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
}

class QrParserService {
  QrParserService._();

  static ParsedRemoteTarget? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1. JSON 格式 (例如本機設定檔或自定義 QR code)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final id = json['instanceId'] ?? json['instance_id'] ?? json['uuid'];
        if (id != null) {
          return ParsedRemoteTarget(
            instanceId: id.toString(),
            hostname: json['hostname']?.toString() ?? json['remoteControlHostname']?.toString(),
            email: json['email']?.toString(),
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 2. Google AccountChooser 格式:
    // https://accounts.google.com/AccountChooser?Email={email}&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F{instanceId}
    if (trimmed.contains('continue=') || trimmed.contains('antigravity.google.com')) {
      try {
        final uri = Uri.parse(trimmed);
        String? email = uri.queryParameters['Email'];
        String? continueUrl = uri.queryParameters['continue'];

        Uri targetUri = continueUrl != null ? Uri.parse(continueUrl) : uri;
        
        // 路徑格式通常為 /r/{instanceId}
        final pathSegments = targetUri.pathSegments;
        final rIndex = pathSegments.indexOf('r');
        String? instanceId;
        if (rIndex != -1 && pathSegments.length > rIndex + 1) {
          instanceId = pathSegments[rIndex + 1];
        }

        // 參數 ?p=c/{cascadeId}
        String? cascadeId;
        final pParam = targetUri.queryParameters['p'];
        if (pParam != null && pParam.startsWith('c/')) {
          cascadeId = pParam.substring(2);
        }

        if (instanceId != null && instanceId.isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            cascadeId: cascadeId,
            email: email,
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 3. 自定義 URL scheme: antigravity://remote/{instanceId}
    if (trimmed.startsWith('antigravity://')) {
      try {
        final uri = Uri.parse(trimmed);
        final instanceId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
        if (instanceId.isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: instanceId,
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 4. 直接為 UUID 或 instanceId 字串 (例如 2114863e-6436-4398-b26f-8672c1bd5e4b-v2)
    final uuidRegex = RegExp(r'^[a-zA-Z0-9_-]{8,64}$');
    if (uuidRegex.hasMatch(trimmed)) {
      return ParsedRemoteTarget(
        instanceId: trimmed,
        rawSource: trimmed,
      );
    }

    return null;
  }
}
