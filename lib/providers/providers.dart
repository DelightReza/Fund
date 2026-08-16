import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/saved_repo.dart';
import '../models/settlement.dart';
import '../models/transaction.dart';
import '../services/calculations.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../utils/date_utils.dart';

enum LaunchStage { loading, repoSelection, userSelection, dashboard, error }

class AppState {
  static const _unset = Object();

  const AppState({
    this.stage = LaunchStage.loading,
    this.config = const AppConfig(),
    this.data = const FundData(),
    this.savedRepos = const [],
    this.token,
    this.userId,
    this.syncing = false,
    this.pendingCount = 0,
    this.error,
  });

  final LaunchStage stage;
  final AppConfig config;
  final FundData data;
  final List<SavedRepo> savedRepos;
  final String? token;
  final String? userId;
  final bool syncing;
  final int pendingCount;
  final String? error;

  AppState copyWith({
    LaunchStage? stage,
    AppConfig? config,
    FundData? data,
    List<SavedRepo>? savedRepos,
    Object? token = _unset,
    Object? userId = _unset,
    bool? syncing,
    int? pendingCount,
    Object? error = _unset,
  }) {
    return AppState(
      stage: stage ?? this.stage,
      config: config ?? this.config,
      data: data ?? this.data,
      savedRepos: savedRepos ?? this.savedRepos,
      token: identical(token, _unset) ? this.token : token as String?,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      syncing: syncing ?? this.syncing,
      pendingCount: pendingCount ?? this.pendingCount,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageProvider must be overridden in main.dart');
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final storage = ref.watch(storageProvider);
  return SyncService(storage);
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this.storage) : super(_loadFromStorage(storage));
  final StorageService storage;

  static ThemeMode _loadFromStorage(StorageService storage) {
    final mode = storage.loadThemeMode();
    return mode != null ? ThemeMode.values[mode] : ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    storage.saveThemeMode(mode.index);
  }
}

final appStateProvider = StateNotifierProvider<AppNotifier, AppState>((ref) {
  return AppNotifier(ref);
});

class AppNotifier extends StateNotifier<AppState> {
  AppNotifier(this.ref) : super(const AppState());

  final Ref ref;
  Timer? _syncTimer;

  bool get _isWeb => kIsWeb;

