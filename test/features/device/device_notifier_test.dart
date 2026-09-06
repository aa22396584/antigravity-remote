import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antigravity_remote/core/network/endpoints.dart';
import 'package:antigravity_remote/features/device/providers/device_provider.dart';

void main() {
  group('DeviceNotifier Tests', () {
    test('initializes with mock devices in demo mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(deviceProvider);
      expect(state.devices, isNotEmpty);
      expect(state.activeDevice, isNotNull);
      expect(state.isDemoMode, isTrue);
    });

    test('addDevice inserts new device and sets it active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      await notifier.addDevice(
        instanceId: 'new-instance-8899',
        name: 'New Test Mac',
      );

      final state = container.read(deviceProvider);
      expect(state.devices.any((d) => d.instanceId == 'new-instance-8899'), isTrue);
      expect(state.activeDevice?.instanceId, 'new-instance-8899');
      expect(state.activeDevice?.uuid, 'new-instance-8899');
      expect(state.activeDevice?.name, 'New Test Mac');
    });

    test('removeDevice deletes device and updates active device', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      final initialActive = container.read(deviceProvider).activeDevice;
      expect(initialActive, isNotNull);

      await notifier.removeDevice(initialActive!.instanceId);

      final state = container.read(deviceProvider);
      expect(state.devices.any((d) => d.instanceId == initialActive.instanceId), isFalse);
      expect(state.activeDevice, isNotNull);
      expect(state.activeDevice!.instanceId, isNot(initialActive.instanceId));
    });

    test('toggleDemoMode updates state and propagates to remoteControlService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      notifier.toggleDemoMode(false);

      expect(container.read(deviceProvider).isDemoMode, isFalse);
      expect(notifier.remoteControlService.isDemoMode, isFalse);

      notifier.toggleDemoMode(true);
      expect(container.read(deviceProvider).isDemoMode, isTrue);
      expect(notifier.remoteControlService.isDemoMode, isTrue);
    });

    test('setEnvironment and setAccessToken update state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      notifier.setEnvironment(CloudEnvironment.daily);
      notifier.setAccessToken('test-ya29-token');

      final state = container.read(deviceProvider);
      expect(state.environment, CloudEnvironment.daily);
      expect(state.accessToken, 'test-ya29-token');
    });
  });
}
