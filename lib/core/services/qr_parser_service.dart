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

  static ParsedRemoteTarget? parse(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 0. 去除外層引號與角括號（常見於終端輸出複製或 markdown 格式）
    while ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
        (trimmed.startsWith('<') && trimmed.endsWith('>')) ||
        (trimmed.startsWith('`') && trimmed.endsWith('`'))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      if (trimmed.isEmpty) return null;
    }

    // 1. JSON 格式 (例如本機設定檔或自定義 QR code)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final id = json['instanceId'] ?? json['instance_id'] ?? json['uuid'] ?? json['id'];
        if (id != null && id.toString().isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: id.toString(),
            cascadeId: json['cascadeId']?.toString() ??
                json['cascade_id']?.toString() ??
                json['sessionId']?.toString() ??
                json['session_id']?.toString(),
            hostname: json['hostname']?.toString() ??
                json['host']?.toString() ??
                json['remoteControlHostname']?.toString(),
            email: json['email']?.toString() ?? json['Email']?.toString(),
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 2. Google AccountChooser 格式或帶有 continue 的 redirect URL
    if (trimmed.contains('continue=') ||
        trimmed.contains('accounts.google.') ||
        trimmed.contains('AccountChooser')) {
      try {
        final uri = Uri.parse(trimmed);
        final email = uri.queryParameters['Email'] ??
            uri.queryParameters['email'] ??
            uri.queryParameters['authuser'];
        var continueUrl = uri.queryParameters['continue'];

        if (continueUrl != null && continueUrl.isNotEmpty) {
          // 處理可能的多層 URL 編碼 (Double-encoded URL)
          while (continueUrl!.contains('%3A') ||
              continueUrl.contains('%3a') ||
              continueUrl.contains('%2F') ||
              continueUrl.contains('%2f')) {
            try {
              final decoded = Uri.decodeFull(continueUrl);
              if (decoded == continueUrl) break;
              continueUrl = decoded;
            } catch (_) {
              break;
            }
          }

          final nestedTarget = parse(continueUrl!);
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
      } catch (_) {}
    }

    // 3. antigravity.google.com 網頁 Deep Link
    if (trimmed.contains('antigravity.google.com')) {
      try {
        final uri = Uri.parse(trimmed);
        String? email = uri.queryParameters['Email'] ?? uri.queryParameters['email'];
        final hostname = uri.queryParameters['hostname'] ?? uri.queryParameters['host'];

        // instanceId 提取
        String? instanceId = uri.queryParameters['instanceId'] ??
            uri.queryParameters['instance_id'] ??
            uri.queryParameters['id'] ??
            uri.queryParameters['uuid'];

        if (instanceId == null || instanceId.isEmpty) {
          final pathSegments = uri.pathSegments;
          final rIndex = pathSegments.indexOf('r');
          if (rIndex != -1 && pathSegments.length > rIndex + 1) {
            instanceId = pathSegments[rIndex + 1];
          } else {
            final segs = pathSegments.where((s) => s.isNotEmpty && s != 'r' && s != 'c').toList();
            if (segs.isNotEmpty) {
              instanceId = segs.last;
            }
          }
        }

        // cascadeId 提取
        String? cascadeId = uri.queryParameters['cascadeId'] ??
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

        if (instanceId != null && instanceId.isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            cascadeId: cascadeId,
            email: email,
            hostname: hostname,
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 4. 自定義 URL scheme: antigravity: 或 antigravity-remote:
    if (trimmed.startsWith('antigravity:') ||
        trimmed.startsWith('antigravity-remote:')) {
      try {
        // 標準化 URI (如 antigravity:/r/abc -> antigravity://r/abc)
        String normalized = trimmed;
        if (!normalized.contains('://')) {
          final colonIdx = normalized.indexOf(':');
          final rest = normalized.substring(colonIdx + 1).replaceFirst(RegExp(r'^/+'), '');
          normalized = '${normalized.substring(0, colonIdx)}://$rest';
        }

        final uri = Uri.parse(normalized);
        String? email = uri.queryParameters['Email'] ?? uri.queryParameters['email'];
        final hostname = uri.queryParameters['hostname'] ?? uri.queryParameters['host'];

        // cascadeId 提取
        String? cascadeId = uri.queryParameters['cascadeId'] ??
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

        // instanceId 提取
        String? instanceId = uri.queryParameters['instanceId'] ??
            uri.queryParameters['instance_id'] ??
            uri.queryParameters['id'] ??
            uri.queryParameters['uuid'];

        if (instanceId == null || instanceId.isEmpty) {
          final segs = uri.pathSegments
              .where((s) => s.isNotEmpty && s != 'r' && s != 'remote' && s != 'connect')
              .toList();
          if (segs.isNotEmpty) {
            instanceId = segs.last;
          } else if (uri.host.isNotEmpty &&
              uri.host != 'r' &&
              uri.host != 'remote' &&
              uri.host != 'connect') {
            instanceId = uri.host;
          }
        }

        if (instanceId != null && instanceId.isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            cascadeId: cascadeId,
            email: email,
            hostname: hostname,
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 5. 直接為 UUID 或 instanceId 字串 (例如 2114863e-6436-4398-b26f-8672c1bd5e4b-v2)
    final uuidRegex = RegExp(r'^[a-zA-Z0-9_-]{4,128}$');
    if (uuidRegex.hasMatch(trimmed)) {
      return ParsedRemoteTarget(
        instanceId: trimmed,
        rawSource: trimmed,
      );
    }

    return null;
  }
}
