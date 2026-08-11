import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config.dart';
import '../models/fund_data.dart';
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
    this.token,
    this.userId,
    this.syncing = false,
    this.pendingCount = 0,
    this.error,
  });

  final LaunchStage stage;
  final AppConfig config;
  final FundData data;
  final String? token;
  final String? userId;
  final bool syncing;
  final int pendingCount;
  final String? error;

  AppState copyWith({
    LaunchStage? stage,
    AppConfig? config,
    FundData? data,
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
      final token = storage.loadToken();
      final userId = storage.loadUser();
      final localConfig = storage.loadConfig() ?? const AppConfig();
      final localData = storage.loadData() ?? const FundData();
      final pending = ref.read(syncServiceProvider).loadQueue().length;

      if (_isWeb) {
        final webService = GitHubService(owner: '', repo: '', branch: 'main', dataFileName: localConfig.dataFileName);
        AppConfig config;
        FundData data;
        try {
          config = await webService.fetchRelativeConfig();
          data = await webService.fetchRelativeData(config.dataFileName);
        } catch (_) {
          config = localConfig;
          data = localData;
        }
        state = state.copyWith(
          stage: LaunchStage.dashboard,
          config: config,
          data: data,
          token: null,
          userId: userId,
          pendingCount: 0,
          error: null,
        );
        return;
      }

      if (!localConfig.hasRepository) {
        state = state.copyWith(
          stage: LaunchStage.repoSelection,
          config: localConfig,
          data: localData,
          token: token,
          userId: userId,
          pendingCount: pending,
        );
        return;
      }

      final merged = await _pullLatestFromRemote(localConfig, token, fallbackData: localData);
      final nextStage = (userId == null || userId.isEmpty) ? LaunchStage.userSelection : LaunchStage.dashboard;

      state = state.copyWith(
        stage: nextStage,
        config: merged.$1,
        data: merged.$2,
        token: token,
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
  }) async {
    state = state.copyWith(stage: LaunchStage.loading, error: null);

    final baseConfig = state.config.copyWith(
      repoOwner: owner,
      repoName: repo,
      repoBranch: branch,
      dataFileName: dataFileName,
    );

    final merged = await _pullLatestFromRemote(baseConfig, token, fallbackData: state.data);

    final storage = ref.read(storageProvider);
    await storage.saveConfig(merged.$1);
    await storage.saveData(merged.$2);

    if (token != null && token.isNotEmpty) {
      await storage.saveToken(token);
    }

    state = state.copyWith(
      stage: LaunchStage.userSelection,
      config: merged.$1,
      data: merged.$2,
      token: token ?? state.token,
      error: null,
    );

    _startPeriodicSync();
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
      return;
    }

    await storage.saveToken(token);
    state = state.copyWith(token: token);
  }

  Future<void> addTransaction(Transaction tx, {String? message}) async {
    final updated = state.data.copyWith(transactions: [tx, ...state.data.transactions]);
    final storage = ref.read(storageProvider);
    await storage.saveData(updated);
    state = state.copyWith(data: updated);

    if (_isWeb) return;

    final pendingCount = await ref.read(syncServiceProvider).queueSnapshot(
          config: state.config,
          data: updated,
          message: message ?? 'Update fund data (${tx.type.name})',
        );

    state = state.copyWith(pendingCount: pendingCount);
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_isWeb || state.token == null || state.token!.isEmpty || !state.config.hasRepository) {
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
    if (!state.config.hasRepository || _isWeb) return;

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
      final remoteData = await github.fetchData();
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
