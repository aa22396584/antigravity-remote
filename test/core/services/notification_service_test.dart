import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_remote/core/services/notification_service.dart';

void main() {
  group('NotificationService Tests', () {
    setUp(() {
      NotificationService.instance.clear();
    });

    test('notifies approval needed and deduplicates repeated step approvals (Issue #33)', () async {
      final notifications = <InAppNotification>[];
      final sub = NotificationService.instance.notificationStream.listen(notifications.add);

      final first = NotificationService.instance.notifyApprovalNeeded(
        instanceId: 'mac-1',
        cascadeId: 'casc-1',
        stepId: 'step-101',
        actionSummary: 'rm -rf /tmp/test',
      );
      expect(first, isTrue);

      // Repeat with same stepId -> deduplicated!
      final second = NotificationService.instance.notifyApprovalNeeded(
        instanceId: 'mac-1',
        cascadeId: 'casc-1',
        stepId: 'step-101',
        actionSummary: 'rm -rf /tmp/test',
      );
      expect(second, isFalse);

      await pumpEventQueue();

      expect(notifications.length, 1);
      expect(notifications.first.type, NotificationType.approvalNeeded);
      expect(notifications.first.body, contains('rm -rf /tmp/test'));

      await sub.cancel();
    });

    test('notifies task completion and failure with event deduplication (Issue #33)', () async {
      final notifications = <InAppNotification>[];
      final sub = NotificationService.instance.notificationStream.listen(notifications.add);

      final ok = NotificationService.instance.notifyTaskCompleted(
        instanceId: 'mac-1',
        cascadeId: 'casc-1',
        taskId: 'task-abc',
      );
      expect(ok, isTrue);

      final dup = NotificationService.instance.notifyTaskCompleted(
        instanceId: 'mac-1',
        cascadeId: 'casc-1',
        taskId: 'task-abc',
      );
      expect(dup, isFalse);

      final failed = NotificationService.instance.notifyTaskFailed(
        instanceId: 'mac-1',
        cascadeId: 'casc-1',
        taskId: 'task-xyz',
        reason: 'Compilation failed',
      );
      expect(failed, isTrue);

      await pumpEventQueue();

      expect(notifications.length, 2);
      expect(notifications[0].type, NotificationType.taskCompleted);
      expect(notifications[1].type, NotificationType.taskFailed);

      await sub.cancel();
    });
  });
}
