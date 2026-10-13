import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';
import '../services/github_api_service.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../utils/fund_merger.dart';
import '../utils/json_formatter.dart';

class FundRepository extends ChangeNotifier {
  final StorageService storage;
  final GitHubApiService api = GitHubApiService();

  AppConfig? _config;
  FundData? _data;
  bool _isLoading = false;
  String? _error;

  FundRepository(this.storage) {
    _config = storage.currentConfig;
    _data = storage.currentDataCache;
  }

  void initializeData(AppConfig config, FundData data) {
    _config = config;
    _data = data;
    notifyListeners();
  }

  AppConfig? get config => _config;
  FundData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const double _duplicateAmountTolerance = 0.0001;
  static const Duration _duplicateTimeWindow = Duration(hours: 1);

  String _normalizedText(String value) => value.trim().toLowerCase();

  bool _doubleEquals(double a, double b) =>
      (a - b).abs() <= _duplicateAmountTolerance;

  List<String> _normalizedList(List<String>? values) {
    final list = (values ?? const <String>[])
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList()
      ..sort();
    return list;
  }

  Map<String, double> _normalizedSplitMap(Map<String, double>? values) {
    final entries = <MapEntry<String, double>>[];
    (values ?? const <String, double>{}).forEach((k, v) {
      final key = k.trim();
      if (key.isNotEmpty) {
        entries.add(MapEntry(key, double.parse(v.toStringAsFixed(4))));
      }
    });
    entries.sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }

  bool _isEquivalentTransaction(TransactionModel a, TransactionModel b) {
    if (a.type != b.type) return false;
    if (!_doubleEquals(a.amount, b.amount)) return false;

    // Prevent duplicate entries within 1 hour (covers rapid double-taps, 5m, 10m, 30m, 1h)
    // Legitimately distinct transactions outside 1 hour (e.g. 2 hours later or next day) are allowed.
    final dtA = AppDateUtils.parseDateTime(a.date);
    final dtB = AppDateUtils.parseDateTime(b.date);
    final timeDiff = dtA.difference(dtB).abs();
    if (timeDiff > _duplicateTimeWindow) return false;

    if (_normalizedText(a.note) != _normalizedText(b.note)) return false;
    if (_normalizedText(a.whoOrBill) != _normalizedText(b.whoOrBill))
      return false;

    final aPayer =
        _normalizedText(a.payerId ?? (a.type == 'credit' ? a.whoOrBill : ''));
    final bPayer =
        _normalizedText(b.payerId ?? (b.type == 'credit' ? b.whoOrBill : ''));
    if (aPayer != bPayer) return false;

    final aBill =
        _normalizedText(a.billTypeId ?? (a.type == 'debit' ? a.whoOrBill : ''));
    final bBill =
        _normalizedText(b.billTypeId ?? (b.type == 'debit' ? b.whoOrBill : ''));
    if (aBill != bBill) return false;

    if (!_doubleEquals(a.distributionTotal ?? 0.0, b.distributionTotal ?? 0.0))
      return false;

    final aSplit = _normalizedList(a.splitAmong);
    final bSplit = _normalizedList(b.splitAmong);
    if (aSplit.length != bSplit.length) return false;
    for (int i = 0; i < aSplit.length; i++) {
      if (aSplit[i] != bSplit[i]) return false;
    }

    final aEx = _normalizedList(a.exemptions);
    final bEx = _normalizedList(b.exemptions);
    if (aEx.length != bEx.length) return false;
    for (int i = 0; i < aEx.length; i++) {
      if (aEx[i] != bEx[i]) return false;
    }

    final aCustom = _normalizedSplitMap(a.customSplit);
    final bCustom = _normalizedSplitMap(b.customSplit);
    if (aCustom.length != bCustom.length) return false;
    for (final entry in aCustom.entries) {
      if (!bCustom.containsKey(entry.key)) return false;
      if (!_doubleEquals(entry.value, bCustom[entry.key]!)) return false;
    }

    final aPct = _normalizedSplitMap(a.splitPercentages);
    final bPct = _normalizedSplitMap(b.splitPercentages);
    if (aPct.length != bPct.length) return false;
    for (final entry in aPct.entries) {
      if (!bPct.containsKey(entry.key)) return false;
      if (!_doubleEquals(entry.value, bPct[entry.key]!)) return false;
    }

    return true;
  }

  bool _containsEquivalentTransaction(
      List<TransactionModel> existing, TransactionModel candidate) {
    return existing.any((tx) => _isEquivalentTransaction(tx, candidate));
  }

  bool _containsEquivalentPair(
    List<TransactionModel> existing, {
    required TransactionModel first,
    required TransactionModel second,
  }) {
    return _containsEquivalentTransaction(existing, first) &&
        _containsEquivalentTransaction(existing, second);
  }

  bool _containsEquivalentSet(
    List<TransactionModel> existing,
    List<TransactionModel> candidates,
  ) {
    if (candidates.isEmpty) return false;
    for (final candidate in candidates) {
      if (!_containsEquivalentTransaction(existing, candidate)) {
        return false;
      }
    }
    return true;
  }

