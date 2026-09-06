import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/network/endpoints.dart';
import 'package:antigravity_remote/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Security & Encryption Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getAccessToken returns null when no token is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      expect(storage.getAccessToken(), isNull);
    });

    test('setAccessToken encrypts token with AES-256-GCM and does not leak plaintext', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      const secretToken = 'ya29.a0AfH6SMA-super-sensitive-oauth-token-12345';
      await storage.setAccessToken(secretToken);

      // Verify that the raw SharedPreferences string is encrypted
      final rawStored = prefs.getString('ag_access_token');
      expect(rawStored, isNotNull);
      expect(rawStored!.startsWith('enc:v1:'), isTrue);
      expect(rawStored.contains(secretToken), isFalse);

      // Verify that getAccessToken correctly decrypts it
      final decrypted = storage.getAccessToken();
      expect(decrypted, secretToken);
    });

    test('getAccessToken provides backward compatibility with legacy plaintext tokens', () async {
      SharedPreferences.setMockInitialValues({
        'ag_access_token': 'ya29.legacy-unencrypted-token-value',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Legacy token without 'enc:v1:' prefix should be returned directly
      expect(storage.getAccessToken(), 'ya29.legacy-unencrypted-token-value');
    });

    test('getAccessToken gracefully returns null on tampered ciphertext', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await storage.setAccessToken('sensitive-token');
      final validEncrypted = prefs.getString('ag_access_token')!;

      // Tamper with the ciphertext/MAC payload
      final tampered = '${validEncrypted.substring(0, validEncrypted.length - 6)}AAAAAA';
      await prefs.setString('ag_access_token', tampered);

      // Decryption MAC validation failure should return null without crashing
      expect(storage.getAccessToken(), isNull);
    });

    test('clearAccessToken removes the token', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await storage.setAccessToken('token-to-delete');
      expect(storage.getAccessToken(), 'token-to-delete');

      await storage.clearAccessToken();
      expect(storage.getAccessToken(), isNull);
      expect(prefs.containsKey('ag_access_token'), isFalse);
    });

    test('setAccessToken with empty string automatically clears the token', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await storage.setAccessToken('temporary-token');
      expect(storage.getAccessToken(), 'temporary-token');

      await storage.setAccessToken('');
      expect(storage.getAccessToken(), isNull);
      expect(prefs.containsKey('ag_access_token'), isFalse);
    });

    test('stores and retrieves environment and demo mode', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      expect(storage.isDemoMode(), isTrue);
      await storage.setDemoMode(false);
      expect(storage.isDemoMode(), isFalse);

      expect(storage.getEnvironment(), CloudEnvironment.production);
      await storage.setEnvironment(CloudEnvironment.daily);
      expect(storage.getEnvironment(), CloudEnvironment.daily);
    });

    test('saves and removes instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      expect(storage.getSavedInstances(), isEmpty);

      final dev1 = InstanceInfo(
        instanceId: 'inst-1',
        uuid: 'uuid-1',
        name: 'Mac-1',
        lastSeen: DateTime.now(),
      );
      final dev2 = InstanceInfo(
        instanceId: 'inst-2',
        uuid: 'uuid-2',
        name: 'Mac-2',
        lastSeen: DateTime.now(),
      );

      await storage.saveInstance(dev1);
      await storage.saveInstance(dev2);

      final saved = storage.getSavedInstances();
      expect(saved.length, 2);
      expect(saved.any((d) => d.instanceId == 'inst-1'), isTrue);
      expect(saved.any((d) => d.instanceId == 'inst-2'), isTrue);

      await storage.removeInstance('inst-1');
      final afterRemove = storage.getSavedInstances();
      expect(afterRemove.length, 1);
      expect(afterRemove.first.instanceId, 'inst-2');
    });
  });
}
