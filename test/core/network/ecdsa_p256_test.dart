import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/network/ecdsa_p256_service.dart';

void main() {
  group('EcdsaP256Service Tests', () {
    test('generate() creates valid P-256 key pair and 91-byte SPKI public key', () {
      final crypto = EcdsaP256Service.generate();

      final spki = crypto.getSpkiPublicKeyBytes();
      expect(spki.length, 91);
      expect(spki[0], 0x30); // SEQUENCE
      expect(spki[1], 0x59); // 89 bytes

      final spkiB64 = crypto.getSpkiPublicKeyBase64();
      expect(spkiB64.isNotEmpty, isTrue);
      expect(base64Decode(spkiB64).length, 91);
    });

    test('sign and verify channel binding challenge nonce', () {
      final crypto = EcdsaP256Service.generate();
      const nonce = 'antigravity-dtls-challenge-nonce-998877';

      final derSig = crypto.sign(utf8.encode(nonce));
      expect(derSig[0], 0x30);
      expect(derSig.length >= 68 && derSig.length <= 73, isTrue);

      final isValid = crypto.verify(utf8.encode(nonce), derSig);
      expect(isValid, isTrue);

      // Fails on tampered message
      final isTamperedValid = crypto.verify(utf8.encode('tampered-nonce'), derSig);
      expect(isTamperedValid, isFalse);
    });

    test('signBase64 returns valid base64 signature', () {
      final crypto = EcdsaP256Service.generate();
      const challenge = 'challenge-nonce-uuid';

      final sigB64 = crypto.signBase64(challenge);
      expect(sigB64.isNotEmpty, isTrue);

      final sigBytes = base64Decode(sigB64);
      final isValid = crypto.verify(utf8.encode(challenge), sigBytes);
      expect(isValid, isTrue);
    });
  });
}
