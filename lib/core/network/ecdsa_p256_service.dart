import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// NIST P-256 (secp256r1) ECDSA 加密服務
/// 用於 WebRTC P2P DataChannel 之 Channel Binding 密鑰生成與雙向挑戰簽名
class EcdsaP256Service {
  final ECPublicKey publicKey;
  final ECPrivateKey privateKey;

  EcdsaP256Service({
    required this.publicKey,
    required this.privateKey,
  });

  /// 隨機生成新的 P-256 密鑰對 (純 Dart 實作，跨平台零原生依賴)
  factory EcdsaP256Service.generate() {
    final domain = ECCurve_secp256r1();
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));

    final keyParams = ECKeyGeneratorParameters(domain);
    final generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));

    final pair = generator.generateKeyPair();
    return EcdsaP256Service(
      publicKey: pair.publicKey,
      privateKey: pair.privateKey,
    );
  }

  /// 取得標準 DER / SPKI (SubjectPublicKeyInfo) 91 位元組公鑰二進位
  /// 相容於 Apple CryptoKit 與 WebCrypto `crypto.subtle.exportKey('spki', key)`
  Uint8List getSpkiPublicKeyBytes() {
    // ASN.1 SEQUENCE of 89 bytes:
    // AlgorithmIdentifier (19 bytes): id-ecPublicKey + prime256v1
    // SubjectPublicKey (66 bytes bit string): 0x00 unused bits + 0x04 uncompressed + 32 bytes X + 32 bytes Y
    const prefix = [
      0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
      0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
      0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
      0x42, 0x00, 0x04,
    ];

    final xBytes = _bigIntToFixedBytes(publicKey.Q!.x!.toBigInteger()!, 32);
    final yBytes = _bigIntToFixedBytes(publicKey.Q!.y!.toBigInteger()!, 32);

    return Uint8List.fromList([...prefix, ...xBytes, ...yBytes]);
  }

  /// 取得 Base64 編碼之 SPKI 公鑰字串，傳送予 InitiateMeshSession
  String getSpkiPublicKeyBase64() {
    return base64Encode(getSpkiPublicKeyBytes());
  }

  /// 以 SHA-256 + RFC 6979 確定性簽署訊息，回傳標準 ASN.1 DER 簽名二進位
  Uint8List sign(List<int> message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter(privateKey));
    final sig = signer.generateSignature(Uint8List.fromList(message)) as ECSignature;

    // 將 r 與 s 編碼為 ASN.1 DER SEQUENCE
    final rDer = _encodeAsn1Integer(sig.r);
    final sDer = _encodeAsn1Integer(sig.s);
    final body = [...rDer, ...sDer];
    return Uint8List.fromList([0x30, body.length, ...body]);
  }

  /// 簽署文字並回傳 Base64 字串
  String signBase64(String messageText) {
    final sigBytes = sign(utf8.encode(messageText));
    return base64Encode(sigBytes);
  }

  /// 驗證簽名
  bool verify(List<int> message, Uint8List derSignature) {
    try {
      if (derSignature.length < 8 || derSignature[0] != 0x30) return false;

      // 解析 ASN.1 DER SEQUENCE
      int offset = 2; // 跳過 0x30 與長度
      if (derSignature[offset] != 0x02) return false;
      final rLen = derSignature[offset + 1];
      final rBytes = derSignature.sublist(offset + 2, offset + 2 + rLen);
      final r = _decodeBigInt(rBytes);

      offset = offset + 2 + rLen;
      if (derSignature[offset] != 0x02) return false;
      final sLen = derSignature[offset + 1];
      final sBytes = derSignature.sublist(offset + 2, offset + 2 + sLen);
      final s = _decodeBigInt(sBytes);

      final verifier = ECDSASigner(SHA256Digest());
      verifier.init(false, PublicKeyParameter(publicKey));
      return verifier.verifySignature(
        Uint8List.fromList(message),
        ECSignature(r, s),
      );
    } catch (_) {
      return false;
    }
  }

  static Uint8List _bigIntToFixedBytes(BigInt number, int length) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final raw = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      raw.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    final result = Uint8List(length);
    if (raw.length > length) {
      result.setRange(0, length, raw.sublist(raw.length - length));
    } else {
      result.setRange(length - raw.length, length, raw);
    }
    return result;
  }

  static Uint8List _encodeAsn1Integer(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final raw = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      raw.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    if ((raw[0] & 0x80) != 0) {
      raw.insert(0, 0x00);
    }
    return Uint8List.fromList([0x02, raw.length, ...raw]);
  }

  static BigInt _decodeBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
