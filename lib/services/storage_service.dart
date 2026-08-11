
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';
import '../models/fund_data.dart';

class StorageService {
  static const String _configKey = 'config';
  static const String _dataKey = 'data';
  static const String _tokenKey = 'pat';
  static const String _tokenTimeKey = 'pat_time';
  static const String _pendingOpsKey = 'pending_ops';
  static const String _userKey = 'selected_user';
  static const String _savedReposKey = 'saved_repos';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ------ Config ------
  AppConfig? loadConfig() {
    final jsonStr = _prefs.getString(_configKey);
    if (jsonStr == null) return null;
    try {
      return AppConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final json = jsonEncode(config.toJson());
    await _prefs.setString(_configKey, json);
  }

  // ------ Data ------
  FundData? loadData() {
    final jsonStr = _prefs.getString(_dataKey);
    if (jsonStr == null) return null;
    try {
      return FundData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveData(FundData data) async {
    final json = jsonEncode(data.toJson());
    await _prefs.setString(_dataKey, json);
  }

  // ------ Token ------
  String? loadToken() {
    final token = _prefs.getString(_tokenKey);
    final timeStr = _prefs.getString(_tokenTimeKey);
    if (token == null || timeStr == null) return null;
    final time = int.tryParse(timeStr);
    if (time == null) return null;
    // 30 days validity
    if (DateTime.now().millisecondsSinceEpoch - time > 30 * 24 * 60 * 60 * 1000) {
      return null;
    }
    return token;
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(
        _tokenTimeKey, DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_tokenTimeKey);
  }

  // ------ User ------
  String? loadUser() {
    return _prefs.getString(_userKey);
  }

  Future<void> saveUser(String userId) async {
    await _prefs.setString(_userKey, userId);
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  // ------ Pending Operations ------
  List<Map<String, dynamic>> loadPendingOps() {
    final jsonStr = _prefs.getString(_pendingOpsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingOps(List<Map<String, dynamic>> ops) async {
    final json = jsonEncode(ops);
    await _prefs.setString(_pendingOpsKey, json);
  }

  // ------ Saved Repos (for mobile) ------
  List<String> loadSavedRepos() {
    final jsonStr = _prefs.getString(_savedReposKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavedRepos(List<String> repos) async {
    final json = jsonEncode(repos);
    await _prefs.setString(_savedReposKey, json);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

