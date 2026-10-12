import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/github_models.dart';
import '../repositories/fund_repository.dart';
import '../services/github_api_service.dart';
import '../services/storage_service.dart';
import 'user_selection_screen.dart';
import '../widgets/glass_container.dart';

class RepoSelectionScreen extends StatefulWidget {
  const RepoSelectionScreen({super.key});

  @override
  State<RepoSelectionScreen> createState() => _RepoSelectionScreenState();
}

class _RepoSelectionScreenState extends State<RepoSelectionScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _isTokenVisible = false;
  bool _showTokenInput = false;

  bool _isLoading = false;
  String? _error;
  List<SavedWorkspace> _saved = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final storage = context.read<StorageService>();
    final list = await storage.getSavedWorkspaces();
    if (mounted) {
      setState(() {
        _saved = list;
      });
    }
  }

  Map<String, String>? _parseRepoInput(String input) {
    var clean = input.trim();
    if (clean.isEmpty) return null;
    clean = clean.replaceAll('"', '').replaceAll("'", "");

    // Handle SSH format: git@github.com:owner/repo.git
    if (clean.contains('git@github.com:')) {
      clean = clean.replaceFirst('git@github.com:', 'https://github.com/');
    }

    // Strip trailing .git and trailing slashes
    clean = clean.replaceAll(RegExp(r'\.git/?$'), '');

    String owner = '';
    String repo = '';
    String? branch;

    if (clean.contains('raw.githubusercontent.com')) {
      final uri = Uri.tryParse(clean.startsWith('http') ? clean : 'https://$clean');
      if (uri != null) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 2) {
          owner = segments[0];
          repo = segments[1];
          if (segments.length >= 3) {
            branch = segments[2];
          }
        }
      }
    } else if (clean.contains('api.github.com')) {
      final uri = Uri.tryParse(clean.startsWith('http') ? clean : 'https://$clean');
      if (uri != null) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        final repoIdx = segments.indexOf('repos');
        if (repoIdx != -1 && segments.length > repoIdx + 2) {
          owner = segments[repoIdx + 1];
          repo = segments[repoIdx + 2];
        }
      }
    } else if (clean.contains('.github.io')) {
      final uri = Uri.tryParse(clean.startsWith('http') ? clean : 'https://$clean');
      if (uri != null) {
        final host = uri.host;
        owner = host.split('.').first;
        final segments = uri.pathSegments
            .where((s) => s.isNotEmpty && !s.endsWith('.json') && !s.endsWith('.html'))
            .toList();
        if (segments.isNotEmpty) {
          repo = segments[0];
        } else {
          repo = '$owner.github.io';
        }
      }
    } else if (clean.contains('github.com')) {
      final uri = Uri.tryParse(clean.startsWith('http') ? clean : 'https://$clean');
      if (uri != null) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 2) {
          owner = segments[0];
          repo = segments[1];
          final treeIdx = segments.indexOf('tree');
          final blobIdx = segments.indexOf('blob');
          final bIdx = treeIdx != -1 ? treeIdx : blobIdx;
          if (bIdx != -1 && segments.length > bIdx + 1) {
            branch = segments[bIdx + 1];
          }
        }
      }
    } else if (clean.contains('/')) {
      final cleanNoHttp = clean.replaceFirst(RegExp(r'^https?://'), '');
      final parts = cleanNoHttp.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        owner = parts[0];
        repo = parts[1];
      }
    }

    owner = owner.trim();
    repo = repo.trim();

    if (owner.isNotEmpty && repo.isNotEmpty) {
      return {
        'owner': owner,
        'repo': repo,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
      };
    }
    return null;
  }

  Future<void> _attemptConnection({String? customInput, String? customToken}) async {
    final input = (customInput ?? _urlController.text).trim();
    var token = (customToken ?? _tokenController.text).trim();

    if (input.isEmpty) {
      setState(() => _error = 'Please enter a URL or owner/repo');
      return;
    }

    final parsed = _parseRepoInput(input);
    if (parsed == null) {
      setState(() => _error = 'Invalid format. Use owner/repo or a GitHub URL.');
      return;
    }

    final owner = parsed['owner']!;
    final repo = parsed['repo']!;
    final detectedBranch = parsed['branch'];

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final storage = context.read<StorageService>();
    final fundRepo = context.read<FundRepository>();

    if (token.isNotEmpty) {
      await storage.saveToken(token, owner: owner, repo: repo);
    } else {
      // Check if we have an existing saved token for this workspace
      final existingToken = await storage.getToken(owner: owner, repo: repo);
      if (existingToken != null && existingToken.isNotEmpty) {
        token = existingToken;
      }
    }

    // Set active workspace in storage
    await storage.setActiveRepo(owner, repo);

    AppConfig? config;
    String? configBranch = detectedBranch;

    // 0. If input looks like a URL, attempt direct fetch first
    final normalizedUrl = (input.startsWith('http://') || input.startsWith('https://'))
        ? input
        : (input.contains('.') ? 'https://$input' : null);

    if (normalizedUrl != null) {
      final directUrlsToTry = [
        normalizedUrl,
        if (!normalizedUrl.endsWith('config.json'))
          '${normalizedUrl.replaceAll(RegExp(r'/+$'), '')}/config.json',
      ];

      for (final dUrl in directUrlsToTry) {
        try {
          final directResp = await http.get(Uri.parse(dUrl)).timeout(const Duration(seconds: 6));
          if (directResp.statusCode == 200 && directResp.body.trim().isNotEmpty) {
            final body = directResp.body.trim();
            if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
              final json = jsonDecode(body) as Map<String, dynamic>;
              final parsed = AppConfig.fromJson(json);
              config = parsed.copyWith(
                repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
                repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repo,
              );
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 1. Direct GitHub REST API call for config.json
    if (config == null) {
      try {
        final file = await fundRepo.api.getFileDetails(
          token: token.isNotEmpty ? token : null,
          owner: owner,
          repo: repo,
          path: 'config.json',
          branch: detectedBranch,
        );
        if (file != null && file.content.isNotEmpty) {
          final decoded = utf8.decode(base64.decode(file.content));
          final json = jsonDecode(decoded) as Map<String, dynamic>;
          final parsed = AppConfig.fromJson(json);
          config = parsed.copyWith(
            repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
            repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repo,
            repoBranch: detectedBranch ?? 'main',
          );
        }
      } catch (_) {}
    }

    // 2. Fast CDN mirrors (works without tokens, no rate limits, open CORS)
    if (config == null) {
      final cdnUrls = [
        'https://cdn.jsdelivr.net/gh/$owner/$repo/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://cdn.jsdelivr.net/gh/$owner/$repo@main/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://cdn.jsdelivr.net/gh/$owner/$repo@master/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://cdn.jsdelivr.net/gh/${owner.toLowerCase()}/${repo.toLowerCase()}@main/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
      ];

      for (final cUrl in cdnUrls) {
        try {
          final resp = await http.get(Uri.parse(cUrl)).timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
            final body = resp.body.trim();
            if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
              final json = jsonDecode(body) as Map<String, dynamic>;
              final parsed = AppConfig.fromJson(json);
              config = parsed.copyWith(
                repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
                repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repo,
                repoBranch: 'main',
              );
              configBranch = 'main';
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 3. GitHub Pages URLs
    if (config == null) {
      final pagesUrls = [
        'https://$owner.github.io/$repo/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://$owner.github.io/${repo.toLowerCase()}/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://${owner.toLowerCase()}.github.io/$repo/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://${owner.toLowerCase()}.github.io/${repo.toLowerCase()}/config.json?t=${DateTime.now().millisecondsSinceEpoch}',
      ];
      for (final pUrl in pagesUrls) {
        try {
          final resp = await http.get(Uri.parse(pUrl)).timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
            final body = resp.body.trim();
            if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
              final json = jsonDecode(body) as Map<String, dynamic>;
              final parsed = AppConfig.fromJson(json);
              config = parsed.copyWith(
                repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
                repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repo,
              );
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 4. Raw GitHub UserContent Fallback
    if (config == null) {
      final branchesToTry = [
        if (detectedBranch != null) detectedBranch,
        'main',
        'master',
      ].toSet().toList();

      for (final b in branchesToTry) {
        try {
          final rawUrl = 'https://raw.githubusercontent.com/$owner/$repo/$b/config.json?t=${DateTime.now().millisecondsSinceEpoch}';
          final headers = GitHubApiService.buildHeaders(
            token: token.isNotEmpty ? token : null,
            accept: '*/*',
          );
          final resp = await http.get(Uri.parse(rawUrl), headers: headers).timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
            final body = resp.body.trim();
            if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
              final json = jsonDecode(body) as Map<String, dynamic>;
              final parsed = AppConfig.fromJson(json);
              config = parsed.copyWith(
                repoOwner: parsed.repoOwner.isNotEmpty ? parsed.repoOwner : owner,
                repoName: parsed.repoName.isNotEmpty ? parsed.repoName : repo,
                repoBranch: b,
              );
              configBranch = b;
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 5. If config.json was not found, check if the repo is reachable / has data.json
    if (config == null) {
      try {
        final dataFile = await fundRepo.api.getFileDetails(
          token: token.isNotEmpty ? token : null,
          owner: owner,
          repo: repo,
          path: 'data.json',
          branch: detectedBranch,
        );
        if (dataFile != null) {
          // Repository exists and has data.json! Auto-create default config
          config = AppConfig(
            siteTitle: repo,
            siteSubtitle: 'Expense Tracker',
            currency: '₹',
            repoOwner: owner,
            repoName: repo,
            repoBranch: detectedBranch ?? 'main',
            dataFileName: 'data.json',
          );
        }
      } catch (_) {}
    }

    // If config found/created successfully, save and navigate!
    if (config != null) {
      if (configBranch != null && configBranch.isNotEmpty) {
        config = config.copyWith(repoBranch: configBranch);
      }
      await storage.saveConfig(config, owner: owner, repo: repo);
      await storage.saveWorkspace(SavedWorkspace(
        owner: owner,
        repo: repo,
        title: config.siteTitle.isNotEmpty ? config.siteTitle : repo,
        token: token.isNotEmpty ? token : null,
        lastAccessed: DateTime.now(),
      ));

      try {
        // Switch active workspace in repository and fetch initial data
        await fundRepo.switchWorkspace(owner, repo);
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
        );
      }
      return;
    }

    // If not found, diagnose specific HTTP issue for clear, helpful error message
    String detailedError = 'Failed to load config for "$owner/$repo". Check URL or enter a GitHub Token.';
    try {
      final checkUrl = Uri.parse('https://api.github.com/repos/$owner/$repo');
      final checkHeaders = GitHubApiService.buildHeaders(token: token.isNotEmpty ? token : null);
      final checkResp = await http.get(checkUrl, headers: checkHeaders).timeout(const Duration(seconds: 6));

      if (checkResp.statusCode == 401) {
        detailedError = 'Invalid GitHub Token (401 Bad Credentials). Please check your Personal Access Token.';
      } else if (checkResp.statusCode == 403) {
        detailedError = 'GitHub API rate limit exceeded or access forbidden (403). Please provide a valid GitHub Token.';
      } else if (checkResp.statusCode == 404) {
        detailedError = 'Repository "$owner/$repo" not found (404). If it is private, please provide a GitHub Personal Access Token with repo scope.';
      } else if (checkResp.statusCode == 200) {
        detailedError = 'Connected to repository "$owner/$repo", but config.json was not found. Please verify the branch or add config.json.';
      } else {
        detailedError = 'GitHub API error (${checkResp.statusCode}): ${checkResp.reasonPhrase ?? ''}';
      }
    } catch (e) {
      detailedError = 'Connection error: ${e.toString().replaceAll('SocketException:', 'Network error:')}';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = detailedError;
        _showTokenInput = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Fund', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => storage.toggleTheme(context),
          ),
        ],
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Blue Wallet Icon container
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Funds',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a workspace to manage expenses',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Saved Repositories List
                  if (_saved.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _saved.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final ws = _saved[index];
                        return GlassCard(
                          margin: EdgeInsets.zero,
                          borderRadius: 16,
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _attemptConnection(
                                customInput: '${ws.owner}/${ws.repo}',
                                customToken: ws.token,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ws.title ?? 'Fund Repository',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${ws.owner}/${ws.repo}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                    color: Colors.red.shade400,
                                    tooltip: 'Remove',
                                    onPressed: () async {
                                      await storage.removeWorkspace(ws.owner, ws.repo);
                                      _loadSaved();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                  ],

                  // Add New Fund Card
                  GlassCard(
                    margin: EdgeInsets.zero,
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Fund',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _urlController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Repo URL or owner/repo',
                              hintText: 'owner/repo or https://github.com/...',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon: _urlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _urlController.clear();
                                          _error = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                            onSubmitted: (_) => _attemptConnection(),
                          ),
                          if (_showTokenInput) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tokenController,
                              obscureText: !_isTokenVisible,
                              textInputAction: TextInputAction.go,
                              decoration: InputDecoration(
                                labelText: 'GitHub Token (Optional for public repos)',
                                hintText: 'ghp_... or github_pat_...',
                                prefixIcon: const Icon(Icons.key_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isTokenVisible ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _isTokenVisible = !_isTokenVisible);
                                  },
                                ),
                              ),
                              onSubmitted: (_) => _attemptConnection(),
                            ),
                          ] else ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _showTokenInput = true);
                                },
                                child: const Text(
                                  'Private repo? Add token',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _isLoading ? null : () => _attemptConnection(),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Connect Fund',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