  Future<void> bootstrap() async {
    state = state.copyWith(stage: LaunchStage.loading, error: null);

    try {
      final storage = ref.read(storageProvider);
      var savedRepos = storage.loadSavedRepos();
      final token = storage.loadToken();
      final userId = storage.loadUser();
      final localConfig = storage.loadConfig() ?? const AppConfig();
      final localData = storage.loadData() ?? const FundData();
      final pending = ref.read(syncServiceProvider).loadQueue().length;

      // Ensure localConfig repo is in savedRepos if present
      if (localConfig.hasRepository && savedRepos.isEmpty) {
        final initialRepo = SavedRepo(
          id: '${localConfig.repoOwner}/${localConfig.repoName}',
          owner: localConfig.repoOwner,
          repo: localConfig.repoName,
          branch: localConfig.repoBranch,
          dataFileName: localConfig.dataFileName,
          title: localConfig.siteTitle,
          token: token,
        );
        await storage.saveSavedRepo(initialRepo);
        savedRepos = [initialRepo];
      }

      if (_isWeb) {
        final webService = GitHubService(owner: '', repo: '', branch: 'main', dataFileName: localConfig.dataFileName);
        AppConfig config;
        FundData data;
        try {
          config = await webService.fetchRelativeConfig();
          data = await webService.fetchRelativeData(config.dataFileName);
          if (config.hasRepository) {
            storage.setRepo(config.repoOwner, config.repoName);
            await storage.saveConfig(config);
            await storage.saveData(data);
          }
        } catch (_) {
          config = localConfig;
          data = localData;
        }

        final activeRepo = savedRepos.firstWhere(
          (r) => r.owner == config.repoOwner && r.repo == config.repoName,
          orElse: () => savedRepos.isNotEmpty ? savedRepos.first : SavedRepo(
            id: '${config.repoOwner}/${config.repoName}',
            owner: config.repoOwner,
            repo: config.repoName,
            branch: config.repoBranch,
            dataFileName: config.dataFileName,
            token: token,
          ),
        );

        final activeToken = activeRepo.token ?? token;

        state = state.copyWith(
          stage: LaunchStage.dashboard,
          config: config,
          data: data,
          savedRepos: savedRepos,
          token: activeToken,
          userId: userId,
          pendingCount: pending,
          error: null,
        );
        return;
      }

      if (!localConfig.hasRepository && savedRepos.isEmpty) {
        state = state.copyWith(
          stage: LaunchStage.repoSelection,
          config: localConfig,
          data: localData,
          savedRepos: savedRepos,
          token: token,
          userId: userId,
          pendingCount: pending,
        );
        return;
      }

      final activeRepo = savedRepos.firstWhere(
        (r) => r.owner == localConfig.repoOwner && r.repo == localConfig.repoName,
        orElse: () => savedRepos.first,
      );

      final activeToken = activeRepo.token ?? token;

      final merged = await _pullLatestFromRemote(localConfig, activeToken, fallbackData: localData);
      final nextStage = (userId == null || userId.isEmpty) ? LaunchStage.userSelection : LaunchStage.dashboard;

      state = state.copyWith(
        stage: nextStage,
        config: merged.$1,
        data: merged.$2,
        savedRepos: savedRepos,
        token: activeToken,
        userId: userId,
        pendingCount: pending,
        error: null,
      );

      _startPeriodicSync();
    } catch (e) {
      state = state.copyWith(stage: LaunchStage.error, error: e.toString());
    }
  }

  Future<void> connectRepository({
    required String owner,
    required String repo,
    String branch = 'main',
    String dataFileName = 'data.json',
    String? token,
    String? title,
  }) async {
    state = state.copyWith(stage: LaunchStage.loading, error: null);

    final storage = ref.read(storageProvider);
    storage.setRepo(owner, repo);

    final baseConfig = state.config.copyWith(
      siteTitle: (title != null && title.isNotEmpty) ? title : (state.config.siteTitle.isNotEmpty ? state.config.siteTitle : 'Fund'),
      repoOwner: owner,
      repoName: repo,
      repoBranch: branch,
      dataFileName: dataFileName,
    );

    final merged = await _pullLatestFromRemote(baseConfig, token, fallbackData: state.data);

    if (token != null && token.isNotEmpty) {
      final isValid = await GitHubService(
        owner: owner,
        repo: repo,
        branch: branch,
        dataFileName: dataFileName,
        token: token,
      ).verifyToken(token);

      if (!isValid) {
        throw Exception('Invalid Personal Access Token provided.');
      }
      await storage.saveToken(token);
    }

    final newSavedRepo = SavedRepo(
      id: '$owner/$repo',
      owner: owner,
      repo: repo,
      branch: branch,
      dataFileName: dataFileName,
      title: title ?? merged.$1.siteTitle,
      token: token,
    );

    await storage.saveSavedRepo(newSavedRepo);
    final updatedSavedRepos = storage.loadSavedRepos();

    await storage.saveConfig(merged.$1);
    await storage.saveData(merged.$2);

    state = state.copyWith(
      stage: (state.userId == null || state.userId!.isEmpty) ? LaunchStage.userSelection : LaunchStage.dashboard,
      config: merged.$1,
      data: merged.$2,
      savedRepos: updatedSavedRepos,
      token: token ?? state.token,
      error: null,
    );

    _startPeriodicSync();
  }

