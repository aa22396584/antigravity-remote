/// 應用程式強型別錯誤體系 (Issue #32)
enum AppFailureType {
  authExpired,
  forbidden,
  hostOffline,
  networkUnavailable,
  protocolUnsupported,
  malformedResponse,
  storageFailure,
  outcomeUnknown,
}

class AppFailure implements Exception {
  final AppFailureType type;
  final String errorCode;
  final String userMessage;
  final bool isRetryable;
  final Object? cause;

  const AppFailure({
    required this.type,
    required this.errorCode,
    required this.userMessage,
    this.isRetryable = false,
    this.cause,
  });

  factory AppFailure.authExpired([Object? cause]) => AppFailure(
    type: AppFailureType.authExpired,
    errorCode: 'AUTH_TOKEN_EXPIRED',
    userMessage: '授權憑證已過期，請重新登入或更新 Access Token',
    isRetryable: false,
    cause: cause,
  );

  factory AppFailure.forbidden([Object? cause]) => AppFailure(
    type: AppFailureType.forbidden,
    errorCode: 'AUTH_FORBIDDEN',
    userMessage: '存取遭拒，目前帳號無權控制該主機',
    isRetryable: false,
    cause: cause,
  );

  factory AppFailure.hostOffline([Object? cause]) => AppFailure(
    type: AppFailureType.hostOffline,
    errorCode: 'HOST_OFFLINE',
    userMessage: '遠端 Antigravity 實體目前離線或不可達',
    isRetryable: true,
    cause: cause,
  );

  factory AppFailure.networkUnavailable([Object? cause]) => AppFailure(
    type: AppFailureType.networkUnavailable,
    errorCode: 'NETWORK_UNAVAILABLE',
    userMessage: '網路連線中斷，請檢查 Wi-Fi 或行動網路',
    isRetryable: true,
    cause: cause,
  );

  factory AppFailure.protocolUnsupported([Object? cause]) => AppFailure(
    type: AppFailureType.protocolUnsupported,
    errorCode: 'PROTOCOL_UNSUPPORTED',
    userMessage: '遠端實體之協議版本不相容',
    isRetryable: false,
    cause: cause,
  );

  factory AppFailure.malformedResponse([Object? cause]) => AppFailure(
    type: AppFailureType.malformedResponse,
    errorCode: 'MALFORMED_RESPONSE',
    userMessage: '收到無法解析之資料訊框',
    isRetryable: false,
    cause: cause,
  );

  factory AppFailure.storageFailure([Object? cause]) => AppFailure(
    type: AppFailureType.storageFailure,
    errorCode: 'STORAGE_UNAVAILABLE',
    userMessage: '本機安全儲存空間異常，設定可能無法持久化保存',
    isRetryable: true,
    cause: cause,
  );

  factory AppFailure.outcomeUnknown([Object? cause]) => AppFailure(
    type: AppFailureType.outcomeUnknown,
    errorCode: 'OUTCOME_UNKNOWN',
    userMessage: '操作已發送但遠端未確認狀態，禁止自動重試以防重複執行',
    isRetryable: false,
    cause: cause,
  );

  @override
  String toString() => 'AppFailure[$errorCode]: $userMessage';
}
