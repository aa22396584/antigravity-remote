import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/network/ecdsa_p256_service.dart';

void main() {
  group('EcdsaP256Service Tests', () {
    test(
      'generate() creates valid P-256 key pair and 91-byte SPKI public key',
      () {
        final crypto = EcdsaP256Service.generate();

        final spki = crypto.getSpkiPublicKeyBytes();
        expect(spki.length, 91);
        expect(spki[0], 0x30); // SEQUENCE
        expect(spki[1], 0x59); // 89 bytes

        final spkiB64 = crypto.getSpkiPublicKeyBase64();
        expect(spkiB64.isNotEmpty, isTrue);
        expect(base64Decode(spkiB64).length, 91);
      },
    );

    test('sign and verify channel binding challenge nonce', () {
      final crypto = EcdsaP256Service.generate();
      const nonce = 'antigravity-dtls-challenge-nonce-998877';

      final derSig = crypto.sign(utf8.encode(nonce));
      expect(derSig[0], 0x30);
      expect(derSig.length >= 68 && derSig.length <= 73, isTrue);

      final isValid = crypto.verify(utf8.encode(nonce), derSig);
      expect(isValid, isTrue);

      // Fails on tampered message
      final isTamperedValid = crypto.verify(
        utf8.encode('tampered-nonce'),
        derSig,
      );
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

    test('strict DER rejects trailing garbage bytes (Issue #30)', () {
      final crypto = EcdsaP256Service.generate();
      const msg = 'test-trailing-bytes';
      final validDer = crypto.sign(utf8.encode(msg));

      // Append trailing byte
      final withTrailing = Uint8List.fromList([...validDer, 0x00]);
      expect(crypto.verify(utf8.encode(msg), withTrailing), isFalse);
      expect(DerSignature.tryParseDer(withTrailing), isNull);
    });

    test('strict DER rejects tampered sequence length (Issue #30)', () {
      final crypto = EcdsaP256Service.generate();
      const msg = 'test-seq-length';
      final validDer = Uint8List.fromList(crypto.sign(utf8.encode(msg)));

      // Modify sequence length to be smaller or larger
      validDer[1] = validDer[1] + 1;
      expect(crypto.verify(utf8.encode(msg), validDer), isFalse);
      expect(DerSignature.tryParseDer(validDer), isNull);
    });

    test(
      'strict DER rejects redundant leading zeros in integers (Issue #30)',
      () {
        // Construct a signature with redundant 0x00 prefix: [0x30, ..., 0x02, len, 0x00, 0x00, ...]
        final malformed = Uint8List.fromList([
          0x30, 0x46,
          0x02, 0x21, 0x00, 0x00, ...List.filled(31, 0x01), // Redundant 0x00
          0x02, 0x20, ...List.filled(32, 0x02),
        ]);
        expect(DerSignature.tryParseDer(malformed), isNull);
      },
    );

    test(
      'bidirectional conversion between DER and IEEE P1363 64-byte raw format (Issue #30)',
      () {
        final crypto = EcdsaP256Service.generate();
        const msg = 'p1363-conversion-test';

        final p1363 = crypto.signRaw(utf8.encode(msg));
        expect(p1363.rawBytes.length, 64);

        final der = p1363.toDer();
        expect(crypto.verify(utf8.encode(msg), der.derBytes), isTrue);

        final backToP1363 = der.toP1363();
        expect(backToP1363.rawBytes, equals(p1363.rawBytes));
      },
    );
  });
}
