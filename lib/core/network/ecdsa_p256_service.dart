import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// secp256r1 曲線階數 n (Curve order)
final BigInt _p256Order = BigInt.parse(
  'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551',
  radix: 16,
);

/// 標準 ASN.1 DER ECDSA 簽名物件
class DerSignature {
  final BigInt r;
  final BigInt s;
  final Uint8List derBytes;

  const DerSignature({
    required this.r,
    required this.s,
    required this.derBytes,
  });

  /// 轉換為 IEEE P1363 格式 (64 位元組 raw r || s，32B r + 32B s)
  P1363RawSignature toP1363() {
    final raw = Uint8List(64);
    final rBytes = _bigIntToFixedBytes(r, 32);
    final sBytes = _bigIntToFixedBytes(s, 32);
    raw.setRange(0, 32, rBytes);
    raw.setRange(32, 64, sBytes);
    return P1363RawSignature(raw);
  }

  /// 從 IEEE P1363 (64 bytes) 格式構造標準 DER 簽名
  factory DerSignature.fromP1363(P1363RawSignature p1363) {
    final rBytes = p1363.rawBytes.sublist(0, 32);
    final sBytes = p1363.rawBytes.sublist(32, 64);
    final r = _decodeBigInt(rBytes);
    final s = _decodeBigInt(sBytes);

    final rDer = _encodeAsn1Integer(r);
    final sDer = _encodeAsn1Integer(s);
    final body = [...rDer, ...sDer];
    final der = Uint8List.fromList([0x30, body.length, ...body]);

    return DerSignature(r: r, s: s, derBytes: der);
  }

  /// 嚴格解析 ASN.1 DER 二進位簽名 (RFC 5480 / BSI TR-03111 / Issue #30)
  /// 若長度不符、存在 trailing garbage、非最小整數編碼、負數或超過曲線範圍，立即回傳 null
  static DerSignature? tryParseDer(Uint8List bytes) {
    if (bytes.length < 8 || bytes[0] != 0x30) return null;

    int offset = 1;
    int seqLen = bytes[offset++];
    if (seqLen >= 0x80) {
      // 嚴格 DER 禁止對 < 128 的長度使用 long form
      if (seqLen == 0x81) {
        if (offset >= bytes.length) return null;
        seqLen = bytes[offset++];
        if (seqLen < 128) return null; // Non-canonical long form
      } else {
        return null; // P-256 簽名不超過 73 位元組，不應出現更長前綴
      }
    }

    // 嚴格檢查：總長度必須與宣告長度完全一致，杜絕任何尾端附加字節 (Trailing garbage)
    if (offset + seqLen != bytes.length) return null;

    // 解析 r 整數 (Tag 0x02)
    if (offset >= bytes.length || bytes[offset++] != 0x02) return null;
    if (offset >= bytes.length) return null;
    final rLen = bytes[offset++];
    if (rLen <= 0 || offset + rLen > bytes.length) return null;

    final rBytes = bytes.sublist(offset, offset + rLen);
    // 嚴格整數正負與最小長度檢查
    if ((rBytes[0] & 0x80) != 0) return null; // 負整數
    if (rBytes.length > 1 && rBytes[0] == 0x00 && (rBytes[1] & 0x80) == 0) {
      return null; // 存在多餘的前綴 0x00
    }
    final r = _decodeBigInt(rBytes);
    offset += rLen;

    // 解析 s 整數 (Tag 0x02)
    if (offset >= bytes.length || bytes[offset++] != 0x02) return null;
    if (offset >= bytes.length) return null;
    final sLen = bytes[offset++];
    if (sLen <= 0 || offset + sLen != bytes.length) return null; // 恰好讀到結尾

    final sBytes = bytes.sublist(offset, offset + sLen);
    if ((sBytes[0] & 0x80) != 0) return null; // 負整數
    if (sBytes.length > 1 && sBytes[0] == 0x00 && (sBytes[1] & 0x80) == 0) {
      return null; // 存在多餘的前綴 0x00
    }
    final s = _decodeBigInt(sBytes);

    // 範圍檢查：1 <= r, s < n
    if (r < BigInt.one || r >= _p256Order) return null;
    if (s < BigInt.one || s >= _p256Order) return null;

    return DerSignature(r: r, s: s, derBytes: bytes);
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

/// IEEE P1363 格式 (64 位元組 raw r || s)
class P1363RawSignature {
  final Uint8List rawBytes;

  P1363RawSignature(this.rawBytes) {
    if (rawBytes.length != 64) {
      throw ArgumentError('IEEE P1363 signature for P-256 must be exactly 64 bytes');
    }
  }

  DerSignature toDer() => DerSignature.fromP1363(this);
}

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
    const prefix = [
      0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
      0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
      0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
      0x42, 0x00, 0x04,
    ];

    final xBytes = DerSignature._bigIntToFixedBytes(publicKey.Q!.x!.toBigInteger()!, 32);
    final yBytes = DerSignature._bigIntToFixedBytes(publicKey.Q!.y!.toBigInteger()!, 32);

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

    final rDer = DerSignature._encodeAsn1Integer(sig.r);
    final sDer = DerSignature._encodeAsn1Integer(sig.s);
    final body = [...rDer, ...sDer];
    return Uint8List.fromList([0x30, body.length, ...body]);
  }

  /// 簽署為 IEEE P1363 (64 bytes)
  P1363RawSignature signRaw(List<int> message) {
    final derSig = sign(message);
    final parsed = DerSignature.tryParseDer(derSig)!;
    return parsed.toP1363();
  }

  /// 簽署文字並回傳 Base64 字串
  String signBase64(String messageText) {
    final sigBytes = sign(utf8.encode(messageText));
    return base64Encode(sigBytes);
  }

  /// 嚴格驗證簽名 (Issue #30: 嚴格拒絕畸形 DER、尾端附加資料與不符邊界之 r/s)
  bool verify(List<int> message, Uint8List derSignature) {
    try {
      final parsed = DerSignature.tryParseDer(derSignature);
      if (parsed == null) return false;

      final verifier = ECDSASigner(SHA256Digest());
      verifier.init(false, PublicKeyParameter(publicKey));
      return verifier.verifySignature(
        Uint8List.fromList(message),
        ECSignature(parsed.r, parsed.s),
      );
    } catch (_) {
      return false;
    }
  }
}