  Future<void> switchRepository(SavedRepo repo) async {
    state = state.copyWith(stage: LaunchStage.loading, error: null);
    final storage = ref.read(storageProvider);
    storage.setRepo(repo.owner, repo.repo);

    final baseConfig = AppConfig(
      siteTitle: repo.displayTitle,
      repoOwner: repo.owner,
      repoName: repo.repo,
      repoBranch: repo.branch,
      dataFileName: repo.dataFileName,
    );

    final localData = storage.loadData() ?? const FundData();
    final localConfig = storage.loadConfig() ?? baseConfig;

    final merged = await _pullLatestFromRemote(localConfig, repo.token, fallbackData: localData);

    if (repo.token != null) {
      await storage.saveToken(repo.token!);
    } else {
      await storage.clearToken();
    }

    await storage.saveConfig(merged.$1);
    await storage.saveData(merged.$2);

    state = state.copyWith(
      stage: (state.userId == null || state.userId!.isEmpty) ? LaunchStage.userSelection : LaunchStage.dashboard,
      config: merged.$1,
      data: merged.$2,
      token: repo.token,
      error: null,
    );

    _startPeriodicSync();
  }

  Future<void> deleteSavedRepository(String id) async {
    final storage = ref.read(storageProvider);
    await storage.deleteSavedRepo(id);
    final updatedList = storage.loadSavedRepos();

    state = state.copyWith(savedRepos: updatedList);

    if (updatedList.isEmpty) {
      state = state.copyWith(stage: LaunchStage.repoSelection);
    } else if ('${state.config.repoOwner}/${state.config.repoName}' == id) {
      await switchRepository(updatedList.first);
    }
  }

  Future<void> selectUser(String userId) async {
    await ref.read(storageProvider).saveUser(userId);
    state = state.copyWith(userId: userId, stage: LaunchStage.dashboard);
  }

  Future<void> setToken(String? token) async {
    final storage = ref.read(storageProvider);
    if (token == null || token.isEmpty) {
      await storage.clearToken();
      state = state.copyWith(token: null);
      
      // Update SavedRepo
      final currentRepoId = '${state.config.repoOwner}/${state.config.repoName}';
      final match = state.savedRepos.where((r) => r.id == currentRepoId).toList();
      if (match.isNotEmpty) {
        final updated = match.first.copyWith(token: null);
        await storage.saveSavedRepo(updated);
        state = state.copyWith(savedRepos: storage.loadSavedRepos());
      }
      return;
    }

    final isValid = await GitHubService(
      owner: state.config.repoOwner,
      repo: state.config.repoName,
      branch: state.config.repoBranch,
      dataFileName: state.config.dataFileName,
      token: token,
    ).verifyToken(token);

    if (!isValid) {
      throw Exception('Invalid Personal Access Token');
    }

    await storage.saveToken(token);

    final currentRepoId = '${state.config.repoOwner}/${state.config.repoName}';
    final match = state.savedRepos.where((r) => r.id == currentRepoId).toList();
    if (match.isNotEmpty) {
      final updated = match.first.copyWith(token: token);
      await storage.saveSavedRepo(updated);
    }

    state = state.copyWith(token: token, savedRepos: storage.loadSavedRepos());
  }

  Future<bool> addTransaction(Transaction tx, {String? message}) async {
    final updatedTx = [tx, ...state.data.transactions];
    return await _saveAndUpdateData(updatedTx, state.config, message ?? 'Update fund data (${tx.type.name})');
  }

  Future<bool> addGroupedExpense({
    required String parentId,
    required List<Transaction> children,
    String? message,
  }) async {
    final updatedTx = [...children, ...state.data.transactions];
    return await _saveAndUpdateData(
      updatedTx,
      state.config,
      message ?? 'Add grouped expense breakdown (${children.length} items)',
    );
  }

  Future<bool> updateGroupedExpense({
    required String parentId,
    required List<Transaction> newChildren,
    String? message,
  }) async {
    // Atomically replace all items having parentId or id == parentId with newChildren
    final filtered = state.data.transactions.where((tx) => tx.parentId != parentId && tx.id != parentId).toList();
    final updatedTx = [...newChildren, ...filtered];
    return await _saveAndUpdateData(
      updatedTx,
      state.config,
      message ?? 'Update grouped expense breakdown ($parentId)',
    );
  }

