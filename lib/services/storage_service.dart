import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/pending_operation.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _configKey = 'fund.config';
  static const _dataKey = 'fund.data';
  static const _tokenKey = 'fund.token';
  static const _userKey = 'fund.user';
  static const _pendingOpsKey = 'fund.pending_ops';

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

  String? loadToken() => _prefs.getString(_tokenKey);

  Future<void> saveToken(String token) async => _prefs.setString(_tokenKey, token);

  Future<void> clearToken() async => _prefs.remove(_tokenKey);

  String? loadUser() => _prefs.getString(_userKey);

  Future<void> saveUser(String userId) async => _prefs.setString(_userKey, userId);

  Future<void> clearUser() async => _prefs.remove(_userKey);

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
}
