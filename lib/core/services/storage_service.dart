import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/instance_info.dart';
import '../network/endpoints.dart';

/// 加密金鑰與 AES-256-GCM 處理模組
class _TokenVaultCrypto {
  static const int _ivLength = 12; // 96-bit nonce for GCM
  static const int _macLengthBits = 128;

  static Uint8List deriveKey(String salt) {
    final digest = SHA256Digest();
    final input = utf8.encode('antigravity_token_vault_v1:$salt');
    return digest.process(Uint8List.fromList(input));
  }

  static String encrypt(String plaintext, Uint8List key) {
    final random = Random.secure();
    final iv = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), _macLengthBits, iv, Uint8List(0));
    cipher.init(true, params);

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = cipher.process(input);

    return 'enc:v1:${base64Url.encode(iv)}:${base64Url.encode(output)}';
  }

  static String? decrypt(String ciphertext, Uint8List key) {
    if (!ciphertext.startsWith('enc:v1:')) {
      // 相容既有舊版明文 Token
      return ciphertext;
    }

    final parts = ciphertext.split(':');
    if (parts.length != 4) return null;

    try {
      final iv = base64Url.decode(parts[2]);
      final payload = base64Url.decode(parts[3]);

      final decipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        _macLengthBits,
        Uint8List.fromList(iv),
        Uint8List(0),
      );
      decipher.init(false, params);

      final decrypted = decipher.process(Uint8List.fromList(payload));
      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }
}

enum BootState {
  ready,
  degraded,
  failed,
}

class StorageService {
  static const _keyAccessToken = 'ag_access_token';
  static const _keyTokenSalt = 'ag_token_salt';
  static const _keyEnvironment = 'ag_environment';
  static const _keyInstances = 'ag_instances';
  static const _keyDemoMode = 'ag_demo_mode';

  static BootState lastBootState = BootState.ready;

  final SharedPreferences _prefs;
  final BootState bootState;

  StorageService(this._prefs, {this.bootState = BootState.ready});

  static Future<StorageService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lastBootState = BootState.ready;
      return StorageService(prefs, bootState: BootState.ready);
    } catch (_) {
      lastBootState = BootState.degraded;
      rethrow;
    }
  }

  Future<String> _getOrCreateSaltAsync() async {
    var salt = _prefs.getString(_keyTokenSalt);
    if (salt == null || salt.isEmpty) {
      final rand = Random.secure();
      final bytes = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        bytes[i] = rand.nextInt(256);
      }
      salt = base64Url.encode(bytes);
      await _prefs.setString(_keyTokenSalt, salt);
    }
    return salt;
  }

  String _getOrCreateSalt() {
    var salt = _prefs.getString(_keyTokenSalt);
    if (salt == null || salt.isEmpty) {
      final rand = Random.secure();
      final bytes = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        bytes[i] = rand.nextInt(256);
      }
      salt = base64Url.encode(bytes);
      _prefs.setString(_keyTokenSalt, salt);
    }
    return salt;
  }

  Uint8List get _vaultKey => _TokenVaultCrypto.deriveKey(_getOrCreateSalt());

  // Google OAuth / Bearer Token (AES-256-GCM 加密保護，避免明文落盤)
  String? getAccessToken() {
    final raw = _prefs.getString(_keyAccessToken);
    if (raw == null || raw.isEmpty) return null;
    return _TokenVaultCrypto.decrypt(raw, _vaultKey);
  }

  Future<void> setAccessToken(String token) async {
    if (token.isEmpty) {
      await clearAccessToken();
      return;
    }
    final salt = await _getOrCreateSaltAsync();
    final key = _TokenVaultCrypto.deriveKey(salt);
    final encrypted = _TokenVaultCrypto.encrypt(token, key);
    await _prefs.setString(_keyAccessToken, encrypted);
  }

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
