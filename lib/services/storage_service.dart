import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/github_models.dart';

class StorageService extends ChangeNotifier {
  final SharedPreferences _prefs;

  // Global preference keys
  static const String _keyActiveRepoOwner = 'active_repo_owner';
  static const String _keyActiveRepoName = 'active_repo_name';
  static const String _keyWorkspaces = 'fund_saved_workspaces';
  static const String _keyGlobalToken = 'fund_github_pat';
  static const String _keyThemeMode = 'fund_theme_mode';

  // Legacy fallback keys (for seamless backward compatibility & test mocks)
  static const String _legacyKeyConfig = 'fund_app_config';
  static const String _legacyKeyConfigAlt = 'local_config_json';
  static const String _legacyKeyDataCache = 'fund_data_cache';
  static const String _legacyKeyDataCacheAlt = 'local_data_json';
  static const String _legacyKeyUser = 'fund_active_user';
  static const String _legacyKeyPendingSync = 'fund_pending_sync';
  static const String _legacyKeyPendingMsg = 'fund_pending_msg';

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  static Future<StorageService> create([SharedPreferences? prefs]) async {
    if (prefs != null) {
      return StorageService(prefs);
    }
    final p = await SharedPreferences.getInstance();
    return StorageService(p);
  }

  // Active Repository tracking
  String? get activeRepoOwner => _prefs.getString(_keyActiveRepoOwner);
  String? get activeRepoName => _prefs.getString(_keyActiveRepoName);

  Future<void> setActiveRepo(String owner, String repo) async {
    await _prefs.setString(_keyActiveRepoOwner, owner);
    await _prefs.setString(_keyActiveRepoName, repo);
    notifyListeners();
  }

  // Helper key generators: fund_${repoOwner}_${repoName}_${suffix}
  String _formatKey(String suffix, [String? owner, String? repo]) {
    final o =
        (owner != null && owner.isNotEmpty) ? owner : (activeRepoOwner ?? '');
    final r = (repo != null && repo.isNotEmpty) ? repo : (activeRepoName ?? '');

    if (o.isNotEmpty && r.isNotEmpty) {
      return 'fund_${o}_${r}_$suffix';
    }
    return 'fund_$suffix';
  }

  // Key names strictly per repository
  String configKey([String? owner, String? repo]) =>
      _formatKey('config', owner, repo);
  String dataKey([String? owner, String? repo]) =>
      _formatKey('data', owner, repo);
  String fundKey([String? owner, String? repo]) =>
      _formatKey('metadata', owner, repo);
  String userKey([String? owner, String? repo]) =>
      _formatKey('user', owner, repo);
  String tokenKey([String? owner, String? repo]) =>
      _formatKey('token', owner, repo);
  String verifiedKey([String? owner, String? repo]) =>
      _formatKey('admin_verified', owner, repo);
  String pendingSyncKey([String? owner, String? repo]) =>
      _formatKey('pending_sync', owner, repo);
  String pendingMsgKey([String? owner, String? repo]) =>
      _formatKey('pending_msg', owner, repo);
  String tombstonesKey([String? owner, String? repo]) =>
      _formatKey('tombstones', owner, repo);
  String lastRouteKey([String? owner, String? repo]) =>
      _formatKey('last_active_route', owner, repo);
  String lastRouteTimeKey([String? owner, String? repo]) =>
      _formatKey('last_active_route_time', owner, repo);
  String historyKey([String? owner, String? repo]) =>
      _formatKey('route_history', owner, repo);

  static const String _legacyKeyLastRouteTime = 'fund_last_active_route_time';
  static const int routeCacheMaxAgeMs =
      10 * 60 * 1000; // 10 minutes cache expiration

  // Admin Verification Status per Repository
  bool isAdminVerifiedFor({String? owner, String? repo}) {
    final key = verifiedKey(owner, repo);
    final verified = _prefs.getBool(key) ?? false;
    final token = getTokenFor(owner: owner, repo: repo);
    // If token was deleted or empty, verification is false
    if (token == null || token.isEmpty) return false;
    return verified;
  }

  bool get isAdminVerified => isAdminVerifiedFor();

  Future<void> setAdminVerified(bool verified,
      {String? owner, String? repo}) async {
    final key = verifiedKey(owner, repo);
    await _prefs.setBool(key, verified);
    notifyListeners();
  }

  // Theme Mode
  ThemeMode get themeMode {
    final mode = _prefs.getString(_keyThemeMode);
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    await _prefs.setString(_keyThemeMode, val);
    notifyListeners();
  }

