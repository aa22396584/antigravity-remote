import 'dart:async';

enum NotificationType { approvalNeeded, taskCompleted, taskFailed }

class InAppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? instanceId;
  final String? cascadeId;
  final DateTime timestamp;

  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.instanceId,
    this.cascadeId,
    required this.timestamp,
  });

  @override
  String toString() => 'InAppNotification[$type]: $title - $body';
}

/// 應用內通知與提醒服務 (Issue #33)
/// 實作按 (host / cascade / eventId) 之嚴格事件去重，杜絕倒序或重複觸發通知
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final Set<String> _seenEvents = <String>{};
  final StreamController<InAppNotification> _controller =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get notificationStream => _controller.stream;

  /// 發送待審批工具執行提醒
  bool notifyApprovalNeeded({
    required String instanceId,
    required String cascadeId,
    required String stepId,
    required String actionSummary,
  }) {
    final eventKey = '$instanceId:$cascadeId:approval:$stepId';
    if (_seenEvents.contains(eventKey)) return false;
    _seenEvents.add(eventKey);

    final notification = InAppNotification(
      id: eventKey,
      type: NotificationType.approvalNeeded,
      title: 'Cascade 需使用者審批',
      body: '工具執行即將執行：$actionSummary',
      instanceId: instanceId,
      cascadeId: cascadeId,
      timestamp: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(notification);
    }
    return true;
  }

  /// 發送任務完成提醒
  bool notifyTaskCompleted({
    required String instanceId,
    required String cascadeId,
    required String taskId,
  }) {
    final eventKey = '$instanceId:$cascadeId:completed:$taskId';
    if (_seenEvents.contains(eventKey)) return false;
    _seenEvents.add(eventKey);

    final notification = InAppNotification(
      id: eventKey,
      type: NotificationType.taskCompleted,
      title: '任務執行完成',
      body: 'Cascade 任務已順利完成',
      instanceId: instanceId,
      cascadeId: cascadeId,
      timestamp: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(notification);
    }
    return true;
  }

  /// 發送任務失敗提醒
  bool notifyTaskFailed({
    required String instanceId,
    required String cascadeId,
    required String taskId,
    String? reason,
  }) {
    final eventKey = '$instanceId:$cascadeId:failed:$taskId';
    if (_seenEvents.contains(eventKey)) return false;
    _seenEvents.add(eventKey);

    final notification = InAppNotification(
      id: eventKey,
      type: NotificationType.taskFailed,
      title: '任務中斷或失敗',
      body: reason ?? 'Cascade 任務遇到未預期錯誤停止',
      instanceId: instanceId,
      cascadeId: cascadeId,
      timestamp: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(notification);
    }
    return true;
  }

  /// 清除已去重事件快取 (例如切換裝置或登出時)
  void clear() {
    _seenEvents.clear();
  }

  void dispose() {
    _controller.close();
  }
}
