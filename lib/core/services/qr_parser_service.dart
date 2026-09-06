import 'dart:convert';

class ParsedRemoteTarget {
  final String instanceId;
  final String? cascadeId;
  final String? email;
  final String? hostname;
  final String rawSource;

  const ParsedRemoteTarget({
    required this.instanceId,
    this.cascadeId,
    this.email,
    this.hostname,
    required this.rawSource,
  });

  ParsedRemoteTarget copyWith({
    String? instanceId,
    String? cascadeId,
    String? email,
    String? hostname,
    String? rawSource,
  }) {
    return ParsedRemoteTarget(
      instanceId: instanceId ?? this.instanceId,
      cascadeId: cascadeId ?? this.cascadeId,
      email: email ?? this.email,
      hostname: hostname ?? this.hostname,
      rawSource: rawSource ?? this.rawSource,
    );
  }
}

class QrParserService {
  QrParserService._();

  static const int maxInputLength = 4096;
  static const int maxRedirectDepth = 3;
  static final RegExp _validIdPattern = RegExp(r'^[a-zA-Z0-9_-]{4,128}$');

  /// 全函數 (Total Function) 解析：對任何字串保證不向外拋出例外，超限、畸形或攻擊封包安全回傳 null
  static ParsedRemoteTarget? parse(String raw, {int depth = 0}) {
    try {
      return _parseInternal(raw, depth: depth);
    } catch (_) {
      return null;
    }
  }

  static ParsedRemoteTarget? _parseInternal(String raw, {required int depth}) {
    if (depth > maxRedirectDepth) return null;

    var trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > maxInputLength) return null;

