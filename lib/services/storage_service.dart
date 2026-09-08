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

  // Helper key generators: ${prefix}_${repoOwner}_${repoName}
  String _formatKey(String prefix, [String? owner, String? repo]) {
    final o = (owner != null && owner.isNotEmpty)
        ? owner
        : (activeRepoOwner ?? _findFallbackOwner());
    final r = (repo != null && repo.isNotEmpty)
        ? repo
        : (activeRepoName ?? _findFallbackRepo());

    if (o.isNotEmpty && r.isNotEmpty) {
      return '${prefix}_${o}_$r';
    }
    return prefix;
  }

  String _findFallbackOwner() {
    final legacyStr = _prefs.getString(_legacyKeyConfig) ?? _prefs.getString(_legacyKeyConfigAlt);
    if (legacyStr != null) {
      try {
        final j = jsonDecode(legacyStr);
        if (j is Map && j['repoOwner'] != null) return j['repoOwner'];
      } catch (_) {}
    }
    return '';
  }

  String _findFallbackRepo() {
    final legacyStr = _prefs.getString(_legacyKeyConfig) ?? _prefs.getString(_legacyKeyConfigAlt);
    if (legacyStr != null) {
      try {
        final j = jsonDecode(legacyStr);
        if (j is Map && j['repoName'] != null) return j['repoName'];
      } catch (_) {}
    }
    return '';
  }

  // Key names per repository
  String configKey([String? owner, String? repo]) => _formatKey('config', owner, repo);
  String dataKey([String? owner, String? repo]) => _formatKey('data', owner, repo);
  String fundKey([String? owner, String? repo]) => _formatKey('fund', owner, repo);
  String userKey([String? owner, String? repo]) => _formatKey('user', owner, repo);
  String tokenKey([String? owner, String? repo]) => _formatKey('token', owner, repo);
  String verifiedKey([String? owner, String? repo]) => _formatKey('admin_verified', owner, repo);
  String pendingSyncKey([String? owner, String? repo]) => _formatKey('pending_sync', owner, repo);
  String pendingMsgKey([String? owner, String? repo]) => _formatKey('pending_msg', owner, repo);
  String lastRouteKey([String? owner, String? repo]) {
    final o = (owner != null && owner.isNotEmpty)
        ? owner
        : (activeRepoOwner ?? _findFallbackOwner());
    final r = (repo != null && repo.isNotEmpty)
        ? repo
        : (activeRepoName ?? _findFallbackRepo());

    if (o.isNotEmpty && r.isNotEmpty) {
      return 'Fund_${o}_${r}_last_active_route';
    }
    return 'Fund_last_active_route';
  }

  String lastRouteTimeKey([String? owner, String? repo]) {
    final o = (owner != null && owner.isNotEmpty)
        ? owner
        : (activeRepoOwner ?? _findFallbackOwner());
    final r = (repo != null && repo.isNotEmpty)
        ? repo
        : (activeRepoName ?? _findFallbackRepo());

    if (o.isNotEmpty && r.isNotEmpty) {
      return 'Fund_${o}_${r}_last_active_route_time';
    }
    return 'Fund_last_active_route_time';
  }

  static const String _legacyKeyLastRouteTime = 'fund_last_active_route_time';
  static const int routeCacheMaxAgeMs = 10 * 60 * 1000; // 10 minutes cache expiration

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

  Future<void> setAdminVerified(bool verified, {String? owner, String? repo}) async {
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

  // App Config: config_${repoOwner}_${repoName}
  AppConfig? getConfigFor({String? owner, String? repo}) {
    final key = configKey(owner, repo);
    String? str = _prefs.getString(key);

    // Fallback to legacy keys if namespaced key not found
    str ??= _prefs.getString(_legacyKeyConfig);
    str ??= _prefs.getString(_legacyKeyConfigAlt);

    if (str == null || str.isEmpty) return null;
    try {
      return AppConfig.fromJson(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  AppConfig? get currentConfig => getConfigFor();
  Future<AppConfig?> getConfig() async => currentConfig;

  Future<void> saveConfig(AppConfig config, {String? owner, String? repo}) async {
    final o = (owner != null && owner.isNotEmpty) ? owner : config.repoOwner;
    final r = (repo != null && repo.isNotEmpty) ? repo : config.repoName;

    if (o.isNotEmpty && r.isNotEmpty) {
      await _prefs.setString(_keyActiveRepoOwner, o);
      await _prefs.setString(_keyActiveRepoName, r);
    }

    final key = configKey(o, r);
    final jsonStr = jsonEncode(config.toJson());
    await _prefs.setString(key, jsonStr);

    // Also update metadata entry fund_${repoOwner}_${repoName}
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

  // Fund Data Cache: data_${repoOwner}_${repoName}
  FundData? getDataCacheFor({String? owner, String? repo}) {
    final key = dataKey(owner, repo);
    String? str = _prefs.getString(key);

    // Fallback to legacy keys
    str ??= _prefs.getString(_legacyKeyDataCache);
    str ??= _prefs.getString(_legacyKeyDataCacheAlt);

    if (str == null || str.isEmpty) return null;
    try {
      return FundData.fromJson(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }

  FundData? get currentDataCache => getDataCacheFor();
  Future<FundData?> getDataCache() async => currentDataCache;

  Future<void> saveDataCache(FundData data, {String? owner, String? repo}) async {
    final key = dataKey(owner, repo);
    await _prefs.setString(key, jsonEncode(data.toJson()));
    notifyListeners();
  }

  // GitHub Personal Access Token: token_${repoOwner}_${repoName} & global fallback
  String? getTokenFor({String? owner, String? repo}) {
    final key = tokenKey(owner, repo);
    final token = _prefs.getString(key);
    if (token != null && token.isNotEmpty) return token;
    return _prefs.getString(_keyGlobalToken);
  }

  String? get currentToken => getTokenFor();
  Future<String?> getToken({String? owner, String? repo}) async => getTokenFor(owner: owner, repo: repo);

  Future<void> saveToken(String? token, {String? owner, String? repo}) async {
    final key = tokenKey(owner, repo);
    if (token == null || token.trim().isEmpty) {
      await _prefs.remove(key);
      await _prefs.remove(_keyGlobalToken);
      await setAdminVerified(false, owner: owner, repo: repo);
    } else {
      await _prefs.setString(key, token.trim());
      await _prefs.setString(_keyGlobalToken, token.trim());
    }
    notifyListeners();
  }

  // Active User Profile: user_${repoOwner}_${repoName}
  String? getUserFor({String? owner, String? repo}) {
    final key = userKey(owner, repo);
    String? user = _prefs.getString(key);
    user ??= _prefs.getString(_legacyKeyUser);
    return user;
  }

  String? get currentUser => getUserFor();
  Future<String?> getUser() async => currentUser;

  Future<void> saveUser(String userId, {String? owner, String? repo}) async {
    final key = userKey(owner, repo);
    await _prefs.setString(key, userId);
    await _prefs.setString(_legacyKeyUser, userId);
    notifyListeners();
  }

  // Saved Workspaces
  List<SavedWorkspace> get savedWorkspaces {
    final list = _prefs.getStringList(_keyWorkspaces) ?? [];
    return list.map((item) {
      try {
        return SavedWorkspace.fromJson(jsonDecode(item));
      } catch (_) {
        return null;
      }
    }).whereType<SavedWorkspace>().toList();
  }

  Future<List<SavedWorkspace>> getSavedWorkspaces() async => savedWorkspaces;

  Future<void> saveWorkspace(SavedWorkspace workspace) async {
    final current = savedWorkspaces;
    current.removeWhere(
      (w) => w.owner.toLowerCase() == workspace.owner.toLowerCase() &&
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
      (w) => w.owner.toLowerCase() == owner.toLowerCase() &&
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

    notifyListeners();
  }

  // Offline Pending Sync: pending_sync_${repoOwner}_${repoName} & pending_msg_${repoOwner}_${repoName}
  bool hasPendingSyncFlagFor({String? owner, String? repo}) {
    final key = pendingSyncKey(owner, repo);
    final val = _prefs.getBool(key);
    if (val != null) return val;
    return _prefs.getBool(_legacyKeyPendingSync) ?? false;
  }

  bool get hasPendingSyncFlag => hasPendingSyncFlagFor();
  Future<bool> hasPendingSync() async => hasPendingSyncFlag;

  String? getPendingMessageFor({String? owner, String? repo}) {
    final key = pendingMsgKey(owner, repo);
    final msg = _prefs.getString(key);
    if (msg != null) return msg;
    return _prefs.getString(_legacyKeyPendingMsg);
  }

  String? get currentPendingMessage => getPendingMessageFor();
  Future<String?> getPendingMessage() async => currentPendingMessage;

  Future<void> setPendingSync(bool pending, [String? msg, String? owner, String? repo]) async {
    final sKey = pendingSyncKey(owner, repo);
    final mKey = pendingMsgKey(owner, repo);

    await _prefs.setBool(sKey, pending);
    await _prefs.setBool(_legacyKeyPendingSync, pending);

    if (msg != null) {
      await _prefs.setString(mKey, msg);
      await _prefs.setString(_legacyKeyPendingMsg, msg);
    } else if (!pending) {
      await _prefs.remove(mKey);
      await _prefs.remove(_legacyKeyPendingMsg);
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
    }
    await _prefs.remove(_legacyKeyConfig);
    await _prefs.remove(_legacyKeyDataCache);
    await _prefs.remove(_legacyKeyPendingSync);
    await _prefs.remove(_legacyKeyPendingMsg);
    notifyListeners();
  }

  // Web Route Persistence
  static const String _legacyKeyLastRoute = 'fund_last_active_route';

  String historyKey([String? owner, String? repo]) {
    final o = (owner != null && owner.isNotEmpty)
        ? owner
        : (activeRepoOwner ?? _findFallbackOwner());
    final r = (repo != null && repo.isNotEmpty)
        ? repo
        : (activeRepoName ?? _findFallbackRepo());

    if (o.isNotEmpty && r.isNotEmpty) {
      return 'Fund_${o}_${r}_route_history';
    }
    return 'Fund_route_history';
  }

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
    if (route == 'transactions' || route == 'people' || route == 'expenses' || route == 'admin') {
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
    }
    await _prefs.remove(_legacyKeyConfig);
    await _prefs.remove(_legacyKeyDataCache);
    await _prefs.remove(_legacyKeyUser);
    await _prefs.remove(_legacyKeyPendingSync);
    await _prefs.remove(_legacyKeyPendingMsg);
    await _prefs.remove(_legacyKeyLastRoute);
    await _prefs.remove(_legacyKeyLastRouteTime);
    notifyListeners();
  }
}
