import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antigravity_remote/core/models/instance_info.dart';
import 'package:antigravity_remote/core/models/terminal_stream.dart';
import 'package:antigravity_remote/core/network/cloud_relay_client.dart';
import 'package:antigravity_remote/core/network/dual_transport_manager.dart';
import 'package:antigravity_remote/core/network/webrtc_mesh_client.dart';
import 'package:antigravity_remote/features/device/providers/device_provider.dart';
import 'package:antigravity_remote/features/terminal/providers/terminal_provider.dart';

class TrackableDualTransportManager extends DualTransportManager {
  bool isDisposed = false;
  final String deviceTag;
  final Future<void> Function()? onConnectAll;

  TrackableDualTransportManager({
    required this.deviceTag,
    this.onConnectAll,
  }) : super(
          relayClient: CloudRelayClient(
            baseUrl: 'https://mock.googleapis.com',
            googleAccessToken: 'token',
            targetInstanceUuid: 'uuid-$deviceTag',
          ),
          meshClient: WebRtcMeshClient(
            baseUrl: 'https://mock.googleapis.com',
            googleAccessToken: 'token',
            targetInstanceUuid: 'uuid-$deviceTag',
          ),
        );

  @override
  Future<void> connectAll() async {
    if (onConnectAll != null) {
      await onConnectAll!();
    }
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await super.dispose();
  }
}