    // 0. 去除外層引號、反引號與角括號（保護長度 >= 2，杜絕單引號 RangeError 崩潰）
    while (trimmed.length >= 2 &&
        ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
            (trimmed.startsWith('<') && trimmed.endsWith('>')) ||
            (trimmed.startsWith('`') && trimmed.endsWith('`')))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      if (trimmed.isEmpty) return null;
    }

    if (trimmed.isEmpty) return null;

    // 1. JSON 格式 (嚴格型別驗證，禁止將 boolean/list/map 轉為身分識別)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final idRaw =
              decoded['instanceId'] ??
              decoded['instance_id'] ??
              decoded['uuid'] ??
              decoded['id'];

          if (idRaw is String && _validIdPattern.hasMatch(idRaw)) {
            return ParsedRemoteTarget(
              instanceId: idRaw,
              cascadeId: decoded['cascadeId'] is String
                  ? decoded['cascadeId'] as String
                  : (decoded['cascade_id'] is String
                        ? decoded['cascade_id'] as String
                        : (decoded['sessionId'] is String
                              ? decoded['sessionId'] as String
                              : (decoded['session_id'] is String
                                    ? decoded['session_id'] as String
                                    : null))),
              hostname: decoded['hostname'] is String
                  ? decoded['hostname'] as String
                  : (decoded['host'] is String
                        ? decoded['host'] as String
                        : (decoded['remoteControlHostname'] is String
                              ? decoded['remoteControlHostname'] as String
                              : null)),
              email: decoded['email'] is String
                  ? decoded['email'] as String
                  : (decoded['Email'] is String
                        ? decoded['Email'] as String
                        : null),
              rawSource: trimmed,
            );
          }
        }
      } catch (_) {}
    }

    // 2. URI 結構解析 (防止假網域如 attacker-antigravity.google.com 或 userinfo 釣魚)
    Uri? uri = Uri.tryParse(trimmed);

    // 若不是包含標準 scheme 的 URI，嘗試補充 scheme 輔助驗證
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      // 拒絕帶有 userinfo 的偽造網域 (如 https://antigravity.google.com@evil.com)
      if (uri.userInfo.isNotEmpty) {
        return null;
      }

      final host = uri.host.toLowerCase();

      // 2a. Google AccountChooser 格式或官方登入 redirect URL
      if (host == 'accounts.google.com') {
        final email =
            uri.queryParameters['Email'] ??
            uri.queryParameters['email'] ??
            uri.queryParameters['authuser'];
        var continueUrl = uri.queryParameters['continue'];

        if (continueUrl != null &&
            continueUrl.isNotEmpty &&
            continueUrl.length <= maxInputLength) {
          int decodeCount = 0;
          while (decodeCount < 3 &&
              (continueUrl!.contains('%3A') ||
                  continueUrl.contains('%3a') ||
                  continueUrl.contains('%2F') ||
                  continueUrl.contains('%2f'))) {
            try {
              final decoded = Uri.decodeFull(continueUrl);
              if (decoded == continueUrl) break;
              continueUrl = decoded;
              decodeCount++;
            } catch (_) {
              break;
            }
          }

          final nestedTarget = parse(continueUrl!, depth: depth + 1);
          if (nestedTarget != null) {
            return ParsedRemoteTarget(
              instanceId: nestedTarget.instanceId,
              cascadeId: nestedTarget.cascadeId,
              email: nestedTarget.email ?? email,
              hostname: nestedTarget.hostname,
              rawSource: trimmed,
            );
          }
        }
      }

      // 2b. 精確匹配 antigravity.google.com 網頁 Deep Link
      if (host == 'antigravity.google.com') {
        String? email =
            uri.queryParameters['Email'] ?? uri.queryParameters['email'];
        final hostname =
            uri.queryParameters['hostname'] ?? uri.queryParameters['host'];

        // instanceId 提取
        String? instanceId =
            uri.queryParameters['instanceId'] ??
            uri.queryParameters['instance_id'] ??
            uri.queryParameters['id'] ??
            uri.queryParameters['uuid'];

        if (instanceId == null || instanceId.isEmpty) {
          final pathSegments = uri.pathSegments;
          final rIndex = pathSegments.indexOf('r');
          if (rIndex != -1 && pathSegments.length > rIndex + 1) {
            instanceId = pathSegments[rIndex + 1];
          } else {
            final segs = pathSegments
                .where((s) => s.isNotEmpty && s != 'r' && s != 'c')
                .toList();
            if (segs.isNotEmpty) {
              instanceId = segs.last;
            }
          }
        }

        // cascadeId 提取
        String? cascadeId =
            uri.queryParameters['cascadeId'] ??
            uri.queryParameters['cascade_id'] ??
            uri.queryParameters['CascadeId'];
        final pParam = uri.queryParameters['p'];
        if (pParam != null) {
          if (pParam.startsWith('c/')) {
            cascadeId = pParam.substring(2);
          } else if (pParam.startsWith('/c/')) {
            cascadeId = pParam.substring(3);
          } else {
            cascadeId = pParam;
          }
        }

        if (instanceId != null && _validIdPattern.hasMatch(instanceId)) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            cascadeId: cascadeId,
            email: email,
            hostname: hostname,
            rawSource: trimmed,
          );
        }
      }

      // 既非 accounts.google.com 亦非 antigravity.google.com 之 http/https 連結，拒絕
      return null;
    }

    // 3. 自定義 URL scheme: antigravity: 或 antigravity-remote:
    if (trimmed.startsWith('antigravity:') ||
        trimmed.startsWith('antigravity-remote:')) {
      try {
        String normalized = trimmed;
        if (!normalized.contains('://')) {
          final colonIdx = normalized.indexOf(':');
          final rest = normalized
              .substring(colonIdx + 1)
              .replaceFirst(RegExp(r'^/+'), '');
          normalized = '${normalized.substring(0, colonIdx)}://$rest';
        }

        final customUri = Uri.parse(normalized);
        if (customUri.scheme != 'antigravity' &&
            customUri.scheme != 'antigravity-remote') {
          return null;
        }

        String? email =
            customUri.queryParameters['Email'] ??
            customUri.queryParameters['email'];
        final hostname =
            customUri.queryParameters['hostname'] ??
            customUri.queryParameters['host'];

        // cascadeId 提取
        String? cascadeId =
            customUri.queryParameters['cascadeId'] ??
            customUri.queryParameters['cascade_id'] ??
            customUri.queryParameters['CascadeId'];
        final pParam = customUri.queryParameters['p'];
        if (pParam != null) {
          if (pParam.startsWith('c/')) {
            cascadeId = pParam.substring(2);
          } else if (pParam.startsWith('/c/')) {
            cascadeId = pParam.substring(3);
          } else {
            cascadeId = pParam;
          }
        }

        // instanceId 提取
        String? instanceId =
            customUri.queryParameters['instanceId'] ??
            customUri.queryParameters['instance_id'] ??
            customUri.queryParameters['id'] ??
            customUri.queryParameters['uuid'];

        if (instanceId == null || instanceId.isEmpty) {
          final segs = customUri.pathSegments
              .where(
                (s) =>
                    s.isNotEmpty && s != 'r' && s != 'remote' && s != 'connect',
              )
              .toList();
          if (segs.isNotEmpty) {
            instanceId = segs.last;
          } else if (customUri.host.isNotEmpty &&
              customUri.host != 'r' &&
              customUri.host != 'remote' &&
              customUri.host != 'connect') {
            instanceId = customUri.host;
          }
        }

        if (instanceId != null && _validIdPattern.hasMatch(instanceId)) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            cascadeId: cascadeId,
            email: email,
            hostname: hostname,
            rawSource: trimmed,
          );
        }
      } catch (_) {}
      return null;
    }

    // 4. 純 UUID 或合法 Instance ID 字串
    if (_validIdPattern.hasMatch(trimmed)) {
      return ParsedRemoteTarget(instanceId: trimmed, rawSource: trimmed);
    }

    return null;
  }
}