  Future<void> switchWorkspace(String owner, String repo) async {
    await storage.setActiveRepo(owner, repo);
    _config = storage.getConfigFor(owner: owner, repo: repo);
    _data = storage.getDataCacheFor(owner: owner, repo: repo);
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final curConfig = _config ?? await storage.getConfig();
      final owner = curConfig?.repoOwner;
      final repo = curConfig?.repoName;

      final token = await storage.getToken(owner: owner, repo: repo);
      if (token != null &&
          token.isNotEmpty &&
          storage.hasPendingSyncFlagFor(owner: owner, repo: repo)) {
        await syncPending(token);
      }
      await fetchConfig();
      await fetchData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AppConfig?> fetchConfig() async {
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null ||
        curConfig.repoOwner.isEmpty ||
        curConfig.repoName.isEmpty) {
      return null;
    }

    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;
    final token = await storage.getToken(owner: owner, repo: repo);

    final file = await api.getFileDetails(
      token: token,
      owner: owner,
      repo: repo,
      path: 'config.json',
      branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
    );

    if (file != null && file.content.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64.decode(file.content));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final fetched = AppConfig.fromJson(json).copyWith(
          repoOwner: owner,
          repoName: repo,
        );
        _config = fetched;
        await storage.saveConfig(fetched, owner: owner, repo: repo);
        notifyListeners();
        return fetched;
      } catch (_) {}
    }

    _config = curConfig;
    notifyListeners();
    return _config;
  }

  Future<FundData?> fetchData() async {
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null ||
        curConfig.repoOwner.isEmpty ||
        curConfig.repoName.isEmpty) {
      _data = null;
      notifyListeners();
      return _data;
    }

    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;
    final token = await storage.getToken(owner: owner, repo: repo);

    final file = await api.getFileDetails(
      token: token,
      owner: owner,
      repo: repo,
      path: curConfig.dataFileName,
      branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
    );

    if (file != null && file.content.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64.decode(file.content));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final fetched = FundData.fromJson(json);
        final activeDeletedTxIds =
            storage.getDeletedTxIds(owner: owner, repo: repo);
        final activeDeletedParentIds =
            storage.getDeletedParentIds(owner: owner, repo: repo);
        if (activeDeletedTxIds.isNotEmpty ||
            activeDeletedParentIds.isNotEmpty) {
          fetched.transactions.removeWhere((t) =>
              activeDeletedTxIds.contains(t.id) ||
              (t.parentId != null &&
                  activeDeletedParentIds.contains(t.parentId)));
        }
        fetched.updateSummaries(curConfig);
        _data = fetched;
        await storage.saveDataCache(fetched, owner: owner, repo: repo);
        notifyListeners();
        return _data;
      } catch (_) {}
    }

    _data = storage.getDataCacheFor(owner: owner, repo: repo);
    if (_data != null) {
      _data!.updateSummaries(curConfig);
    }
    notifyListeners();
    return _data;
  }

  Future<bool> addQuickExpense({
    required String payerId,
    required String billTypeId,
    required double amount,
    required String note,
    required String date,
    required List<String> exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
  }) async {
    _error = null;
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final parentId = 'tx_exp_${DateTime.now().millisecondsSinceEpoch}';
    final payerName = curConfig.members
        .firstWhere((m) => m.id == payerId,
            orElse: () => MemberConfig(id: payerId, name: payerId))
        .name;
    final billName = curConfig.billTypes
        .firstWhere((b) => b.id == billTypeId,
            orElse: () =>
                BillTypeConfig(id: billTypeId, name: billTypeId, icon: '🧾'))
        .name;
    final ref = note.trim().isNotEmpty ? note.trim() : billName;

    final activeMembers =
        curConfig.members.where((m) => m.active).map((m) => m.id).toList();
    final splitAmong = (customSplit != null && customSplit.isNotEmpty)
        ? customSplit.keys
            .where(
                (k) => !exemptions.contains(k) && (customSplit[k] ?? 0.0) > 0.0)
            .toList()
        : (splitPercentages != null && splitPercentages.isNotEmpty
            ? splitPercentages.keys
                .where((k) =>
                    !exemptions.contains(k) &&
                    (splitPercentages[k] ?? 0.0) > 0.0)
                .toList()
            : activeMembers.where((id) => !exemptions.contains(id)).toList());

    final creditTx = TransactionModel(
      id: '${parentId}_credit',
      type: 'credit',
      payerId: payerId,
      whoOrBill: payerId,
      amount: amount,
      note: '$payerName paid for $ref',
      date: date,
      parentId: parentId,
    );

    final debitTx = TransactionModel(
      id: '${parentId}_debit',
      type: 'debit',
      billTypeId: billTypeId,
      whoOrBill: billTypeId,
      amount: amount,
      note: '$ref is paid by $payerName',
      date: date,
      parentId: parentId,
      splitAmong: splitAmong,
      exemptions: exemptions.isNotEmpty ? exemptions : null,
      customSplit: customSplit,
      splitPercentages: splitPercentages,
    );

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    if (_containsEquivalentPair(currentData.transactions,
        first: creditTx, second: debitTx)) {
      _error =
          'Duplicate expense detected. An identical expense was recorded within the last hour.';
      return false;
    }
    currentData.transactions.insert(0, creditTx);
    currentData.transactions.insert(0, debitTx);
    currentData.updateSummaries(curConfig);

    final amtStr =
        '${curConfig.currency} ${amount % 1.0 == 0.0 ? amount.toInt() : amount.toStringAsFixed(2)}';
    final billConfig = curConfig.billTypes.firstWhere(
      (b) => b.id == billTypeId,
      orElse: () => BillTypeConfig(id: billTypeId, name: billName, icon: ''),
    );
    final billDisplay = billConfig.icon.trim().isNotEmpty
        ? '${billConfig.icon.trim()} ${billConfig.name}'
        : billConfig.name;
    final noteExtra = (note.trim().isNotEmpty && note.trim() != billConfig.name)
        ? ' ($note)'
        : '';
    final activeCount = curConfig.members.where((m) => m.active).length;
    final splitStr = (customSplit != null && customSplit.isNotEmpty)
        ? 'Custom split (${customSplit.length} members)'
        : (splitAmong.length == activeCount
            ? 'Split equally'
            : 'Split among ${splitAmong.length}');
    final msg =
        'Expense: $payerName paid $amtStr for $billDisplay$noteExtra - $splitStr';

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> editQuickExpense({
    required String parentId,
    required String payerId,
    required String billTypeId,
    required double amount,
    required String note,
    required String date,
    required List<String> exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
  }) async {
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final payerName = curConfig.members
        .firstWhere((m) => m.id == payerId,
            orElse: () => MemberConfig(id: payerId, name: payerId))
        .name;
    final billName = curConfig.billTypes
        .firstWhere((b) => b.id == billTypeId,
            orElse: () =>
                BillTypeConfig(id: billTypeId, name: billTypeId, icon: '🧾'))
        .name;
    final ref = note.trim().isNotEmpty ? note.trim() : billName;

    final activeMembers =
        curConfig.members.where((m) => m.active).map((m) => m.id).toList();
    final splitAmong = (customSplit != null && customSplit.isNotEmpty)
        ? customSplit.keys
            .where(
                (k) => !exemptions.contains(k) && (customSplit[k] ?? 0.0) > 0.0)
            .toList()
        : (splitPercentages != null && splitPercentages.isNotEmpty
            ? splitPercentages.keys
                .where((k) =>
                    !exemptions.contains(k) &&
                    (splitPercentages[k] ?? 0.0) > 0.0)
                .toList()
            : activeMembers.where((id) => !exemptions.contains(id)).toList());

    final creditTx = TransactionModel(
      id: '${parentId}_credit',
      type: 'credit',
      payerId: payerId,
      whoOrBill: payerId,
      amount: amount,
      note: '$payerName paid for $ref',
      date: date,
      parentId: parentId,
    );

    final debitTx = TransactionModel(
      id: '${parentId}_debit',
      type: 'debit',
      billTypeId: billTypeId,
      whoOrBill: billTypeId,
      amount: amount,
      note: '$ref is paid by $payerName',
      date: date,
      parentId: parentId,
      splitAmong: splitAmong,
      exemptions: exemptions.isNotEmpty ? exemptions : null,
      customSplit: customSplit,
      splitPercentages: splitPercentages,
    );

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    currentData.transactions.removeWhere((t) => t.parentId == parentId);
    currentData.transactions.insert(0, creditTx);
    currentData.transactions.insert(0, debitTx);
    currentData.updateSummaries(curConfig);

    final amtStr =
        '${curConfig.currency} ${amount % 1.0 == 0.0 ? amount.toInt() : amount.toStringAsFixed(2)}';
    final billConfig = curConfig.billTypes.firstWhere(
      (b) => b.id == billTypeId,
      orElse: () => BillTypeConfig(id: billTypeId, name: billName, icon: ''),
    );
    final billDisplay = billConfig.icon.trim().isNotEmpty
        ? '${billConfig.icon.trim()} ${billConfig.name}'
        : billConfig.name;
    final noteExtra = (note.trim().isNotEmpty && note.trim() != billConfig.name)
        ? ' ($note)'
        : '';
    final msg =
        'Edit Expense: $payerName paid $amtStr for $billDisplay$noteExtra';

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> addSingleTransaction({
    required String type,
    String? payerId,
    String? billTypeId,
    required double amount,
    required String note,
    required String date,
    List<String>? splitAmong,
    List<String>? exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
  }) async {
    _error = null;
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final whoOrBill = type == 'credit' ? (payerId ?? '') : (billTypeId ?? '');

    final tx = TransactionModel(
      id: txId,
      type: type,
      payerId: payerId,
      billTypeId: billTypeId,
      whoOrBill: whoOrBill,
      amount: amount,
      note: note,
      date: date,
      splitAmong: (customSplit != null && customSplit.isNotEmpty)
          ? customSplit.keys.toList()
          : (splitPercentages != null && splitPercentages.isNotEmpty
              ? splitPercentages.keys.toList()
              : splitAmong),
      exemptions: exemptions,
      customSplit: customSplit,
      splitPercentages: splitPercentages,
    );

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    if (_containsEquivalentTransaction(currentData.transactions, tx)) {
      _error =
          'Duplicate transaction detected. An identical transaction was recorded within the last hour.';
      return false;
    }
    currentData.transactions.insert(0, tx);
    currentData.updateSummaries(curConfig);

    final amtStr =
        '${curConfig.currency} ${amount % 1.0 == 0.0 ? amount.toInt() : amount.toStringAsFixed(2)}';
    final noteStr = note.trim().isNotEmpty ? ' ($note)' : '';
    String msg;
    if (type == 'credit') {
      final payer = curConfig.members
          .firstWhere((m) => m.id == payerId,
              orElse: () =>
                  MemberConfig(id: payerId ?? '', name: payerId ?? ''))
          .name;
      msg = 'Deposit: $payer added $amtStr$noteStr';
    } else if (type == 'debit') {
      final bill = curConfig.billTypes.firstWhere((b) => b.id == billTypeId,
          orElse: () => BillTypeConfig(
              id: billTypeId ?? '', name: billTypeId ?? '', icon: ''));
      final billDisplay = bill.icon.trim().isNotEmpty
          ? '${bill.icon.trim()} ${bill.name}'
          : bill.name;
      msg = 'Debit: Spent $amtStr on $billDisplay$noteStr';
    } else {
      msg = 'Transaction: Added $type of $amtStr$noteStr';
    }

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> addDistribution({
    required double totalAmount,
    required String note,
    required String date,
    List<String> participantIds = const [],
  }) async {
    _error = null;
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final activeMembers =
        curConfig.members.where((m) => m.active).map((m) => m.id).toList();
    final distributionMembers = participantIds.isNotEmpty
        ? participantIds.where((id) => activeMembers.contains(id)).toList()
        : activeMembers;
    if (distributionMembers.isEmpty) return false;

    final splitAmount = totalAmount / distributionMembers.length;
    final parentId = 'tx_dist_${DateTime.now().millisecondsSinceEpoch}';
    final newTxs = distributionMembers.asMap().entries.map((entry) {
      final index = entry.key;
      final personId = entry.value;
      return TransactionModel(
        id: '${parentId}_$index',
        type: 'credit',
        payerId: personId,
        whoOrBill: personId,
        note: note.isEmpty ? 'Distribution' : note,
        amount: splitAmount,
        date: date,
        parentId: parentId,
        distributionTotal: totalAmount,
      );
    }).toList();

    final amtStr = totalAmount % 1.0 == 0.0
        ? totalAmount.toInt().toString()
        : totalAmount.toStringAsFixed(2);
    final noteStr = note.isNotEmpty ? ' for $note' : '';
    final msg =
        'Distribution: Distributed ${curConfig.currency} $amtStr among ${distributionMembers.length} members$noteStr';

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    if (_containsEquivalentSet(currentData.transactions, newTxs)) {
      _error =
          'Duplicate distribution detected. An identical distribution was recorded within the last hour.';
      return false;
    }
    for (final tx in newTxs) {
      currentData.transactions.insert(0, tx);
    }
    currentData.updateSummaries(curConfig);

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> addSettlement({
    required String payerId,
    required String receiverId,
    required double amount,
    required String note,
    required String date,
  }) async {
    _error = null;
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final parentId = 'tx_set_${DateTime.now().millisecondsSinceEpoch}';
    final payerName = curConfig.members
        .firstWhere((m) => m.id == payerId,
            orElse: () => MemberConfig(id: payerId, name: payerId))
        .name;
    final receiverName = curConfig.members
        .firstWhere((m) => m.id == receiverId,
            orElse: () => MemberConfig(id: receiverId, name: receiverId))
        .name;

    final payerTx = TransactionModel(
      id: '${parentId}_payer',
      type: 'credit',
      payerId: payerId,
      whoOrBill: payerId,
      note: 'Settlement to $receiverName${note.isNotEmpty ? ": $note" : ""}',
      amount: amount,
      date: date,
      parentId: parentId,
    );

    final receiverTx = TransactionModel(
      id: '${parentId}_rcvr',
      type: 'credit',
      payerId: receiverId,
      whoOrBill: receiverId,
      note: 'Settlement from $payerName${note.isNotEmpty ? ": $note" : ""}',
      amount: -amount,
      date: date,
      parentId: parentId,
    );

    final amtStr = amount % 1.0 == 0.0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    final noteStr = note.trim().isNotEmpty ? ' ($note)' : '';
    final msg =
        'Settlement: $payerName paid ${curConfig.currency} $amtStr to $receiverName$noteStr';

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    if (_containsEquivalentPair(currentData.transactions,
        first: payerTx, second: receiverTx)) {
      _error =
          'Duplicate settlement detected. An identical settlement was recorded within the last hour.';
      return false;
    }
    currentData.transactions.insert(0, payerTx);
    currentData.transactions.insert(0, receiverTx);
    currentData.updateSummaries(curConfig);

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> addTransfer({
    required String senderId,
    required String recipientId,
    required double amount,
    required String note,
    required String date,
  }) async {
    _error = null;
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final parentId = 'tx_trf_${DateTime.now().millisecondsSinceEpoch}';
    final senderName = curConfig.members
        .firstWhere((m) => m.id == senderId,
            orElse: () => MemberConfig(id: senderId, name: senderId))
        .name;
    final recipientName = curConfig.members
        .firstWhere((m) => m.id == recipientId,
            orElse: () => MemberConfig(id: recipientId, name: recipientId))
        .name;

    final senderTx = TransactionModel(
      id: '${parentId}_sender',
      type: 'credit',
      payerId: senderId,
      whoOrBill: senderId,
      note: 'Transfer to $recipientName${note.isNotEmpty ? ": $note" : ""}',
      amount: -amount,
      date: date,
      parentId: parentId,
    );

    final recipientTx = TransactionModel(
      id: '${parentId}_rcvr',
      type: 'credit',
      payerId: recipientId,
      whoOrBill: recipientId,
      note: 'Transfer from $senderName${note.isNotEmpty ? ": $note" : ""}',
      amount: amount,
      date: date,
      parentId: parentId,
    );

    final amtStr = amount % 1.0 == 0.0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    final noteStr = note.trim().isNotEmpty ? ' ($note)' : '';
    final msg =
        'Transfer: $senderName transferred ${curConfig.currency} $amtStr to $recipientName$noteStr';

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    if (_containsEquivalentPair(currentData.transactions,
        first: senderTx, second: recipientTx)) {
      _error =
          'Duplicate transfer detected. An identical transfer was recorded within the last hour.';
      return false;
    }
    currentData.transactions.insert(0, senderTx);
    currentData.transactions.insert(0, recipientTx);
    currentData.updateSummaries(curConfig);

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> editSingleTransaction({
    required String txId,
    required String type,
    String? payerId,
    String? billTypeId,
    required double amount,
    required String note,
    required String date,
    List<String>? splitAmong,
    List<String>? exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
  }) async {
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final whoOrBill = type == 'credit' ? (payerId ?? '') : (billTypeId ?? '');
    final updatedTx = TransactionModel(
      id: txId,
      type: type,
      payerId: payerId,
      billTypeId: billTypeId,
      whoOrBill: whoOrBill,
      amount: amount,
      note: note,
      date: date,
      splitAmong: (customSplit != null && customSplit.isNotEmpty)
          ? customSplit.keys.toList()
          : (splitPercentages != null && splitPercentages.isNotEmpty
              ? splitPercentages.keys.toList()
              : splitAmong),
      exemptions: exemptions,
      customSplit: customSplit,
      splitPercentages: splitPercentages,
    );

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName) ??
        FundData();
    final index = currentData.transactions.indexWhere((t) => t.id == txId);
    if (index != -1) {
      currentData.transactions[index] = updatedTx;
    } else {
      currentData.transactions.insert(0, updatedTx);
    }
    currentData.updateSummaries(curConfig);

    final amtStr =
        '${curConfig.currency} ${amount % 1.0 == 0.0 ? amount.toInt() : amount.toStringAsFixed(2)}';
    final noteStr = note.trim().isNotEmpty ? ' ($note)' : '';
    String msg;
    if (type == 'credit') {
      final payer = curConfig.members
          .firstWhere((m) => m.id == payerId,
              orElse: () =>
                  MemberConfig(id: payerId ?? '', name: payerId ?? ''))
          .name;
      msg = 'Edit Deposit: Updated $payer deposit of $amtStr$noteStr';
    } else if (type == 'debit') {
      final bill = curConfig.billTypes.firstWhere((b) => b.id == billTypeId,
          orElse: () => BillTypeConfig(
              id: billTypeId ?? '', name: billTypeId ?? '', icon: ''));
      final billDisplay = bill.icon.trim().isNotEmpty
          ? '${bill.icon.trim()} ${bill.name}'
          : bill.name;
      msg = 'Edit Debit: Updated debit of $amtStr for $billDisplay$noteStr';
    } else {
      msg = 'Edit Transaction: Updated $type of $amtStr$noteStr';
    }

    _data = currentData;
    notifyListeners();

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> deleteTransaction(TransactionModel tx) async {
    final curConfig = _config ?? await storage.getConfig();
    if (curConfig == null) return false;

    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;
    final currentData = _data?.copyWith() ??
        storage.getDataCacheFor(owner: owner, repo: repo) ??
        FundData();

    final deletedTxIds = <String>{};
    final deletedParentIds = <String>{};

    if (tx.parentId != null && tx.parentId!.isNotEmpty) {
      final siblings = currentData.transactions
          .where((t) => t.parentId == tx.parentId)
          .toList();
      for (final s in siblings) {
        deletedTxIds.add(s.id);
      }
      deletedParentIds.add(tx.parentId!);
      currentData.transactions.removeWhere((t) => t.parentId == tx.parentId);
    } else {
      deletedTxIds.add(tx.id);
      currentData.transactions.removeWhere((t) => t.id == tx.id);
    }

    // Persist tombstones to ensure background sync or 3-way merge never resurrects deleted transactions
    for (final id in deletedTxIds) {
      await storage.addDeletedTombstone(txId: id, owner: owner, repo: repo);
    }
    for (final pId in deletedParentIds) {
      await storage.addDeletedTombstone(
          parentId: pId, owner: owner, repo: repo);
    }

    currentData.updateSummaries(curConfig);

    final amtStr =
        '${curConfig.currency} ${tx.amount.abs() % 1.0 == 0.0 ? tx.amount.abs().toInt() : tx.amount.abs().toStringAsFixed(2)}';
    String detail;
    if (tx.parentId != null && tx.parentId!.contains('_dist_')) {
      detail = 'Distribution (${tx.note})';
    } else if (tx.parentId != null && tx.parentId!.contains('_set_')) {
      detail = 'Settlement (${tx.note})';
    } else if (tx.parentId != null && tx.parentId!.contains('_trf_')) {
      detail = 'Transfer (${tx.note})';
    } else if (tx.type == 'credit') {
      final name = curConfig.members
          .firstWhere((m) => m.id == tx.payerId,
              orElse: () => MemberConfig(id: tx.whoOrBill, name: tx.whoOrBill))
          .name;
      detail = '$name ($amtStr - ${tx.note})';
    } else if (tx.type == 'debit') {
      final bill = curConfig.billTypes.firstWhere((b) => b.id == tx.billTypeId,
          orElse: () =>
              BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: ''));
      final billDisplay = bill.icon.trim().isNotEmpty
          ? '${bill.icon.trim()} ${bill.name}'
          : bill.name;
      detail = '$billDisplay ($amtStr - ${tx.note})';
    } else {
      detail = '${tx.note} ($amtStr)';
    }
    final msg = 'Delete: Removed transaction - $detail';

    _data = currentData;
    notifyListeners();

    final token = await storage.getToken(
        owner: curConfig.repoOwner, repo: curConfig.repoName);
    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  Future<bool> _saveAndPushData(
    FundData currentData,
    AppConfig curConfig,
    String msg,
    String? token,
  ) async {
    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;

    if (token != null && token.isNotEmpty) {
      FundData dataToPush = currentData;
      int attempts = 0;
      const int maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        final file = await api.getFileDetails(
          token: token,
          owner: owner,
          repo: repo,
          path: curConfig.dataFileName,
          branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
        );

        final activeDeletedTxIds =
            storage.getDeletedTxIds(owner: owner, repo: repo);
        final activeDeletedParentIds =
            storage.getDeletedParentIds(owner: owner, repo: repo);

        // Automated 3-Way Merge: If remote data exists, merge remote state with local changes respecting tombstones
        if (file != null && file.content.isNotEmpty) {
          try {
            final decoded = utf8.decode(base64.decode(file.content));
            final remoteData = FundData.fromJson(jsonDecode(decoded));
            dataToPush = FundDataMerger.merge(
              remoteData: remoteData,
              localData: dataToPush,
              config: curConfig,
              deletedIds: activeDeletedTxIds,
              deletedParentIds: activeDeletedParentIds,
            );
          } catch (_) {}
        } else {
          dataToPush.updateSummaries(curConfig);
        }

        final formattedJson = JsonFormatter.formatFundData(dataToPush);
        final encoded = base64.encode(utf8.encode(formattedJson));

        final res = await api.updateFileWithResult(
          token: token,
          owner: owner,
          repo: repo,
          branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
          path: curConfig.dataFileName,
          message: msg,
          base64Content: encoded,
          sha: file?.sha,
        );

        if (res.isSuccess) {
          _data = dataToPush;
          await storage.saveDataCache(dataToPush, owner: owner, repo: repo);
          await storage.setPendingSync(false, null, owner, repo);
          // Clean up tombstones that are confirmed removed
          await storage.removeDeletedTombstones(
            txIds: activeDeletedTxIds,
            parentIds: activeDeletedParentIds,
            owner: owner,
            repo: repo,
          );
          notifyListeners();
          return true;
        }

        // If conflict (409/422) or sha mismatch occurred, wait and re-merge
        if (res.isConflict && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        break;
      }
    }

    await storage.saveDataCache(currentData, owner: owner, repo: repo);
    await storage.setPendingSync(true, msg, owner, repo);
    return true;
  }

  Future<bool> updateConfig(AppConfig newConfig,
      {String? commitMessage}) async {
    final owner = newConfig.repoOwner.isNotEmpty
        ? newConfig.repoOwner
        : (_config?.repoOwner ?? '');
    final repo = newConfig.repoName.isNotEmpty
        ? newConfig.repoName
        : (_config?.repoName ?? '');
    final branch = newConfig.repoBranch.isNotEmpty
        ? newConfig.repoBranch
        : (_config?.repoBranch ?? '');
    final dataFileName = newConfig.dataFileName.isNotEmpty
        ? newConfig.dataFileName
        : (_config?.dataFileName ?? '');
    final token = await storage.getToken(owner: owner, repo: repo);
    final msg =
        commitMessage ?? _generateConfigCommitMessage(_config, newConfig);

    AppConfig configToSave = newConfig.copyWith(
      repoOwner: owner,
      repoName: repo,
      repoBranch: branch,
      dataFileName: dataFileName,
    );

    if (token != null && token.isNotEmpty) {
      final file = await api.getFileDetails(
        token: token,
        owner: owner,
        repo: repo,
        path: 'config.json',
        branch: branch.isNotEmpty ? branch : null,
      );

      if (file != null && file.content.isNotEmpty) {
        try {
          final decoded = utf8.decode(base64.decode(file.content));
          final remoteJson = jsonDecode(decoded) as Map<String, dynamic>;
          final remoteOwner = remoteJson['repoOwner']?.toString();
          final remoteRepo = remoteJson['repoName']?.toString();
          final remoteBranch = remoteJson['repoBranch']?.toString();
          final remoteDataFileName = remoteJson['dataFileName']?.toString();
          if (remoteOwner != null && remoteOwner.isNotEmpty) {
            configToSave = configToSave.copyWith(
              repoOwner: remoteOwner,
              repoName: (remoteRepo != null && remoteRepo.isNotEmpty)
                  ? remoteRepo
                  : configToSave.repoName,
              repoBranch: (remoteBranch != null && remoteBranch.isNotEmpty)
                  ? remoteBranch
                  : configToSave.repoBranch,
              dataFileName:
                  (remoteDataFileName != null && remoteDataFileName.isNotEmpty)
                      ? remoteDataFileName
                      : configToSave.dataFileName,
            );
          }
        } catch (_) {}
      }

      _config = configToSave;
      await storage.saveConfig(configToSave, owner: owner, repo: repo);
      if (_data != null) {
        _data!.updateSummaries(configToSave);
        await storage.saveDataCache(_data!, owner: owner, repo: repo);
      }
      notifyListeners();

      final formattedJson = JsonFormatter.formatAppConfig(configToSave);
      final encoded = base64.encode(utf8.encode(formattedJson));
      final ok = await api.updateFile(
        token: token,
        owner: owner,
        repo: repo,
        branch: configToSave.repoBranch,
        path: 'config.json',
        message: msg,
        base64Content: encoded,
        sha: file?.sha,
      );
      return ok;
    }

    _config = configToSave;
    await storage.saveConfig(configToSave, owner: owner, repo: repo);
    if (_data != null) {
      _data!.updateSummaries(configToSave);
      await storage.saveDataCache(_data!, owner: owner, repo: repo);
    }
    notifyListeners();
    return true;
  }

  Future<bool> syncPending(String token) async {
    final curConfig = _config ?? await storage.getConfig();
    final owner = curConfig?.repoOwner;
    final repo = curConfig?.repoName;
    final localData = storage.getDataCacheFor(owner: owner, repo: repo);
    if (curConfig == null || localData == null || owner == null || repo == null)
      return false;

    int attempts = 0;
    const int maxAttempts = 3;
    FundData dataToSync = localData;

    while (attempts < maxAttempts) {
      attempts++;
      final file = await api.getFileDetails(
        token: token,
        owner: owner,
        repo: repo,
        path: curConfig.dataFileName,
        branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
      );

      final activeDeletedTxIds =
          storage.getDeletedTxIds(owner: owner, repo: repo);
      final activeDeletedParentIds =
          storage.getDeletedParentIds(owner: owner, repo: repo);

      if (file != null && file.content.isNotEmpty) {
        try {
          final decoded = utf8.decode(base64.decode(file.content));
          final remoteData = FundData.fromJson(jsonDecode(decoded));
          dataToSync = FundDataMerger.merge(
            remoteData: remoteData,
            localData: dataToSync,
            config: curConfig,
            deletedIds: activeDeletedTxIds,
            deletedParentIds: activeDeletedParentIds,
          );
        } catch (_) {}
      } else {
        dataToSync.updateSummaries(curConfig);
      }

      final formattedJson = JsonFormatter.formatFundData(dataToSync);
      final encoded = base64.encode(utf8.encode(formattedJson));
      final res = await api.updateFileWithResult(
        token: token,
        owner: owner,
        repo: repo,
        branch: curConfig.repoBranch.isNotEmpty ? curConfig.repoBranch : null,
        path: curConfig.dataFileName,
        message: 'Sync: Merge offline changes with remote ledger (3-way merge)',
        base64Content: encoded,
        sha: file?.sha,
      );

      if (res.isSuccess) {
        _data = dataToSync;
        await storage.saveDataCache(dataToSync, owner: owner, repo: repo);
        await storage.setPendingSync(false, null, owner, repo);
        await storage.removeDeletedTombstones(
          txIds: activeDeletedTxIds,
          parentIds: activeDeletedParentIds,
          owner: owner,
          repo: repo,
        );
        notifyListeners();
        return true;
      }

      if (res.isConflict && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      break;
    }
    return false;
  }

  /// Force Pulls latest config and data from GitHub (overwriting local cache with remote state)
  Future<bool> pullFromGitHub() async {
    final curConfig = _config ?? await storage.getConfig();
    final owner = curConfig?.repoOwner;
    final repo = curConfig?.repoName;

    if (owner == null || repo == null || owner.isEmpty || repo.isEmpty) {
      return false;
    }

    final configRes = await fetchConfig();
    final dataRes = await fetchData();

    if (configRes != null && dataRes != null) {
      await storage.setPendingSync(false, null, owner, repo);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Pushes local data (and ledger) to GitHub repository with automated 3-way merge
  Future<bool> pushToGitHub({String? commitMessage}) async {
    final curConfig = _config ?? await storage.getConfig() ?? AppConfig();
    final currentData = _data ??
        storage.getDataCacheFor(
            owner: curConfig.repoOwner, repo: curConfig.repoName);
    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;
    final token = await storage.getToken(owner: owner, repo: repo);
    final txCount = currentData?.transactions.length ?? 0;
    final msg = commitMessage ??
        'Sync: Push $txCount offline transactions to remote ledger';

    if (currentData == null || owner.isEmpty || repo.isEmpty) return false;

    if (token == null || token.isEmpty) {
      await storage.setPendingSync(true, msg, owner, repo);
      return false;
    }

    return await _saveAndPushData(currentData, curConfig, msg, token);
  }

  /// Force Pulls latest config and data from GitHub and pushes any offline pending changes
  Future<bool> forceSyncGitHub() async {
    final curConfig = _config ?? await storage.getConfig();
    final owner = curConfig?.repoOwner;
    final repo = curConfig?.repoName;
    final token = await storage.getToken(owner: owner, repo: repo);

    if (token == null || token.isEmpty || owner == null || repo == null) {
      await refreshAll();
      return false;
    }

    if (storage.hasPendingSyncFlag) {
      await syncPending(token);
    }

    await fetchConfig();
    await fetchData();
    notifyListeners();
    return true;
  }

  String exportToCsv() {
    final d = _data;
    if (d == null || d.transactions.isEmpty)
      return 'Date,Type,Amount,Category/Who,Note,SplitAmong,Exemptions\n';

    final buffer = StringBuffer();
    buffer.writeln(
        'ID,Date,Type,Amount,CategoryOrWho,Note,ParentID,SplitAmong,Exemptions');
    for (final tx in d.transactions) {
      final split = (tx.splitAmong ?? []).join(';');
      final ex = (tx.exemptions ?? []).join(';');
      final escapedNote = '"${tx.note.replaceAll('"', '""')}"';
      buffer.writeln(
          '${tx.id},${tx.date},${tx.type},${tx.amount},${tx.whoOrBill},$escapedNote,${tx.parentId ?? ""},$split,$ex');
    }
    return buffer.toString();
  }

  String exportToJsonFormatted() {
    final d = _data;
    if (d == null) return '{}';
    return JsonFormatter.formatFundData(d);
  }

  String exportConfigJsonFormatted() {
    final c = _config;
    if (c == null) return '{}';
    return JsonFormatter.formatAppConfig(c);
  }

  Future<bool> importFundData(FundData importedData,
      {String? commitMessage}) async {
    final curConfig = _config ?? await storage.getConfig() ?? AppConfig();
    final owner = curConfig.repoOwner;
    final repo = curConfig.repoName;
    final token = await storage.getToken(owner: owner, repo: repo);
    final txCount = importedData.transactions.length;
    final msg =
        commitMessage ?? 'Import: Load ledger with $txCount transactions';

    importedData.updateSummaries(curConfig);
    _data = importedData;
    await storage.saveDataCache(importedData, owner: owner, repo: repo);
    notifyListeners();

    if (token != null &&
        token.isNotEmpty &&
        owner.isNotEmpty &&
        repo.isNotEmpty) {
      final file = await api.getFileDetails(
        token: token,
        owner: owner,
        repo: repo,
        path: curConfig.dataFileName,
      );

      final formattedJson = JsonFormatter.formatFundData(importedData);
      final encoded = base64.encode(utf8.encode(formattedJson));
      final ok = await api.updateFile(
        token: token,
        owner: owner,
        repo: repo,
        path: curConfig.dataFileName,
        message: msg,
        base64Content: encoded,
        sha: file?.sha,
      );

      if (ok) {
        await storage.setPendingSync(false, null, owner, repo);
        return true;
      }
    }

    await storage.setPendingSync(true, msg, owner, repo);
    return true;
  }

  String _generateConfigCommitMessage(
      AppConfig? oldConfig, AppConfig newConfig) {
    if (oldConfig == null) {
      return 'Config: Initialize configuration settings';
    }

    final addedMembers = <String>[];
    final removedMembers = <String>[];
    final updatedMembers = <String>[];

    final oldMemberMap = {for (final m in oldConfig.members) m.id: m};
    final newMemberMap = {for (final m in newConfig.members) m.id: m};

    // 1. Added members
    for (final m in newConfig.members) {
      if (!oldMemberMap.containsKey(m.id)) {
        addedMembers.add('Add member "${m.name}" (@${m.id})');
      }
    }

    // 2. Removed members
    for (final m in oldConfig.members) {
      if (!newMemberMap.containsKey(m.id)) {
        removedMembers.add('Remove member "${m.name}" (@${m.id})');
      }
    }

    // 3. Updated/renamed members
    for (final newM in newConfig.members) {
      final oldM = oldMemberMap[newM.id];
      if (oldM != null) {
        final nameChanged = oldM.name.trim() != newM.name.trim();
        final activeChanged = oldM.active != newM.active;

        if (nameChanged && activeChanged) {
          final status = newM.active ? 'active' : 'inactive';
          updatedMembers.add(
              'Rename member "${oldM.name}" to "${newM.name}" and set $status (@${newM.id})');
        } else if (nameChanged) {
          updatedMembers.add(
              'Rename member "${oldM.name}" to "${newM.name}" (@${newM.id})');
        } else if (activeChanged) {
          if (newM.active) {
            updatedMembers.add('Activate member "${newM.name}" (@${newM.id})');
          } else {
            updatedMembers
                .add('Deactivate member "${newM.name}" (@${newM.id})');
          }
        }
      }
    }

    // Check categories (billTypes)
    final addedBills = <String>[];
    final removedBills = <String>[];
    final updatedBills = <String>[];

    final oldBillMap = {for (final b in oldConfig.billTypes) b.id: b};
    final newBillMap = {for (final b in newConfig.billTypes) b.id: b};

    // 1. Added categories
    for (final b in newConfig.billTypes) {
      if (!oldBillMap.containsKey(b.id)) {
        final iconStr = b.icon.trim().isNotEmpty ? '${b.icon.trim()} ' : '';
        addedBills.add('Add category "$iconStr${b.name.trim()}" (@${b.id})');
      }
    }

    // 2. Removed categories
    for (final b in oldConfig.billTypes) {
      if (!newBillMap.containsKey(b.id)) {
        final iconStr = b.icon.trim().isNotEmpty ? '${b.icon.trim()} ' : '';
        removedBills
            .add('Remove category "$iconStr${b.name.trim()}" (@${b.id})');
      }
    }

    // 3. Updated categories
    for (final newB in newConfig.billTypes) {
      final oldB = oldBillMap[newB.id];
      if (oldB != null) {
        final nameChanged = oldB.name.trim() != newB.name.trim();
        final iconChanged = oldB.icon.trim() != newB.icon.trim();

        if (nameChanged && iconChanged) {
          final oldDisplay = oldB.icon.trim().isNotEmpty
              ? '${oldB.icon.trim()} ${oldB.name.trim()}'
              : oldB.name.trim();
          final newDisplay = newB.icon.trim().isNotEmpty
              ? '${newB.icon.trim()} ${newB.name.trim()}'
              : newB.name.trim();
          updatedBills.add(
              'Update category "$oldDisplay" to "$newDisplay" (@${newB.id})');
        } else if (nameChanged) {
          final iconStr =
              newB.icon.trim().isNotEmpty ? '${newB.icon.trim()} ' : '';
          updatedBills.add(
              'Rename category "$iconStr${oldB.name.trim()}" to "${newB.name.trim()}" (@${newB.id})');
        } else if (iconChanged) {
          updatedBills.add(
              'Update icon for category "${newB.name.trim()}" from ${oldB.icon.trim()} to ${newB.icon.trim()} (@${newB.id})');
        }
      }
    }

    // Check general settings
    final generalChanges = <String>[];
    if (oldConfig.currency.trim() != newConfig.currency.trim() &&
        newConfig.currency.trim().isNotEmpty) {
      generalChanges.add(
          'Change currency from "${oldConfig.currency.trim()}" to "${newConfig.currency.trim()}"');
    }
    if (oldConfig.siteTitle.trim() != newConfig.siteTitle.trim() &&
        newConfig.siteTitle.trim().isNotEmpty) {
      generalChanges.add('Change title to "${newConfig.siteTitle.trim()}"');
    }
    if (oldConfig.siteSubtitle.trim() != newConfig.siteSubtitle.trim() &&
        newConfig.siteSubtitle.trim().isNotEmpty) {
      generalChanges
          .add('Change subtitle to "${newConfig.siteSubtitle.trim()}"');
    }
    if (oldConfig.dataFileName.trim() != newConfig.dataFileName.trim() &&
        newConfig.dataFileName.trim().isNotEmpty) {
      generalChanges
          .add('Change data file to "${newConfig.dataFileName.trim()}"');
    }
    if (oldConfig.repoBranch.trim() != newConfig.repoBranch.trim() &&
        newConfig.repoBranch.trim().isNotEmpty) {
      generalChanges.add('Change branch to "${newConfig.repoBranch.trim()}"');
    }

    final allChanges = [
      ...addedMembers,
      ...updatedMembers,
      ...removedMembers,
      ...addedBills,
      ...updatedBills,
      ...removedBills,
      ...generalChanges,
    ];

    if (allChanges.isEmpty) {
      final oldMemberOrder = oldConfig.members.map((m) => m.id).join(',');
      final newMemberOrder = newConfig.members.map((m) => m.id).join(',');
      if (oldMemberOrder != newMemberOrder) {
        return 'Config: Reorder members';
      }
      final oldBillOrder = oldConfig.billTypes.map((b) => b.id).join(',');
      final newBillOrder = newConfig.billTypes.map((b) => b.id).join(',');
      if (oldBillOrder != newBillOrder) {
        return 'Config: Reorder categories';
      }
      return 'Config: Update configuration';
    }

    if (allChanges.length == 1) {
      return 'Config: ${allChanges.first}';
    }

    // Multi-line commit with summary subject and bulleted body
    final hasMemberChanges = addedMembers.isNotEmpty ||
        updatedMembers.isNotEmpty ||
        removedMembers.isNotEmpty;
    final hasBillChanges = addedBills.isNotEmpty ||
        updatedBills.isNotEmpty ||
        removedBills.isNotEmpty;
    final hasGeneralChanges = generalChanges.isNotEmpty;

    String subject;
    if (hasMemberChanges && !hasBillChanges && !hasGeneralChanges) {
      subject = 'Config: Update members (${allChanges.length} changes)';
    } else if (!hasMemberChanges && hasBillChanges && !hasGeneralChanges) {
      subject = 'Config: Update categories (${allChanges.length} changes)';
    } else if (!hasMemberChanges && !hasBillChanges && hasGeneralChanges) {
      subject = 'Config: Update settings (${allChanges.length} changes)';
    } else {
      subject = 'Config: Update configuration (${allChanges.length} changes)';
    }

    final body = allChanges.map((c) => '- $c').join('\n');
    return '$subject\n\n$body';
  }
}