  Future<bool> deleteGroupedExpense(String parentId, {String? message}) async {
    final updatedTx = state.data.transactions.where((tx) => tx.parentId != parentId && tx.id != parentId).toList();
    return await _saveAndUpdateData(
      updatedTx,
      state.config,
      message ?? 'Delete grouped transaction ($parentId)',
    );
  }

  Future<bool> updateTransaction(Transaction updatedTx, {String? message}) async {
    final updatedList = state.data.transactions.map((tx) => tx.id == updatedTx.id ? updatedTx : tx).toList();
    return await _saveAndUpdateData(updatedList, state.config, message ?? 'Update transaction (${updatedTx.id})');
  }

  Future<bool> deleteTransaction(String id) async {
    // If target transaction has a parentId, delete all transactions with that same parentId
    final target = state.data.transactions.where((tx) => tx.id == id).toList();
    final parentId = target.isNotEmpty ? target.first.parentId : null;

    final List<Transaction> updatedTx;
    final String msg;
    if (parentId != null && parentId.isNotEmpty) {
      updatedTx = state.data.transactions.where((tx) => tx.parentId != parentId && tx.id != parentId).toList();
      msg = 'Delete grouped transaction ($parentId)';
    } else {
      updatedTx = state.data.transactions.where((tx) => tx.id != id).toList();
      msg = 'Delete transaction ($id)';
    }

    return await _saveAndUpdateData(updatedTx, state.config, msg);
  }

  Future<bool> updateConfig(AppConfig newConfig) async {
    final storage = ref.read(storageProvider);
    await storage.saveConfig(newConfig);
    return await _saveAndUpdateData(state.data.transactions, newConfig, 'Update configuration');
  }

  Future<bool> _saveAndUpdateData(List<Transaction> transactions, AppConfig config, String message) async {
    final tempFundData = state.data.copyWith(transactions: transactions);
    final balances = Calculations.calculateBalances(tempFundData, config.people);
    final billTotals = Calculations.calculateBillTotals(tempFundData);

    final updated = tempFundData.copyWith(
      people: balances,
      billTypes: billTotals,
    );

    final storage = ref.read(storageProvider);
    await storage.saveData(updated);
    state = state.copyWith(config: config, data: updated);

    final pendingCount = await ref.read(syncServiceProvider).queueSnapshot(
          config: config,
          data: updated,
          message: message,
        );

    state = state.copyWith(pendingCount: pendingCount);

    if (state.token != null && state.token!.isNotEmpty && state.config.hasRepository) {
      try {
        state = state.copyWith(syncing: true, error: null);
        final github = GitHubService(
          owner: state.config.repoOwner,
          repo: state.config.repoName,
          branch: state.config.repoBranch,
          dataFileName: state.config.dataFileName,
          token: state.token,
        );

        await ref.read(syncServiceProvider).flushQueue(github);
        await github.commitConfig(config, message: message);
        await github.commitData(updated, message: message);

        state = state.copyWith(syncing: false, pendingCount: 0, error: null);
        return true;
      } catch (e) {
        final errMessage = e.toString().replaceAll('Exception: ', '');
        state = state.copyWith(syncing: false, error: 'Push failed: $errMessage');
        return false;
      }
    }

    return false;
  }

