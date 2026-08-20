import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/pending_operation.dart';
import '../models/saved_repo.dart';

class StorageService {
  StorageService(this._prefs) {
    _loadLastPrefix();
  }

  final SharedPreferences _prefs;
  String _prefix = 'fund_';

  static const String _savedReposKey = 'fund_saved_repos_v2';

  void _loadLastPrefix() {
    final last = _prefs.getString('fund_last_repo');
    if (last != null && last.isNotEmpty) {
      _prefix = last;
    }
  }

  void setRepo(String owner, String repo) {
    if (owner.isNotEmpty && repo.isNotEmpty) {
      _prefix = '${owner.toLowerCase().trim()}_${repo.toLowerCase().trim()}_';
      _prefs.setString('fund_last_repo', _prefix);
    }
  }

  List<SavedRepo> loadSavedRepos() {
    final raw = _prefs.getString(_savedReposKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => SavedRepo.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSavedRepo(SavedRepo repo) async {
    final current = loadSavedRepos().toList();
    final index = current.indexWhere((r) => r.id == repo.id || (r.owner.toLowerCase() == repo.owner.toLowerCase() && r.repo.toLowerCase() == repo.repo.toLowerCase() && r.branch == repo.branch && r.dataFileName == repo.dataFileName));
    if (index >= 0) {
      current[index] = repo;
    } else {
      current.add(repo);
    }
    final payload = current.map((e) => e.toJson()).toList();
    await _prefs.setString(_savedReposKey, jsonEncode(payload));
  }

  Future<void> deleteSavedRepo(String id) async {
    final current = loadSavedRepos().where((r) => r.id != id).toList();
    final payload = current.map((e) => e.toJson()).toList();
    await _prefs.setString(_savedReposKey, jsonEncode(payload));
  }

  String get _configKey => '${_prefix}config';
  String get _dataKey => '${_prefix}data';
  String get _tokenKey => '${_prefix}token';
  String get _userKey => '${_prefix}user';
  String get _pendingOpsKey => '${_prefix}pending_ops';

  AppConfig? loadConfig() {
    final raw = _prefs.getString(_configKey);
    if (raw == null) return null;
    try {
      return AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    await _prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  FundData? loadData() {
    final raw = _prefs.getString(_dataKey);
    if (raw == null) return null;
    try {
      return FundData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveData(FundData data) async {
    await _prefs.setString(_dataKey, jsonEncode(data.toJson()));
  }

  String? loadToken() {
    final token = _prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) return token;
    final fallback = _prefs.getString('fund_token');
    if (fallback != null && fallback.isNotEmpty) return fallback;
    // Check saved repos
    for (final repo in loadSavedRepos()) {
      if (repo.token != null && repo.token!.isNotEmpty) {
        return repo.token;
      }
    }
    return null;
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString('fund_token', token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove('fund_token');
  }

  String? loadUser() => _prefs.getString(_userKey);

  Future<void> saveUser(String userId) async => _prefs.setString(_userKey, userId);

  Future<void> clearUser() async => _prefs.remove(_userKey);

  String get _themeModeKey => 'fund_app_theme_mode';

  int? loadThemeMode() => _prefs.getInt(_themeModeKey);

  Future<void> saveThemeMode(int mode) async => _prefs.setInt(_themeModeKey, mode);

  List<PendingOperation> loadPendingOperations() {
    final raw = _prefs.getString(_pendingOpsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => PendingOperation.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingOperations(List<PendingOperation> operations) async {
    final payload = operations.map((e) => e.toJson()).toList();
    await _prefs.setString(_pendingOpsKey, jsonEncode(payload));
  }

  Future<void> clearAll() async {
    await _prefs.remove(_configKey);
    await _prefs.remove(_dataKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    await _prefs.remove(_pendingOpsKey);
    await _prefs.remove('fund_last_repo');
    _prefix = 'fund_';
  }
}
