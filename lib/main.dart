import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_config.dart';
import 'models/fund_data.dart';
import 'repositories/fund_repository.dart';
import 'services/github_api_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/repo_selection_screen.dart';
import 'screens/user_selection_screen.dart';
import 'screens/main_screen.dart';
import 'utils/web_prefetch_helper.dart';
import 'utils/web_route_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  final repository = FundRepository(storage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<FundRepository>.value(value: repository),
      ],
      child: const FundApp(),
    ),
  );
}

class FundApp extends StatelessWidget {
  const FundApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return MaterialApp(
      title: 'Fund - Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: storage.themeMode,
      home: const AppBootstrapScreen(),
    );
  }
}

class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final storage = context.read<StorageService>();
      final repo = context.read<FundRepository>();

      if (kIsWeb) {
        // 1. Web Flow - Instant Launch from cache followed by non-blocking background sync
        AppConfig? config = storage.currentConfig;
        FundData? data = storage.currentDataCache;

        // Check if early prefetch restored config/data from window or localStorage
        if (config == null) {
          final prefetchedCfg = WebPrefetchHelper.getPrefetchedConfigRaw();
          if (prefetchedCfg != null && prefetchedCfg.trim().isNotEmpty) {
            try {
              config = AppConfig.fromJson(jsonDecode(prefetchedCfg));
            } catch (_) {}
          }
        }
        if (data == null) {
          final prefetchedData = WebPrefetchHelper.getPrefetchedDataRaw();
          if (prefetchedData != null && prefetchedData.trim().isNotEmpty) {
            try {
              data = FundData.fromJson(jsonDecode(prefetchedData));
            } catch (_) {}
          }
        }

        // If cached or prefetched config is available, launch IMMEDIATELY!
        if (config != null) {
          data ??= FundData();
          data.updateSummaries(config);
          repo.initializeData(config, data);

          if (config.hasRepository) {
            await storage.setActiveRepo(config.repoOwner, config.repoName);
            await storage.saveConfig(config, owner: config.repoOwner, repo: config.repoName);
            await storage.saveDataCache(data, owner: config.repoOwner, repo: config.repoName);
          }

          if (mounted) {
            final initialRoute = WebRouteHelper.getCurrentRoute() ?? storage.getLastRoute();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => MainScreen(initialRoute: initialRoute)),
            );
          }

          // Trigger background sync to pull fresh updates without blocking UI
          _syncWebInBackground(storage, repo, config);
          return;
        }

        // First-time visit: no cached config exists yet.
        // Fetch relative config.json with a brief timeout
        final api = GitHubApiService();
        try {
          final relativeConfigRaw = await api.fetchRelativeFile('config.json').timeout(const Duration(seconds: 3));
          if (relativeConfigRaw != null && relativeConfigRaw.trim().isNotEmpty) {
            config = AppConfig.fromJson(jsonDecode(relativeConfigRaw));
          }
        } catch (_) {}

        final dataFileName = config?.dataFileName ?? 'data.json';
        try {
          final relativeDataRaw = await api.fetchRelativeFile(dataFileName).timeout(const Duration(seconds: 3));
          if (relativeDataRaw != null && relativeDataRaw.trim().isNotEmpty) {
            data = FundData.fromJson(jsonDecode(relativeDataRaw));
          }
        } catch (_) {}

        // Fallbacks if first visit was offline or empty
        config ??= AppConfig(
          repoOwner: '',
          repoName: '',
          siteTitle: 'Fund',
          siteSubtitle: 'Expense Tracker',
          currency: '₹',
          members: [MemberConfig(id: 'me', name: 'Me', active: true)],
          billTypes: [
            BillTypeConfig(id: 'expense', name: 'General Expense', icon: '🧾')
          ],
        );

        data ??= FundData();
        data.updateSummaries(config);

        if (config.hasRepository) {
          await storage.setActiveRepo(config.repoOwner, config.repoName);
          await storage.saveConfig(config, owner: config.repoOwner, repo: config.repoName);
          await storage.saveDataCache(data, owner: config.repoOwner, repo: config.repoName);
        }

        repo.initializeData(config, data);

        if (mounted) {
          final initialRoute = WebRouteHelper.getCurrentRoute() ?? storage.getLastRoute();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainScreen(initialRoute: initialRoute)),
          );
        }

        _syncWebInBackground(storage, repo, config);
      } else {
        // 2. Mobile / App Flow - Prompts RepoSelection and UserSelection
        final config = await storage.getConfig();
        if (config == null || config.repoOwner.isEmpty || config.repoName.isEmpty) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RepoSelectionScreen()),
            );
          }
          return;
        }

        final user = await storage.getUser();
        if (user == null || user.isEmpty) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
            );
          }
          return;
        }

        // Non-blocking background fetch
        Future.microtask(() async {
          try {
            await repo.fetchConfig().timeout(const Duration(seconds: 4));
            await repo.fetchData().timeout(const Duration(seconds: 4));
          } catch (_) {}
        });

        if (mounted) {
          final initialRoute = WebRouteHelper.getCurrentRoute() ?? storage.getLastRoute();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainScreen(initialRoute: initialRoute)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  static void _syncWebInBackground(
    StorageService storage,
    FundRepository repo,
    AppConfig initialConfig,
  ) {
    Future.microtask(() async {
      try {
        final api = GitHubApiService();
        AppConfig latestConfig = initialConfig;
        FundData? latestData = repo.data ?? storage.currentDataCache;

        // 1. Fetch fresh relative config.json
        final relativeConfigRaw = await api.fetchRelativeFile('config.json');
        if (relativeConfigRaw != null && relativeConfigRaw.trim().isNotEmpty) {
          try {
            final parsed = AppConfig.fromJson(jsonDecode(relativeConfigRaw));
            latestConfig = parsed.copyWith(
              repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : initialConfig.repoOwner,
              repoName: parsed.repoName.isNotEmpty ? parsed.repoName : initialConfig.repoName,
              repoBranch: parsed.repoBranch.isNotEmpty ? parsed.repoBranch : initialConfig.repoBranch,
              dataFileName: parsed.dataFileName.isNotEmpty ? parsed.dataFileName : initialConfig.dataFileName,
            );
          } catch (_) {}
        }

        // 2. If configured with GitHub repo, check remote config
        if (latestConfig.hasRepository) {
          final owner = latestConfig.repoOwner;
          final repoName = latestConfig.repoName;
          final token = await storage.getToken(owner: owner, repo: repoName);
          final remoteConfigFile = await api.getFileDetails(
            token: token,
            owner: owner,
            repo: repoName,
            path: 'config.json',
            branch: latestConfig.repoBranch.isNotEmpty ? latestConfig.repoBranch : null,
          );
          if (remoteConfigFile != null && remoteConfigFile.content.isNotEmpty) {
            try {
              final decoded = utf8.decode(base64.decode(remoteConfigFile.content));
              final parsed = AppConfig.fromJson(jsonDecode(decoded));
              latestConfig = parsed.copyWith(
                repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
                repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repoName,
                repoBranch: parsed.repoBranch.isNotEmpty ? parsed.repoBranch : latestConfig.repoBranch,
                dataFileName: parsed.dataFileName.isNotEmpty ? parsed.dataFileName : latestConfig.dataFileName,
              );
            } catch (_) {}
          }
        }

        // 3. Fetch fresh relative data
        final dataFileName = latestConfig.dataFileName.isNotEmpty ? latestConfig.dataFileName : 'data.json';
        final relativeDataRaw = await api.fetchRelativeFile(dataFileName);
        if (relativeDataRaw != null && relativeDataRaw.trim().isNotEmpty) {
          try {
            latestData = FundData.fromJson(jsonDecode(relativeDataRaw));
          } catch (_) {}
        }

        // 4. If remote repo configured, also pull from GitHub if needed
        if (latestConfig.hasRepository) {
          final owner = latestConfig.repoOwner;
          final repoName = latestConfig.repoName;
          final token = await storage.getToken(owner: owner, repo: repoName);
          final remoteDataFile = await api.getFileDetails(
            token: token,
            owner: owner,
            repo: repoName,
            path: dataFileName,
            branch: latestConfig.repoBranch.isNotEmpty ? latestConfig.repoBranch : null,
          );
          if (remoteDataFile != null && remoteDataFile.content.isNotEmpty) {
            try {
              final decoded = utf8.decode(base64.decode(remoteDataFile.content));
              latestData = FundData.fromJson(jsonDecode(decoded));
            } catch (_) {}
          }
        }

        if (latestData != null) {
          final owner = latestConfig.hasRepository ? latestConfig.repoOwner : null;
          final repo = latestConfig.hasRepository ? latestConfig.repoName : null;
          final activeDeletedTxIds = storage.getDeletedTxIds(owner: owner, repo: repo);
          final activeDeletedParentIds = storage.getDeletedParentIds(owner: owner, repo: repo);
          if (activeDeletedTxIds.isNotEmpty || activeDeletedParentIds.isNotEmpty) {
            latestData.transactions.removeWhere((t) =>
                activeDeletedTxIds.contains(t.id) ||
                (t.parentId != null && activeDeletedParentIds.contains(t.parentId)));
          }
          latestData.updateSummaries(latestConfig);
        }

        // 5. Update local storage, early web cache, and repository
        if (latestConfig.hasRepository) {
          await storage.setActiveRepo(latestConfig.repoOwner, latestConfig.repoName);
          await storage.saveConfig(latestConfig, owner: latestConfig.repoOwner, repo: latestConfig.repoName);
          if (latestData != null) {
            await storage.saveDataCache(latestData, owner: latestConfig.repoOwner, repo: latestConfig.repoName);
          }
        } else {
          await storage.saveConfig(latestConfig);
          if (latestData != null) {
            await storage.saveDataCache(latestData);
          }
        }

        if (latestData != null) {
          WebPrefetchHelper.updateEarlyCache(
            jsonEncode(latestConfig.toJson()),
            jsonEncode(latestData.toJson()),
          );
          repo.initializeData(latestConfig, latestData);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 54, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _bootstrap();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    final initialRoute = WebRouteHelper.getCurrentRoute() ?? context.read<StorageService>().getLastRoute();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => MainScreen(initialRoute: initialRoute)),
                    );
                  },
                  child: const Text('Continue to App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Fund',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Expense & Fund Tracker',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