  Future<void> pullOnly() async {
    if (!state.config.hasRepository) return;
    state = state.copyWith(syncing: true);
    try {
      final merged = await _pullLatestFromRemote(state.config, state.token, fallbackData: state.data);
      await ref.read(storageProvider).saveConfig(merged.$1);
      await ref.read(storageProvider).saveData(merged.$2);
      state = state.copyWith(config: merged.$1, data: merged.$2, syncing: false);
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<void> forceCommitData() async {
    if (state.token == null || state.token!.isEmpty || !state.config.hasRepository) return;
    state = state.copyWith(syncing: true);
    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: state.token,
      );
      await github.commitData(state.data, message: 'Force manual commit of data');
      state = state.copyWith(syncing: false);
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<void> forceCommitConfig() async {
    if (state.token == null || state.token!.isEmpty || !state.config.hasRepository) return;
    state = state.copyWith(syncing: true);
    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: state.token,
      );
      await github.commitConfig(state.config, message: 'Force manual commit of config');
      state = state.copyWith(syncing: false);
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<void> syncNow() async {
    if (state.token == null || state.token!.isEmpty || !state.config.hasRepository) {
      return;
    }

    state = state.copyWith(syncing: true);

    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: state.token,
      );
      final remaining = await ref.read(syncServiceProvider).flushQueue(github);
      final merged = await _pullLatestFromRemote(state.config, state.token, fallbackData: state.data);

      await ref.read(storageProvider).saveConfig(merged.$1);
      await ref.read(storageProvider).saveData(merged.$2);

      state = state.copyWith(
        config: merged.$1,
        data: merged.$2,
        pendingCount: remaining,
        syncing: false,
      );
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<void> logoutUser() async {
    await ref.read(storageProvider).clearUser();
    state = state.copyWith(userId: null, stage: LaunchStage.userSelection);
  }

  Future<void> refreshReadOnly() async {
    if (!state.config.hasRepository) return;

    final merged = await _pullLatestFromRemote(state.config, state.token, fallbackData: state.data);
    await ref.read(storageProvider).saveConfig(merged.$1);
    await ref.read(storageProvider).saveData(merged.$2);
    state = state.copyWith(config: merged.$1, data: merged.$2);
  }

  Future<(AppConfig, FundData)> _pullLatestFromRemote(
    AppConfig base,
    String? token, {
    required FundData fallbackData,
  }) async {
    final github = GitHubService(
      owner: base.repoOwner,
      repo: base.repoName,
      branch: base.repoBranch,
      dataFileName: base.dataFileName,
      token: token,
    );

    try {
      final remoteConfig = await github.fetchConfig();
      final remoteDataRaw = await github.fetchData();
      
      final balances = Calculations.calculateBalances(remoteDataRaw, remoteConfig.people);
      final billTotals = Calculations.calculateBillTotals(remoteDataRaw);
      final remoteData = remoteDataRaw.copyWith(people: balances, billTypes: billTotals);
      
      return (remoteConfig, remoteData);
    } catch (_) {
      return (base, fallbackData);
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncNow();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> clearLocalData() async {
    await ref.read(storageProvider).clearAll();
    state = const AppState(stage: LaunchStage.repoSelection);
  }
}

final balancesProvider = Provider<Map<String, double>>((ref) {
  final state = ref.watch(appStateProvider);
  return Calculations.calculateBalances(state.data, state.config.people);
});

final settlementsProvider = Provider<List<Settlement>>((ref) {
  final balances = ref.watch(balancesProvider);
  return Calculations.calculateDebtSettlements(balances);
});

final totalsProvider = Provider<({double credits, double debits})>((ref) {
  final data = ref.watch(appStateProvider.select((s) => s.data));
  return Calculations.totals(data);
});

final billTotalsProvider = Provider<Map<String, double>>((ref) {
  final data = ref.watch(appStateProvider.select((s) => s.data));
  return Calculations.calculateBillTotals(data);
});

final authSessionTokenProvider = Provider<String?>((ref) {
  return ref.watch(appStateProvider.select((s) => s.token));
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final token = ref.watch(authSessionTokenProvider);
  return token != null && token.trim().isNotEmpty;
});

Transaction createTransaction({
  required TransactionType type,
  required double amount,
  required String note,
  String? actorId,
  String? targetId,
  List<String> participants = const [],
  List<String> exemptions = const [],
  String? parentId,
}) {
  return Transaction(
    id: AppDateUtils.generateId(),
    type: type,
    amount: amount,
    note: note,
    actorId: actorId,
    targetId: targetId,
    participantIds: participants,
    exemptions: exemptions,
    parentId: parentId,
    timestamp: AppDateUtils.nowIso(),
  );
}
