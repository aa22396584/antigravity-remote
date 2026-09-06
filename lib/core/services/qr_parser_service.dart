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
        if (id != null && id.toString().isNotEmpty) {
          return ParsedRemoteTarget(
            instanceId: id.toString(),
            cascadeId: json['cascadeId']?.toString() ?? json['cascade_id']?.toString(),
            hostname: json['hostname']?.toString() ?? json['remoteControlHostname']?.toString(),
            email: json['email']?.toString() ?? json['Email']?.toString(),
            rawSource: trimmed,
          );
        }
      } catch (_) {}
    }

    // 2. Google AccountChooser 格式或 antigravity.google.com:
    // https://accounts.google.com/AccountChooser?Email={email}&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F{instanceId}
    if (trimmed.contains('continue=') ||
        trimmed.contains('antigravity.google.com') ||
        trimmed.contains('accounts.google.com')) {
      try {
        final uri = Uri.parse(trimmed);
        String? email = uri.queryParameters['Email'] ?? uri.queryParameters['email'];
        String? continueUrl = uri.queryParameters['continue'];

        Uri targetUri = continueUrl != null ? Uri.parse(continueUrl) : uri;

        // 路徑格式通常為 /r/{instanceId} 或 /{instanceId}
        final pathSegments = targetUri.pathSegments;
        final rIndex = pathSegments.indexOf('r');
        String? instanceId;
        if (rIndex != -1 && pathSegments.length > rIndex + 1) {
          instanceId = pathSegments[rIndex + 1];
        } else if (targetUri.host.contains('antigravity.google.com') && pathSegments.isNotEmpty) {
          final segs = pathSegments.where((s) => s.isNotEmpty && s != 'r').toList();
          if (segs.isNotEmpty) {
            instanceId = segs.last;
          }
        }

        // 也支援 queryParameters 中的 instanceId / id
        instanceId ??= targetUri.queryParameters['instanceId'] ?? targetUri.queryParameters['id'];

        // 參數 ?p=c/{cascadeId} 或 cascadeId
        String? cascadeId = targetUri.queryParameters['cascadeId'];
        final pParam = targetUri.queryParameters['p'];
        if (pParam != null && pParam.startsWith('c/')) {
          cascadeId = pParam.substring(2);
        }

        email ??= targetUri.queryParameters['Email'] ?? targetUri.queryParameters['email'];
        final hostname = targetUri.queryParameters['hostname'];

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

    // 3. 自定義 URL scheme: antigravity:// 或 antigravity-remote://
    if (trimmed.startsWith('antigravity://') || trimmed.startsWith('antigravity-remote://')) {
      try {
        final uri = Uri.parse(trimmed);
        String? email = uri.queryParameters['Email'] ?? uri.queryParameters['email'];
        String? cascadeId = uri.queryParameters['cascadeId'];
        final pParam = uri.queryParameters['p'];
        if (pParam != null && pParam.startsWith('c/')) {
          cascadeId = pParam.substring(2);
        }
        final hostname = uri.queryParameters['hostname'];

        String? instanceId = uri.queryParameters['instanceId'] ?? uri.queryParameters['id'];

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