void main() {
  group('P0 #1: 錯機控制防禦與裝置切換一致性測試 (Target Consistency Tests)', () {
    test('switching active device clears terminal chunks from old device', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final deviceNotifier = container.read(deviceProvider.notifier);
      final terminalNotifier = container.read(terminalProvider.notifier);

      final devA = InstanceInfo(
        instanceId: 'dev-alpha',
        uuid: 'uuid-alpha',
        name: 'Alpha Host',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      final devB = InstanceInfo(
        instanceId: 'dev-beta',
        uuid: 'uuid-beta',
        name: 'Beta Host',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      await deviceNotifier.addDevice(instanceId: devA.instanceId, name: devA.name);
      await deviceNotifier.addDevice(instanceId: devB.instanceId, name: devB.name);

      await deviceNotifier.selectDevice(devA);

      // 模擬在設備 A 上執行指令產生終端日誌
      terminalNotifier.state = terminalNotifier.state.copyWith(
        chunks: [
          TerminalChunk(text: 'Alpha-Host-Prompt> ls -la\n', timestamp: DateTime.now()),
          TerminalChunk(text: 'secret_file_on_alpha.txt\n', timestamp: DateTime.now()),
        ],
      );

      expect(container.read(terminalProvider).chunks.length, 2);

      // 切換至設備 B！
      await deviceNotifier.selectDevice(devB);

      // 核心安全斷言 (P0 #1)：
      // 終端輸出必須清空，設備 A 的敏感檔案清單絕不能出現在設備 B 的畫面上！
      final terminalState = container.read(terminalProvider);
      expect(terminalState.chunks, isEmpty, reason: '切換設備時必須清理舊終端緩衝，避免誤導控制目標');
    });

    test('concurrent device switching drops outdated in-flight connections (Epoch / Generation check)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final deviceNotifier = container.read(deviceProvider.notifier);

      final dev1 = InstanceInfo(
        instanceId: 'dev-fast-1',
        uuid: 'uuid-1',
        name: 'Device 1',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      final dev2 = InstanceInfo(
        instanceId: 'dev-fast-2',
        uuid: 'uuid-2',
        name: 'Device 2',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      final dev3 = InstanceInfo(
        instanceId: 'dev-fast-3',
        uuid: 'uuid-3',
        name: 'Device 3',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      await deviceNotifier.addDevice(instanceId: dev1.instanceId, name: dev1.name);
      await deviceNotifier.addDevice(instanceId: dev2.instanceId, name: dev2.name);
      await deviceNotifier.addDevice(instanceId: dev3.instanceId, name: dev3.name);

      // 模擬使用者快速連續切換：dev1 -> dev2 -> dev3
      // 三個非同步呼叫幾乎同時觸發
      final f1 = deviceNotifier.selectDevice(dev1);
      final f2 = deviceNotifier.selectDevice(dev2);
      final f3 = deviceNotifier.selectDevice(dev3);

      await Future.wait([f1, f2, f3]);

      // 斷言：最終作用中的裝置必須是最後被選擇的 dev3，早期連線絕不可覆蓋最新的狀態！
      final state = container.read(deviceProvider);
      expect(state.activeDevice?.instanceId, dev3.instanceId);
      expect(state.isConnecting, isFalse);
    });

    test('removing active device disposes transport and cleans up session completely', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final deviceNotifier = container.read(deviceProvider.notifier);

      // 先清空既有 mock 設備
      final initialDevices = List.of(container.read(deviceProvider).devices);
      for (final dev in initialDevices) {
        await deviceNotifier.removeDevice(dev.instanceId);
      }

      final devOnly = InstanceInfo(
        instanceId: 'dev-sole',
        uuid: 'uuid-sole',
        name: 'Sole Device',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.p2p,
        lastSeen: DateTime.now(),
      );

      await deviceNotifier.addDevice(instanceId: devOnly.instanceId, name: devOnly.name);
      await deviceNotifier.selectDevice(devOnly);

      expect(container.read(deviceProvider).activeDevice?.instanceId, devOnly.instanceId);

      // 刪除唯一裝置
      await deviceNotifier.removeDevice(devOnly.instanceId);

      // 斷言：
      // 1. activeDevice 必須被清空為 null
      // 2. activeTransport 必須標記為 offline
      // 3. transportManager 必須為 null
      final state = container.read(deviceProvider);
      expect(state.activeDevice, isNull);
      expect(state.devices, isEmpty);
      expect(state.activeTransport, TransportType.offline);
      expect(deviceNotifier.transportManager, isNull);
      expect(deviceNotifier.remoteControlService.isDemoMode, isTrue);
    });

    test('Live Mode: switching active device completely disposes old transport manager', () async {
      final createdManagers = <String, TrackableDualTransportManager>{};

      final container = ProviderContainer(
        overrides: [
          transportManagerFactoryProvider.overrideWithValue(
            ({required relayClient, required meshClient}) {
              final tag = relayClient.targetInstanceUuid.replaceAll('uuid-', '');
              final mgr = TrackableDualTransportManager(deviceTag: tag);
              createdManagers[tag] = mgr;
              return mgr;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      // 切換為 Live 模式
      notifier.toggleDemoMode(false);

      final devA = InstanceInfo(
        instanceId: 'dev-live-a',
        uuid: 'uuid-live-a',
        name: 'Live Host A',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.relay,
        lastSeen: DateTime.now(),
      );

      final devB = InstanceInfo(
        instanceId: 'dev-live-b',
        uuid: 'uuid-live-b',
        name: 'Live Host B',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.relay,
        lastSeen: DateTime.now(),
      );

      // 連線至 Device A
      await notifier.connectToDevice(devA);
      expect(createdManagers['live-a'], isNotNull);
      expect(createdManagers['live-a']!.isDisposed, isFalse);
      expect(notifier.transportManager, createdManagers['live-a']);

      // 切換至 Device B
      await notifier.connectToDevice(devB);

      // 核心安全斷言 (P0 #1 Live Mode)：
      // 舊機器 A 的 Transport 必須已被完全銷毀 dispose！新機器 B 必須正常連線且未被 dispose！
      expect(createdManagers['live-a']!.isDisposed, isTrue, reason: '切換設備時舊連線必須立即且完整 dispose');
      expect(createdManagers['live-b']!.isDisposed, isFalse, reason: '新連線必須維持開啟狀態');
      expect(notifier.transportManager, createdManagers['live-b']);
      expect(container.read(deviceProvider).activeDevice?.instanceId, 'dev-live-b');
    });

    test('Live Mode: removing active device disposes its transport manager', () async {
      final createdManagers = <String, TrackableDualTransportManager>{};

      final container = ProviderContainer(
        overrides: [
          transportManagerFactoryProvider.overrideWithValue(
            ({required relayClient, required meshClient}) {
              final tag = relayClient.targetInstanceUuid.replaceAll('uuid-', '');
              final mgr = TrackableDualTransportManager(deviceTag: tag);
              createdManagers[tag] = mgr;
              return mgr;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      notifier.toggleDemoMode(false);

      // 先清空既有設備
      final existing = List.of(container.read(deviceProvider).devices);
      for (final d in existing) {
        await notifier.removeDevice(d.instanceId);
      }

      await notifier.addDevice(instanceId: 'dev-live-solo', name: 'Solo Live');
      expect(createdManagers['dev-live-solo'], isNotNull);
      expect(createdManagers['dev-live-solo']!.isDisposed, isFalse);

      // 刪除該唯一設備
      await notifier.removeDevice('dev-live-solo');

      // 核心安全斷言 (P0 #1 Live Mode)：
      // 刪除活躍設備時，其 Transport 必須立即 dispose，狀態變為 offline
      expect(createdManagers['dev-live-solo']!.isDisposed, isTrue, reason: '刪除裝置必須銷毀其 Transport');
      expect(notifier.transportManager, isNull);
      expect(container.read(deviceProvider).activeDevice, isNull);
      expect(container.read(deviceProvider).activeTransport, TransportType.offline);
    });

    test('Live Mode: connectAll error handles gracefully, disposes failed manager and transitions to offline', () async {
      TrackableDualTransportManager? failedMgr;

      final container = ProviderContainer(
        overrides: [
          transportManagerFactoryProvider.overrideWithValue(
            ({required relayClient, required meshClient}) {
              failedMgr = TrackableDualTransportManager(
                deviceTag: 'failing',
                onConnectAll: () async {
                  throw Exception('Network unreachable');
                },
              );
              return failedMgr!;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);
      notifier.toggleDemoMode(false);

      final devFail = InstanceInfo(
        instanceId: 'dev-fail',
        uuid: 'uuid-fail',
        name: 'Fail Host',
        status: InstanceConnectionStatus.connected,
        transport: TransportType.relay,
        lastSeen: DateTime.now(),
      );

      await notifier.connectToDevice(devFail);

      // 斷言：失敗時 newManager 必須被 dispose，state 轉為 offline 並標記錯誤
      expect(failedMgr!.isDisposed, isTrue, reason: '連線失敗時新 Manager 必須被 dispose 避免資源洩漏');
      expect(notifier.transportManager, isNull);
      final state = container.read(deviceProvider);
      expect(state.isConnecting, isFalse);
      expect(state.activeTransport, TransportType.offline);
      expect(state.connectionError, contains('Network unreachable'));
    });
  });
}
