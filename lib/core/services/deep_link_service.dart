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
  String? _lastHandledUri;
  DateTime? _lastHandledTime;

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
    final uriStr = uri.toString();
    final now = DateTime.now();

    // 防抖與去重（避免 Android / iOS 冷啟動同時自 getInitialLink() 與 uriLinkStream 派發相同 Intent）
    if (_lastHandledUri == uriStr &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      return;
    }
    _lastHandledUri = uriStr;
    _lastHandledTime = now;

    final parsed = QrParserService.parse(uriStr);
    if (parsed != null) {
      _targetController.add(parsed);
    }
  }

  /// 手動處理外部傳入的 URI 或字串（例如測試或由 Intent 直接傳入）
  ParsedRemoteTarget? handleRawUri(String rawUri) {
    final now = DateTime.now();
    if (_lastHandledUri == rawUri &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      return QrParserService.parse(rawUri);
    }
    _lastHandledUri = rawUri;
    _lastHandledTime = now;

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