  Future<void> toggleTheme([BuildContext? context]) async {
    final isDark = (themeMode == ThemeMode.dark) ||
        (themeMode == ThemeMode.system &&
            context != null &&
            Theme.of(context).brightness == Brightness.dark);

    if (isDark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  // App Config: fund_${repoOwner}_${repoName}_config
  AppConfig? getConfigFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;

    if (o == null || o.isEmpty || r == null || r.isEmpty) {
      return null;
    }

    final key = configKey(o, r);
    String? str = _prefs.getString(key);
    // Backward compatibility migration for THIS specific repository only
    str ??= _prefs.getString('config_${o}_$r');

    if (str == null || str.isEmpty) return null;
    try {
      return AppConfig.fromJson(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  AppConfig? get currentConfig => getConfigFor();
  Future<AppConfig?> getConfig() async => currentConfig;

  Future<void> saveConfig(AppConfig config,
      {String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : config.repoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : config.repoName;

    if (o.isNotEmpty && r.isNotEmpty) {
      await _prefs.setString(_keyActiveRepoOwner, o);
      await _prefs.setString(_keyActiveRepoName, r);
    }

    final key = configKey(o, r);
    final jsonStr = jsonEncode(config.toJson());
    await _prefs.setString(key, jsonStr);

    // Also update metadata entry fund_${repoOwner}_${repoName}_metadata
    final fKey = fundKey(o, r);
    final metadata = {
      'owner': o,
      'repo': r,
      'title': config.siteTitle,
      'currency': config.currency,
      'membersCount': config.members.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(fKey, jsonEncode(metadata));

    notifyListeners();
  }

  // Fund Data Cache: fund_${repoOwner}_${repoName}_data
  FundData? getDataCacheFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;

    if (o == null || o.isEmpty || r == null || r.isEmpty) {
      return null;
    }

    final key = dataKey(o, r);
    String? str = _prefs.getString(key);
    // Backward compatibility migration for THIS specific repository only
    str ??= _prefs.getString('data_${o}_$r');

    if (str == null || str.isEmpty) return null;
    try {
      return FundData.fromJson(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  FundData? get currentDataCache => getDataCacheFor();
  Future<FundData?> getDataCache() async => currentDataCache;

  Future<void> saveDataCache(FundData data,
      {String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return;

    final key = dataKey(o, r);
    await _prefs.setString(key, jsonEncode(data.toJson()));
    notifyListeners();
  }

  // GitHub Personal Access Token: fund_${repoOwner}_${repoName}_token & global fallback
  String? getTokenFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;

    if (o != null && o.isNotEmpty && r != null && r.isNotEmpty) {
      final key = tokenKey(o, r);
      final token = _prefs.getString(key);
      if (token != null && token.isNotEmpty) return token;
      final altToken = _prefs.getString('token_${o}_$r');
      if (altToken != null && altToken.isNotEmpty) return altToken;
    }
    return _prefs.getString(_keyGlobalToken);
  }

  String? get currentToken => getTokenFor();
  Future<String?> getToken({String? owner, String? repo}) async =>
      getTokenFor(owner: owner, repo: repo);

  Future<void> saveToken(String? token, {String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    final key = tokenKey(o, r);

    if (token == null || token.trim().isEmpty) {
      await _prefs.remove(key);
      await _prefs.remove(_keyGlobalToken);
      await setAdminVerified(false, owner: o, repo: r);
    } else {
      await _prefs.setString(key, token.trim());
      await _prefs.setString(_keyGlobalToken, token.trim());
    }
    notifyListeners();
  }

  // Active User Profile: fund_${repoOwner}_${repoName}_user
  String? getUserFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;

    if (o == null || o.isEmpty || r == null || r.isEmpty) {
      return null;
    }

    final key = userKey(o, r);
    String? user = _prefs.getString(key);
    user ??= _prefs.getString('user_${o}_$r');
    return user;
  }

  String? get currentUser => getUserFor();
  Future<String?> getUser() async => currentUser;

  Future<void> saveUser(String userId, {String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return;

    final key = userKey(o, r);
    await _prefs.setString(key, userId);
    notifyListeners();
  }

  // Saved Workspaces
  List<SavedWorkspace> get savedWorkspaces {
    final list = _prefs.getStringList(_keyWorkspaces) ?? [];
    return list
        .map((item) {
          try {
            return SavedWorkspace.fromJson(jsonDecode(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedWorkspace>()
        .toList();
  }

  Future<List<SavedWorkspace>> getSavedWorkspaces() async => savedWorkspaces;

  Future<void> saveWorkspace(SavedWorkspace workspace) async {
    final current = savedWorkspaces;
    current.removeWhere(
      (w) =>
          w.owner.toLowerCase() == workspace.owner.toLowerCase() &&
          w.repo.toLowerCase() == workspace.repo.toLowerCase(),
    );
    current.insert(0, workspace);
    final encoded = current.map((w) => jsonEncode(w.toJson())).toList();
    await _prefs.setStringList(_keyWorkspaces, encoded);

    // Automatically set as active repo
    await setActiveRepo(workspace.owner, workspace.repo);

    notifyListeners();
  }

  Future<void> removeWorkspace(String owner, String repo) async {
    final current = savedWorkspaces;
    current.removeWhere(
      (w) =>
          w.owner.toLowerCase() == owner.toLowerCase() &&
          w.repo.toLowerCase() == repo.toLowerCase(),
    );
    final encoded = current.map((w) => jsonEncode(w.toJson())).toList();
    await _prefs.setStringList(_keyWorkspaces, encoded);

    // Clear fund specific keys
    await _prefs.remove(configKey(owner, repo));
    await _prefs.remove(dataKey(owner, repo));
    await _prefs.remove(fundKey(owner, repo));
    await _prefs.remove(userKey(owner, repo));
    await _prefs.remove(tokenKey(owner, repo));
    await _prefs.remove(verifiedKey(owner, repo));
    await _prefs.remove(pendingSyncKey(owner, repo));
    await _prefs.remove(pendingMsgKey(owner, repo));
    await _prefs.remove(lastRouteKey(owner, repo));
    await _prefs.remove(lastRouteTimeKey(owner, repo));
    await _prefs.remove(historyKey(owner, repo));
    await _prefs.remove(tombstonesKey(owner, repo));
    await _prefs.remove(tombstonesTxKey(owner, repo));
    await _prefs.remove(tombstonesParentKey(owner, repo));
    // Also remove old format keys if present
    await _prefs.remove('config_${owner}_$repo');
    await _prefs.remove('data_${owner}_$repo');
    await _prefs.remove('user_${owner}_$repo');
    await _prefs.remove('token_${owner}_$repo');
    await _prefs.remove('pending_sync_${owner}_$repo');
    await _prefs.remove('pending_msg_${owner}_$repo');
    await _prefs.remove('tombstones_tx_${owner}_$repo');
    await _prefs.remove('tombstones_parent_${owner}_$repo');

    if (activeRepoOwner == owner && activeRepoName == repo) {
      await _prefs.remove(_keyActiveRepoOwner);
      await _prefs.remove(_keyActiveRepoName);
    }

    notifyListeners();
  }

  // Offline Pending Sync: fund_${repoOwner}_${repoName}_pending_sync & fund_${repoOwner}_${repoName}_pending_msg
  bool hasPendingSyncFlagFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) {
      return false;
    }
    final key = pendingSyncKey(o, r);
    return _prefs.getBool(key) ??
        _prefs.getBool('pending_sync_${o}_$r') ??
        false;
  }

  bool get hasPendingSyncFlag => hasPendingSyncFlagFor();
  Future<bool> hasPendingSync() async => hasPendingSyncFlag;

  String? getPendingMessageFor({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) {
      return null;
    }
    final key = pendingMsgKey(o, r);
    return _prefs.getString(key) ?? _prefs.getString('pending_msg_${o}_$r');
  }

  String? get currentPendingMessage => getPendingMessageFor();
  Future<String?> getPendingMessage() async => currentPendingMessage;

  Future<void> setPendingSync(bool pending,
      [String? msg, String? owner, String? repo]) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return;

    final sKey = pendingSyncKey(o, r);
    final mKey = pendingMsgKey(o, r);

    await _prefs.setBool(sKey, pending);

    if (msg != null) {
      await _prefs.setString(mKey, msg);
    } else if (!pending) {
      await _prefs.remove(mKey);
    }
    notifyListeners();
  }

  Future<void> clearCacheOnly({String? owner, String? repo}) async {
    final o = owner ?? activeRepoOwner;
    final r = repo ?? activeRepoName;
    if (o != null && r != null) {
      await _prefs.remove(configKey(o, r));
      await _prefs.remove(dataKey(o, r));
      await _prefs.remove(fundKey(o, r));
      await _prefs.remove(pendingSyncKey(o, r));
      await _prefs.remove(pendingMsgKey(o, r));
      await _prefs.remove(tombstonesKey(o, r));
      await _prefs.remove(tombstonesTxKey(o, r));
      await _prefs.remove(tombstonesParentKey(o, r));
      await _prefs.remove('config_${o}_$r');
      await _prefs.remove('data_${o}_$r');
      await _prefs.remove('pending_sync_${o}_$r');
      await _prefs.remove('pending_msg_${o}_$r');
      await _prefs.remove('tombstones_tx_${o}_$r');
      await _prefs.remove('tombstones_parent_${o}_$r');
    }
    // Also purge global legacy keys once and for all
    await _prefs.remove(_legacyKeyConfig);
    await _prefs.remove(_legacyKeyConfigAlt);
    await _prefs.remove(_legacyKeyDataCache);
    await _prefs.remove(_legacyKeyDataCacheAlt);
    await _prefs.remove(_legacyKeyPendingSync);
    await _prefs.remove(_legacyKeyPendingMsg);
    notifyListeners();
  }

  // Web Route Persistence
  static const String _legacyKeyLastRoute = 'fund_last_active_route';

  List<String> getRouteHistory({String? owner, String? repo}) {
    final key = historyKey(owner, repo);
    final raw = _prefs.getStringList(key);
    if (raw != null && raw.isNotEmpty) {
      return List<String>.from(raw);
    }
    return [];
  }

  Future<void> pushRoute(String route, {String? owner, String? repo}) async {
    final key = historyKey(owner, repo);
    var history = getRouteHistory(owner: owner, repo: repo);
    if (history.isNotEmpty && history.last == route) {
      await setLastRoute(route, owner: owner, repo: repo);
      return;
    }
    // If route is a root/tab route, reset base history to avoid unbounded backstack
    if (route == 'transactions' ||
        route == 'people' ||
        route == 'expenses' ||
        route == 'admin') {
      history = [route];
    } else {
      final existingIndex = history.indexOf(route);
      if (existingIndex != -1) {
        history = history.sublist(0, existingIndex + 1);
      } else {
        history.add(route);
      }
    }
    if (history.length > 20) {
      history = history.sublist(history.length - 20);
    }
    await _prefs.setStringList(key, history);
    await setLastRoute(route, owner: owner, repo: repo);
  }

  Future<String?> popRoute({String? owner, String? repo}) async {
    final key = historyKey(owner, repo);
    final history = getRouteHistory(owner: owner, repo: repo);
    if (history.length > 1) {
      history.removeLast();
      final newTop = history.last;
      await _prefs.setStringList(key, history);
      await setLastRoute(newTop, owner: owner, repo: repo);
      return newTop;
    } else if (history.length == 1) {
      return history.first;
    }
    return null;
  }

  String? getPreviousRoute({String? owner, String? repo}) {
    final history = getRouteHistory(owner: owner, repo: repo);
    if (history.length >= 2) {
      return history[history.length - 2];
    }
    return null;
  }

  String? getLastRoute({String? owner, String? repo}) {
    final key = lastRouteKey(owner, repo);
    final timeKey = lastRouteTimeKey(owner, repo);

    final savedTime = _prefs.getInt(timeKey) ??
        _prefs.getInt(timeKey.toLowerCase()) ??
        _prefs.getInt(_legacyKeyLastRouteTime);

    if (savedTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - savedTime;
      if (elapsed > routeCacheMaxAgeMs) {
        // Cache expired after 10 minutes - clear cached route and history
        _prefs.remove(key);
        _prefs.remove(key.toLowerCase());
        _prefs.remove(timeKey);
        _prefs.remove(timeKey.toLowerCase());
        _prefs.remove(_legacyKeyLastRoute);
        _prefs.remove(_legacyKeyLastRouteTime);
        _prefs.remove(historyKey(owner, repo));
        return null;
      }
    }

    return _prefs.getString(key) ??
        _prefs.getString(key.toLowerCase()) ??
        _prefs.getString(_legacyKeyLastRoute);
  }

  Future<void> setLastRoute(String route, {String? owner, String? repo}) async {
    final key = lastRouteKey(owner, repo);
    final timeKey = lastRouteTimeKey(owner, repo);
    await _prefs.setString(key, route);
    await _prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearSession({String? owner, String? repo}) async {
    final o = owner ?? activeRepoOwner;
    final r = repo ?? activeRepoName;
    if (o != null && r != null) {
      await _prefs.remove(configKey(o, r));
      await _prefs.remove(dataKey(o, r));
      await _prefs.remove(fundKey(o, r));
      await _prefs.remove(userKey(o, r));
      await _prefs.remove(tokenKey(o, r));
      await _prefs.remove(verifiedKey(o, r));
      await _prefs.remove(pendingSyncKey(o, r));
      await _prefs.remove(pendingMsgKey(o, r));
      await _prefs.remove(lastRouteKey(o, r));
      await _prefs.remove(lastRouteTimeKey(o, r));
      await _prefs.remove(historyKey(o, r));
      await _prefs.remove(tombstonesKey(o, r));
      await _prefs.remove(tombstonesTxKey(o, r));
      await _prefs.remove(tombstonesParentKey(o, r));
      await _prefs.remove('config_${o}_$r');
      await _prefs.remove('data_${o}_$r');
      await _prefs.remove('user_${o}_$r');
      await _prefs.remove('token_${o}_$r');
      await _prefs.remove('pending_sync_${o}_$r');
      await _prefs.remove('pending_msg_${o}_$r');
      await _prefs.remove('tombstones_tx_${o}_$r');
      await _prefs.remove('tombstones_parent_${o}_$r');
    }
    await _prefs.remove(_legacyKeyConfig);
    await _prefs.remove(_legacyKeyConfigAlt);
    await _prefs.remove(_legacyKeyDataCache);
    await _prefs.remove(_legacyKeyDataCacheAlt);
    await _prefs.remove(_legacyKeyUser);
    await _prefs.remove(_legacyKeyPendingSync);
    await _prefs.remove(_legacyKeyPendingMsg);
    await _prefs.remove(_legacyKeyLastRoute);
    await _prefs.remove(_legacyKeyLastRouteTime);
    notifyListeners();
  }

  // Deletion Tombstones: fund_${repoOwner}_${repoName}_tombstones & fund_${repoOwner}_${repoName}_tombstones_tx
  static String tombstonesTxKey(String? owner, String? repo) {
    if (owner != null && owner.isNotEmpty && repo != null && repo.isNotEmpty) {
      return 'fund_${owner}_${repo}_tombstones_tx';
    }
    return 'fund_tombstones_tx';
  }

  static String tombstonesParentKey(String? owner, String? repo) {
    if (owner != null && owner.isNotEmpty && repo != null && repo.isNotEmpty) {
      return 'fund_${owner}_${repo}_tombstones_parent';
    }
    return 'fund_tombstones_parent';
  }

  Set<String> getDeletedTxIds({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return <String>{};
    final list = _prefs.getStringList(tombstonesKey(o, r)) ??
        _prefs.getStringList(tombstonesTxKey(o, r)) ??
        _prefs.getStringList('tombstones_tx_${o}_$r');
    return list != null ? list.toSet() : <String>{};
  }

  Set<String> getDeletedParentIds({String? owner, String? repo}) {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return <String>{};
    final list = _prefs.getStringList(tombstonesParentKey(o, r)) ??
        _prefs.getStringList('tombstones_parent_${o}_$r');
    return list != null ? list.toSet() : <String>{};
  }

  Future<void> addDeletedTombstone(
      {String? txId, String? parentId, String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return;
    if (txId != null && txId.isNotEmpty) {
      final current = getDeletedTxIds(owner: o, repo: r);
      current.add(txId);
      await _prefs.setStringList(tombstonesKey(o, r), current.toList());
      await _prefs.setStringList(tombstonesTxKey(o, r), current.toList());
    }
    if (parentId != null && parentId.isNotEmpty) {
      final current = getDeletedParentIds(owner: o, repo: r);
      current.add(parentId);
      await _prefs.setStringList(tombstonesParentKey(o, r), current.toList());
    }
  }

  Future<void> removeDeletedTombstones(
      {Set<String>? txIds,
      Set<String>? parentIds,
      String? owner,
      String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : activeRepoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : activeRepoName;
    if (o == null || o.isEmpty || r == null || r.isEmpty) return;
    if (txIds != null && txIds.isNotEmpty) {
      final current = getDeletedTxIds(owner: o, repo: r);
      current.removeAll(txIds);
      await _prefs.setStringList(tombstonesKey(o, r), current.toList());
      await _prefs.setStringList(tombstonesTxKey(o, r), current.toList());
    }
    if (parentIds != null && parentIds.isNotEmpty) {
      final current = getDeletedParentIds(owner: o, repo: r);
      current.removeAll(parentIds);
      await _prefs.setStringList(tombstonesParentKey(o, r), current.toList());
    }
  }
}
