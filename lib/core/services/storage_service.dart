import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/instance_info.dart';
import '../network/endpoints.dart';

class StorageService {
  static const _keyAccessToken = 'ag_access_token';
  static const _keyEnvironment = 'ag_environment';
  static const _keyInstances = 'ag_instances';
  static const _keyDemoMode = 'ag_demo_mode';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Google OAuth / Bearer Token
  String? getAccessToken() => _prefs.getString(_keyAccessToken);
  Future<void> setAccessToken(String token) => _prefs.setString(_keyAccessToken, token);
  Future<void> clearAccessToken() => _prefs.remove(_keyAccessToken);

  // Cloud Endpoint Environment
  CloudEnvironment getEnvironment() {
    final raw = _prefs.getString(_keyEnvironment);
    return CloudEnvironment.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CloudEnvironment.production,
    );
  }

  Future<void> setEnvironment(CloudEnvironment env) =>
      _prefs.setString(_keyEnvironment, env.name);

  // Demo Mode
  bool isDemoMode() => _prefs.getBool(_keyDemoMode) ?? true;
  Future<void> setDemoMode(bool enabled) => _prefs.setBool(_keyDemoMode, enabled);

  // Paired Devices List
  List<InstanceInfo> getSavedInstances() {
    final rawList = _prefs.getStringList(_keyInstances);
    if (rawList == null) return [];

    return rawList
        .map((str) {
          try {
            return InstanceInfo.fromJson(jsonDecode(str) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<InstanceInfo>()
        .toList();
  }

  Future<void> saveInstance(InstanceInfo instance) async {
    final list = getSavedInstances();
    final index = list.indexWhere((e) => e.instanceId == instance.instanceId);
    if (index != -1) {
      list[index] = instance;
    } else {
      list.insert(0, instance);
    }

    final encoded = list.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_keyInstances, encoded);
  }

  Future<void> removeInstance(String instanceId) async {
    final list = getSavedInstances();
    list.removeWhere((e) => e.instanceId == instanceId);
    final encoded = list.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_keyInstances, encoded);
  }
}
