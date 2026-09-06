import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'qr_parser_service.dart';

class DeepLinkService {
  final AppLinks _appLinks;
  final StreamController<ParsedRemoteTarget> _targetController =
      StreamController<ParsedRemoteTarget>.broadcast();
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;

  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  /// 監聽已解析的遠端連線目標
  Stream<ParsedRemoteTarget> get targetStream => _targetController.stream;

  /// 初始化 Deep Link 監聽器（支援冷啟動與熱啟動）
  Future<void> init({void Function(ParsedRemoteTarget target)? onTargetReceived}) async {
    if (_initialized) return;
    _initialized = true;

    if (onTargetReceived != null) {
      _targetController.stream.listen(onTargetReceived);
    }

    // 1. 監聽熱啟動 / Runtime Intent Stream
    try {
      _linkSub = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleUri(uri);
        },
        onError: (err) {
          // 靜默捕捉或忽略無效 intent
        },
      );
    } catch (_) {}

    // 2. 處理冷啟動 / Cold Start Initial Intent
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}
  }

  void _handleUri(Uri uri) {
    final parsed = QrParserService.parse(uri.toString());
    if (parsed != null) {
      _targetController.add(parsed);
    }
  }

  /// 手動處理外部傳入的 URI 或字串（例如測試或由 Intent 直接傳入）
  ParsedRemoteTarget? handleRawUri(String rawUri) {
    final parsed = QrParserService.parse(rawUri);
    if (parsed != null) {
      _targetController.add(parsed);
    }
    return parsed;
  }

  void dispose() {
    _linkSub?.cancel();
    _targetController.close();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(service.dispose);
  return service;
});
