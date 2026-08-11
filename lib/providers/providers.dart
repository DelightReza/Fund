
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/config.dart';
import '../models/fund_data.dart';
import '../services/storage_service.dart';
import '../services/github_service.dart';
import '../services/sync_service.dart';
import '../services/calculations.dart';

// ---------- Storage Provider ----------
final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized');
});

// ---------- Config Provider ----------
final configProvider = StateNotifierProvider<ConfigNotifier, AppConfig>((ref) {
  return ConfigNotifier(ref);
});

class ConfigNotifier extends StateNotifier<AppConfig> {
  final Ref ref;
  ConfigNotifier(this.ref) : super(const AppConfig());

  Future<void> loadFromStorage() async {
    final storage = ref.read(storageProvider);
    final saved = storage.loadConfig();
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setConfig(AppConfig config) async {
    state = config;
    final storage = ref.read(storageProvider);
    await storage.saveConfig(config);
    // Also queue sync if token exists
  }

  Future<void> syncConfigFromGitHub({String? token}) async {
    final config = state;
    if (config.repoOwner.isEmpty || config.repoName.isEmpty) return;
    final service = GitHubService(
      owner: config.repoOwner,
      repo: config.repoName,
      token: token,
      branch: config.repoBranch,
      dataFileName: config.dataFileName,
    );
    try {
      final remote = await service.fetchConfig();
      state = remote.copyWith(
        repoOwner: config.repoOwner,
        repoName: config.repoName,
        repoBranch: config.repoBranch,
        dataFileName: config.dataFileName,
      );
      final storage = ref.read(storageProvider);
      await storage.saveConfig(state);
    } catch (_) {
      // Fallback to raw URLs
      final rawUrl =
          'https://raw.githubusercontent.com/${config.repoOwner}/${config.repoName}/${config.repoBranch}/config.json';
      try {
        final remote = await GitHubService.fetchConfigRaw(rawUrl);
        state = remote.copyWith(
          repoOwner: config.repoOwner,
          repoName: config.repoName,
          repoBranch: config.repoBranch,
          dataFileName: config.dataFileName,
        );
        final storage = ref.read(storageProvider);
        await storage.saveConfig(state);
      } catch (_) {}
    }
  }
}

// ---------- Data Provider ----------
final dataProvider = StateNotifierProvider<DataNotifier, FundData>((ref) {
  return DataNotifier(ref);
});

class DataNotifier extends StateNotifier<FundData> {
  final Ref ref;
  DataNotifier(this.ref) : super(const FundData());

  Future<void> loadFromStorage() async {
    final storage = ref.read(storageProvider);
    final saved = storage.loadData();
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setData(FundData data) async {
    state = data;
    final storage = ref.read(storageProvider);
    await storage.saveData(data);
  }

  Future<void> syncDataFromGitHub({String? token}) async {
    final config = ref.read(configProvider);
    if (config.repoOwner.isEmpty || config.repoName.isEmpty) return;
    final service = GitHubService(
      owner: config.repoOwner,
      repo: config.repoName,
      token: token,
      branch: config.repoBranch,
      dataFileName: config.dataFileName,
    );
    try {
      final remote = await service.fetchData();
      state = remote;
      final storage = ref.read(storageProvider);
      await storage.saveData(remote);
    } catch (_) {
      final rawUrl =
          'https://raw.githubusercontent.com/${config.repoOwner}/${config.repoName}/${config.repoBranch}/${config.dataFileName}';
      try {
        final remote = await GitHubService.fetchDataRaw(rawUrl);
        state = remote;
        final storage = ref.read(storageProvider);
        await storage.saveData(remote);
      } catch (_) {}
    }
  }

  // Transaction add/edit/delete will be handled via SyncService.
}

// ---------- Auth Provider (PAT) ----------
final authProvider = StateNotifierProvider<AuthNotifier, String?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<String?> {
  final Ref ref;
  AuthNotifier(this.ref) : super(null);

  Future<void> loadToken() async {
    final storage = ref.read(storageProvider);
    final token = storage.loadToken();
    state = token;
  }

  Future<void> setToken(String? token) async {
    final storage = ref.read(storageProvider);
    if (token == null) {
      await storage.clearToken();
      state = null;
    } else {
      await storage.saveToken(token);
      state = token;
    }
  }
}

// ---------- User Provider ----------
final userProvider = StateProvider<String?>((ref) {
  return null;
});

// ---------- Sync Service Provider ----------
final syncServiceProvider = Provider<SyncService>((ref) {
  final storage = ref.watch(storageProvider);
  final config = ref.watch(configProvider);
  final token = ref.watch(authProvider);
  final service = GitHubService(
    owner: config.repoOwner,
    repo: config.repoName,
    token: token,
    branch: config.repoBranch,
    dataFileName: config.dataFileName,
  );
  return SyncService(storage: storage, github: service);
});

// ---------- Computed Providers ----------
final balancesProvider = Provider<Map<String, double>>((ref) {
  final data = ref.watch(dataProvider);
  final config = ref.watch(configProvider);
  return Calculations.calculateBalances(data, config.people);
});

final debtSettlementsProvider = Provider<List<Settlement>>((ref) {
  final balances = ref.watch(balancesProvider);
  return Calculations.calculateDebtSettlements(balances);
});

final totalsProvider = Provider<({double credits, double debits})>((ref) {
  final data = ref.watch(dataProvider);
  return Calculations.totals(data);
});

