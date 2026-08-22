import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

      // Android/Desktop Flow
      if (savedRepos.isEmpty && !localConfig.hasRepository) {
        state = state.copyWith(
          stage: LaunchStage.repoSelection,
          savedRepos: savedRepos,
          pendingCount: pending,
        );
        return;
      }

      final activeRepo = savedRepos.isNotEmpty
          ? savedRepos.first
          : SavedRepo(
              id: '${localConfig.repoOwner}/${localConfig.repoName}',
              owner: localConfig.repoOwner,
              repo: localConfig.repoName,
              branch: localConfig.repoBranch,
              dataFileName: localConfig.dataFileName,
              token: token,
            );

      final activeToken = activeRepo.token ?? token;
      storage.setRepo(activeRepo.owner, activeRepo.repo);

      final baseConfig = AppConfig(
        siteTitle: activeRepo.displayTitle,
        repoOwner: activeRepo.owner,
        repoName: activeRepo.repo,
        repoBranch: activeRepo.branch,
        dataFileName: activeRepo.dataFileName,
      );

      final merged = await _pullLatestFromRemote(localConfig.hasRepository ? localConfig : baseConfig, activeToken, fallbackData: localData);

      await storage.saveConfig(merged.$1);
      await storage.saveData(merged.$2);

      state = state.copyWith(
        stage: (userId == null || userId.isEmpty) ? LaunchStage.userSelection : LaunchStage.dashboard,
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
      state = state.copyWith(
        stage: LaunchStage.error,
        error: e.toString(),
      );
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

    final baseConfig = AppConfig(
      siteTitle: title ?? 'Fund',
      repoOwner: owner,
      repoName: repo,
      repoBranch: branch,
      dataFileName: dataFileName,
    );

    final merged = await _pullLatestFromRemote(baseConfig, token, fallbackData: const FundData());

    if (token != null && token.isNotEmpty) {
      final result = await GitHubService(
        owner: owner,
        repo: repo,
        branch: branch,
        dataFileName: dataFileName,
        token: token,
      ).verifyToken(token);

      if (!result.isVerified) {
        throw Exception(result.error ?? 'Invalid Personal Access Token provided.');
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
      
      final currentRepoId = '${state.config.repoOwner}/${state.config.repoName}';
      final match = state.savedRepos.where((r) => r.id == currentRepoId).toList();
      if (match.isNotEmpty) {
        final updated = match.first.copyWith(token: null);
        await storage.saveSavedRepo(updated);
        state = state.copyWith(savedRepos: storage.loadSavedRepos());
      }
      return;
    }

    final result = await GitHubService(
      owner: state.config.repoOwner,
      repo: state.config.repoName,
      branch: state.config.repoBranch,
      dataFileName: state.config.dataFileName,
      token: token,
    ).verifyToken(token);

    if (!result.isVerified) {
      throw Exception(result.error ?? 'Invalid Personal Access Token');
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

  Future<bool> addMultipleTransactions(List<Transaction> txs, {String? message}) async {
    final updatedTx = [...txs, ...state.data.transactions];
    return await _saveAndUpdateData(
      updatedTx,
      state.config,
      message ?? 'Add transactions (${txs.length} items)',
    );
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
    final target = state.data.transactions.where((tx) => tx.id == id).toList();
    if (target.isEmpty) return false;
    
    final targetTx = target.first;
    final parentId = targetTx.parentId;
    final currency = state.config.currency;
    
    String getPersonName(String? id) {
      if (id == null) return 'Unknown';
      final match = state.config.people.where((p) => p.id == id).toList();
      return match.isNotEmpty ? match.first.name : id;
    }
    
    String getBillTypeName(String? id) {
      if (id == null) return 'Unknown';
      final match = state.config.billTypes.where((b) => b.id == id).toList();
      return match.isNotEmpty ? match.first.name : id;
    }

    final List<Transaction> updatedTx;
    final String msg;

    if (parentId != null && parentId.isNotEmpty) {
      final group = state.data.transactions.where((tx) => tx.parentId == parentId || tx.id == parentId).toList();
      if (group.any((t) => t.type == TransactionType.credit) && group.any((t) => t.type == TransactionType.debit || t.type == TransactionType.expense)) {
        final creditTx = group.firstWhere((t) => t.type == TransactionType.credit);
        final debitTx = group.firstWhere((t) => t.type == TransactionType.debit || t.type == TransactionType.expense);
        final personName = getPersonName(creditTx.whoOrBill);
        final billName = getBillTypeName(debitTx.whoOrBill);
        msg = 'Deleted Expense: $personName paid $currency${creditTx.amount} for $billName';
      } else if (group.any((t) => t.distributionTotal != null)) {
        final distTx = group.firstWhere((t) => t.distributionTotal != null, orElse: () => group.first);
        final total = distTx.distributionTotal ?? group.fold<double>(0.0, (sum, t) => sum + t.amount);
        msg = 'Deleted Distribution ($currency$total)';
      } else {
        msg = 'Deleted Group Transaction ($parentId)';
      }
      updatedTx = state.data.transactions.where((tx) => tx.parentId != parentId && tx.id != parentId).toList();
    } else {
      if (targetTx.type == TransactionType.credit) {
        msg = 'Deleted Credit: ${getPersonName(targetTx.whoOrBill)} ($currency${targetTx.amount})';
      } else {
        msg = 'Deleted Debit: ${getBillTypeName(targetTx.whoOrBill)} ($currency${targetTx.amount})';
      }
      updatedTx = state.data.transactions.where((tx) => tx.id != id).toList();
    }

    return await _saveAndUpdateData(updatedTx, state.config, msg);
  }

  Future<bool> updateConfig(AppConfig newConfig) async {
    final storage = ref.read(storageProvider);
    storage.setRepo(newConfig.repoOwner, newConfig.repoName);
    await storage.saveConfig(newConfig);
    
    final dateStr = DateFormat('M/d/yyyy, h:mm:ss a').format(DateTime.now());
    final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : storage.loadToken();

    if (effectiveToken != null && effectiveToken.isNotEmpty && newConfig.hasRepository) {
      try {
        state = state.copyWith(syncing: true, error: null);
        final github = GitHubService(
          owner: newConfig.repoOwner,
          repo: newConfig.repoName,
          branch: newConfig.repoBranch,
          dataFileName: newConfig.dataFileName,
          token: effectiveToken,
        );

        // Commit config first
        await github.commitConfig(newConfig, message: 'Update config - $dateStr');

        // Then commit data with updated calculations
        final tempFundData = state.data;
        final peopleCredits = Calculations.calculatePeopleCredits(tempFundData, newConfig.people);
        final billTotals = Calculations.calculateBillTotals(tempFundData, newConfig.billTypes);
        final updatedData = tempFundData.copyWith(people: peopleCredits, billTypes: billTotals);

        await github.commitData(updatedData, message: 'Update fund data - $dateStr');
        await storage.saveData(updatedData);
        await storage.savePendingOperations([]);

        state = state.copyWith(
          config: newConfig,
          data: updatedData,
          token: effectiveToken,
          syncing: false,
          pendingCount: 0,
          error: null,
        );
        return true;
      } catch (e) {
        final errMessage = e.toString().replaceAll('Exception: ', '');
        state = state.copyWith(config: newConfig, syncing: false, error: 'Push config failed: $errMessage');
        return false;
      }
    }

    // Offline / no token path
    final tempFundData = state.data;
    final peopleCredits = Calculations.calculatePeopleCredits(tempFundData, newConfig.people);
    final billTotals = Calculations.calculateBillTotals(tempFundData, newConfig.billTypes);
    final updatedData = tempFundData.copyWith(people: peopleCredits, billTypes: billTotals);
    await storage.saveData(updatedData);

    final pendingCount = await ref.read(syncServiceProvider).queueSnapshot(
          config: newConfig,
          data: updatedData,
          message: 'Update config - $dateStr',
        );

    state = state.copyWith(
      config: newConfig,
      data: updatedData,
      token: effectiveToken,
      pendingCount: pendingCount,
    );
    return false;
  }

  Future<bool> _saveAndUpdateData(List<Transaction> transactions, AppConfig config, String message) async {
    final tempFundData = state.data.copyWith(transactions: transactions);
    final peopleCredits = Calculations.calculatePeopleCredits(tempFundData, config.people);
    final billTotals = Calculations.calculateBillTotals(tempFundData, config.billTypes);

    final updated = tempFundData.copyWith(
      people: peopleCredits,
      billTypes: billTotals,
    );

    final storage = ref.read(storageProvider);
    await storage.saveData(updated);

    final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : storage.loadToken();

    state = state.copyWith(config: config, data: updated, token: effectiveToken);

    final pendingCount = await ref.read(syncServiceProvider).queueSnapshot(
          config: config,
          data: updated,
          message: message,
        );

    state = state.copyWith(pendingCount: pendingCount);

    if (effectiveToken != null && effectiveToken.isNotEmpty && config.hasRepository) {
      try {
        state = state.copyWith(syncing: true, error: null);
        final github = GitHubService(
          owner: config.repoOwner,
          repo: config.repoName,
          branch: config.repoBranch,
          dataFileName: config.dataFileName,
          token: effectiveToken,
        );

        await github.commitData(updated, message: message);
        await ref.read(storageProvider).savePendingOperations([]);

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
    state = state.copyWith(syncing: true, error: null);
    try {
      final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : ref.read(storageProvider).loadToken();
      final merged = await _pullLatestFromRemote(state.config, effectiveToken, fallbackData: state.data);
      await ref.read(storageProvider).saveConfig(merged.$1);
      await ref.read(storageProvider).saveData(merged.$2);
      state = state.copyWith(config: merged.$1, data: merged.$2, syncing: false, error: null);
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  Future<bool> forceCommitData() async {
    final storage = ref.read(storageProvider);
    final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : storage.loadToken();
    if (effectiveToken == null || effectiveToken.isEmpty || !state.config.hasRepository) {
      state = state.copyWith(error: 'PAT and configured repository required');
      return false;
    }
    state = state.copyWith(syncing: true, error: null);
    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: effectiveToken,
      );
      await github.commitData(state.data, message: 'Force manual commit of data');
      await storage.savePendingOperations([]);
      state = state.copyWith(syncing: false, pendingCount: 0, error: null);
      return true;
    } catch (e) {
      final errMessage = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(syncing: false, error: 'Commit data failed: $errMessage');
      return false;
    }
  }

  Future<bool> forceCommitConfig() async {
    final storage = ref.read(storageProvider);
    final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : storage.loadToken();
    if (effectiveToken == null || effectiveToken.isEmpty || !state.config.hasRepository) {
      state = state.copyWith(error: 'PAT and configured repository required');
      return false;
    }
    state = state.copyWith(syncing: true, error: null);
    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: effectiveToken,
      );
      await github.commitConfig(state.config, message: 'Force manual commit of config');
      state = state.copyWith(syncing: false, error: null);
      return true;
    } catch (e) {
      final errMessage = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(syncing: false, error: 'Commit config failed: $errMessage');
      return false;
    }
  }

  Future<bool> syncNow() async {
    final storage = ref.read(storageProvider);
    final effectiveToken = (state.token != null && state.token!.isNotEmpty) ? state.token : storage.loadToken();
    if (effectiveToken == null || effectiveToken.isEmpty || !state.config.hasRepository) {
      state = state.copyWith(error: 'PAT and configured repository required');
      return false;
    }

    state = state.copyWith(syncing: true, error: null);

    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: effectiveToken,
      );
      final remaining = await ref.read(syncServiceProvider).flushQueue(github);
      final merged = await _pullLatestFromRemote(state.config, effectiveToken, fallbackData: state.data);

      await storage.saveConfig(merged.$1);
      await storage.saveData(merged.$2);

      state = state.copyWith(
        config: merged.$1,
        data: merged.$2,
        pendingCount: remaining,
        syncing: false,
        error: null,
      );
      return remaining == 0;
    } catch (e) {
      final errMessage = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(syncing: false, error: 'Sync failed: $errMessage');
      return false;
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
      
      final peopleCredits = Calculations.calculatePeopleCredits(remoteDataRaw, remoteConfig.people);
      final billTotals = Calculations.calculateBillTotals(remoteDataRaw, remoteConfig.billTypes);
      final remoteData = remoteDataRaw.copyWith(people: peopleCredits, billTypes: billTotals);
      
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
  final config = ref.watch(appStateProvider.select((s) => s.config));
  return Calculations.calculateBillTotals(data, config.billTypes);
});

final authSessionTokenProvider = Provider<String?>((ref) {
  return ref.watch(appStateProvider.select((s) => s.token));
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final token = ref.watch(authSessionTokenProvider);
  return token != null && token.trim().isNotEmpty;
});
