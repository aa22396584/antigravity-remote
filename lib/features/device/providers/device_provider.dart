import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/instance_info.dart';
import '../../../core/network/cloud_relay_client.dart';
import '../../../core/network/dual_transport_manager.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/webrtc_mesh_client.dart';
import '../../../core/services/diagnostic_service.dart';
import '../../../core/services/mock_antigravity_service.dart';
import '../../../core/services/remote_control_service.dart';
import '../../../core/services/storage_service.dart';

class DeviceState {
  final List<InstanceInfo> devices;
  final InstanceInfo? activeDevice;
  final bool isConnecting;
  final String? connectionError;
  final CloudEnvironment environment;
  final String? accessToken;
  final bool isDemoMode;
  final TransportType activeTransport;
  final int? currentLatencyMs;
  final BootState bootState;

  const DeviceState({
    this.devices = const [],
    this.activeDevice,
    this.isConnecting = false,
    this.connectionError,
    this.environment = CloudEnvironment.production,
    this.accessToken,
    this.isDemoMode = true,
    this.activeTransport = TransportType.p2p,
    this.currentLatencyMs,
    this.bootState = BootState.ready,
  });

  DeviceState copyWith({
    List<InstanceInfo>? devices,
    InstanceInfo? activeDevice,
    bool clearActiveDevice = false,
    bool? isConnecting,
    String? connectionError,
    bool clearError = false,
    CloudEnvironment? environment,
    String? accessToken,
    bool clearAccessToken = false,
    bool? isDemoMode,
    TransportType? activeTransport,
    int? currentLatencyMs,
    bool clearLatency = false,
    BootState? bootState,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      activeDevice: clearActiveDevice ? null : (activeDevice ?? this.activeDevice),
      isConnecting: isConnecting ?? this.isConnecting,
      connectionError: clearError ? null : (connectionError ?? this.connectionError),
      environment: environment ?? this.environment,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      isDemoMode: isDemoMode ?? this.isDemoMode,
      activeTransport: activeTransport ?? this.activeTransport,
      currentLatencyMs: clearLatency ? null : (currentLatencyMs ?? this.currentLatencyMs),
      bootState: bootState ?? this.bootState,
    );
  }
}

class DeviceNotifier extends Notifier<DeviceState> {
  DualTransportManager? _transportManager;
  StreamSubscription? _transportSub;
  StreamSubscription? _latencySub;
  RemoteControlService? _remoteControlService;
  Timer? _demoTimer;

  RemoteControlService get remoteControlService =>
      _remoteControlService ??= RemoteControlService(
        isDemoMode: state.isDemoMode,
        transportManager: _transportManager,
      );

  @override
  DeviceState build() {
    final storage = ref.watch(storageServiceProvider);
    final bootState = storage?.bootState ?? StorageService.lastBootState;

    ref.onDispose(() {
      _demoTimer?.cancel();
      _transportSub?.cancel();
      _latencySub?.cancel();
      _transportManager?.dispose();
      _remoteControlService?.dispose();
    });

    if (storage != null) {
      final saved = storage.getSavedInstances();
      final env = storage.getEnvironment();
      final token = storage.getAccessToken();
      final isDemo = storage.isDemoMode();

      final list = isDemo
          ? (saved.isNotEmpty ? saved : MockAntigravityService.instance.getMockInstances())
          : saved;
      final defaultDev = list.isNotEmpty
          ? list.firstWhere((e) => e.isDefault, orElse: () => list.first)
          : null;

      return DeviceState(
        devices: list,
        activeDevice: defaultDev,
        environment: env,
        accessToken: token,
        isDemoMode: isDemo,
        activeTransport: defaultDev?.transport ?? TransportType.offline,
        currentLatencyMs: defaultDev?.latencyMs,
        bootState: bootState,
      );
    } else {
      final list = MockAntigravityService.instance.getMockInstances();
      return DeviceState(
        devices: list,
        activeDevice: list.first,
        isDemoMode: true,
        bootState: BootState.ready,
      );
    }
  }

  StorageService? get _storageService => ref.read(storageServiceProvider);
  DualTransportManager? get transportManager => _transportManager;

  void toggleDemoMode(bool enabled) {
    if (enabled && _transportManager != null) {
      _transportSub?.cancel();
      _transportSub = null;
      _latencySub?.cancel();
      _latencySub = null;
      _transportManager?.dispose();
      _transportManager = null;
    }
    state = state.copyWith(isDemoMode: enabled);
    _storageService?.setDemoMode(enabled);
    _remoteControlService?.updateConfiguration(
      isDemoMode: enabled,
      transportManager: _transportManager,
    );
  }

  Future<void> setEnvironment(CloudEnvironment env) async {
    state = state.copyWith(environment: env);
    await _storageService?.setEnvironment(env);
    if (state.activeDevice != null && !state.isDemoMode) {
      await connectToDevice(state.activeDevice!);
    }
  }

  Future<void> setAccessToken(String token) async {
    state = state.copyWith(
      accessToken: token,
      clearAccessToken: token.isEmpty,
    );
    await _storageService?.setAccessToken(token);
    if (state.activeDevice != null && !state.isDemoMode) {
      await connectToDevice(state.activeDevice!);
    }
  }

  /// 登出並清除平台安全憑證 (Issue #14, #15)
  Future<void> logout() async {
    _transportSub?.cancel();
    _transportSub = null;
    _latencySub?.cancel();
    _latencySub = null;
    await _transportManager?.dispose();
    _transportManager = null;
    _remoteControlService?.updateConfiguration(
      isDemoMode: state.isDemoMode,
      transportManager: null,
    );

    state = state.copyWith(
      clearAccessToken: true,
      activeTransport: TransportType.offline,
      clearLatency: true,
    );

    await _storageService?.clearAccessToken();
  }

  Future<bool> addDevice({
    required String instanceId,
    String? name,
    String? hostname,
  }) async {
    final shortId = instanceId.length > 8 ? instanceId.substring(0, 8) : instanceId;
    final devName = name ?? hostname ?? 'Antigravity ($shortId)';
    final newDevice = InstanceInfo(
      instanceId: instanceId,
      uuid: instanceId,
      name: devName,
      status: state.isDemoMode
          ? InstanceConnectionStatus.connected
          : InstanceConnectionStatus.unverified,
      transport: state.isDemoMode ? TransportType.p2p : TransportType.offline,
      latencyMs: state.isDemoMode ? 16 : null,
      lastSeen: DateTime.now(),
      isDefault: state.devices.isEmpty,
    );

    final updated = [newDevice, ...state.devices.where((d) => d.instanceId != instanceId)];

    if (state.isDemoMode) {
      _demoTimer?.cancel();
      _demoTimer = null;
      _transportSub?.cancel();
      _transportSub = null;
      _latencySub?.cancel();
      _latencySub = null;
      await _transportManager?.dispose();
      _transportManager = null;
      _remoteControlService?.updateConfiguration(
        isDemoMode: true,
        transportManager: null,
      );
      state = state.copyWith(
        devices: updated,
        activeDevice: newDevice,
        isConnecting: false,
        activeTransport: newDevice.transport,
        currentLatencyMs: newDevice.latencyMs,
      );
      await _storageService?.saveInstance(newDevice);
      return true;
    }

    state = state.copyWith(
      devices: updated,
    );
    await _storageService?.saveInstance(newDevice);

    return await connectToDevice(newDevice);
  }

  int _connectionEpoch = 0;

  Future<bool> connectToDevice(InstanceInfo device) async {
    final epoch = ++_connectionEpoch;

    _demoTimer?.cancel();
    _demoTimer = null;

    // 立即取消既有訂閱與釋放舊連線，杜絕舊連線殘留與控制目標不一致 (P0 #1)
    _transportSub?.cancel();
    _transportSub = null;
    _latencySub?.cancel();
    _latencySub = null;
    await _transportManager?.dispose();
    _transportManager = null;

    _remoteControlService?.updateConfiguration(
      isDemoMode: state.isDemoMode,
      transportManager: null,
    );

    state = state.copyWith(
      isConnecting: true,
      clearError: true,
      activeDevice: device,
    );

    if (state.isDemoMode) {
      final completer = Completer<void>();
      _demoTimer = Timer(const Duration(milliseconds: 300), () {
        if (_connectionEpoch == epoch) {
          _remoteControlService?.updateConfiguration(
            isDemoMode: true,
            transportManager: null,
          );

          state = state.copyWith(
            isConnecting: false,
            activeTransport: device.transport,
            currentLatencyMs: device.latencyMs ?? 14,
          );
        }
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      return true;
    }

    DualTransportManager? newManager;
    try {
      final token = state.accessToken ?? '';
      final relayClient = CloudRelayClient(
        baseUrl: state.environment.url,
        googleAccessToken: token,
        targetInstanceUuid: device.uuid.isNotEmpty ? device.uuid : device.instanceId,
      );

      final meshClient = WebRtcMeshClient(
        baseUrl: state.environment.url,
        googleAccessToken: token,
        targetInstanceUuid: device.uuid.isNotEmpty ? device.uuid : device.instanceId,
      );

      final factory = ref.read(transportManagerFactoryProvider);
      newManager = factory(
        relayClient: relayClient,
        meshClient: meshClient,
      );

      if (_connectionEpoch != epoch) {
        await newManager.dispose();
        return false;
      }

      await newManager.connectAll();

      if (_connectionEpoch != epoch) {
        await newManager.dispose();
        return false;
      }

      _transportManager = newManager;

      _transportSub = newManager.transportStream.listen((transport) {
        if (_connectionEpoch == epoch) {
          state = state.copyWith(activeTransport: transport);
        }
      });

      _latencySub = newManager.latencyStream.listen((lat) {
        if (_connectionEpoch == epoch) {
          state = state.copyWith(currentLatencyMs: lat);
        }
      });

      _remoteControlService?.updateConfiguration(
        isDemoMode: state.isDemoMode,
        transportManager: newManager,
      );

      final connectedDev = device.copyWith(
        status: InstanceConnectionStatus.connected,
        transport: newManager.currentTransport,
        latencyMs: newManager.currentLatencyMs,
      );
      final newDevices = state.devices.map((d) => d.instanceId == device.instanceId ? connectedDev : d).toList();

      state = state.copyWith(
        devices: newDevices,
        activeDevice: connectedDev,
        isConnecting: false,
        activeTransport: newManager.currentTransport,
        currentLatencyMs: newManager.currentLatencyMs,
      );
      await _storageService?.saveInstance(connectedDev);
      return true;
    } catch (e) {
      await newManager?.dispose();
      if (_connectionEpoch == epoch) {
        _transportSub?.cancel();
        _transportSub = null;
        _latencySub?.cancel();
        _latencySub = null;
        _transportManager = null;
        _remoteControlService?.updateConfiguration(
          isDemoMode: state.isDemoMode,
          transportManager: null,
        );

        final disconnectedDev = device.copyWith(
          status: InstanceConnectionStatus.disconnected,
          transport: TransportType.offline,
        );
        final newDevices = state.devices.map((d) => d.instanceId == device.instanceId ? disconnectedDev : d).toList();

        state = state.copyWith(
          devices: newDevices,
          activeDevice: disconnectedDev,
          isConnecting: false,
          activeTransport: TransportType.offline,
          clearLatency: true,
          connectionError: e.toString(),
        );
        await _storageService?.saveInstance(disconnectedDev);
      }
      return false;
    }
  }

  Future<void> selectDevice(InstanceInfo device) async {
    await connectToDevice(device);
  }

  Future<void> removeDevice(String instanceId) async {
    ++_connectionEpoch;
    final updated = state.devices.where((d) => d.instanceId != instanceId).toList();
    final wasActive = state.activeDevice?.instanceId == instanceId;
    InstanceInfo? nextActive;
    if (wasActive) {
      nextActive = updated.isNotEmpty ? updated.first : null;
    } else {
      nextActive = state.activeDevice;
    }

    if (wasActive) {
      _transportSub?.cancel();
      _transportSub = null;
      _latencySub?.cancel();
      _latencySub = null;
      await _transportManager?.dispose();
      _transportManager = null;
      _remoteControlService?.updateConfiguration(
        isDemoMode: state.isDemoMode,
        transportManager: null,
      );
    }

    state = state.copyWith(
      devices: updated,
      activeDevice: nextActive,
      clearActiveDevice: nextActive == null,
      activeTransport: nextActive == null ? TransportType.offline : null,
    );
    await _storageService?.removeInstance(instanceId);

    if (wasActive && nextActive != null) {
      await connectToDevice(nextActive);
    }
  }

  String exportDiagnosticReport() {
    return DiagnosticService.instance.exportReport(
      appVersion: '1.0.0+1',
      isDemoMode: state.isDemoMode,
      environment: state.environment.name,
      deviceCount: state.devices.length,
    );
  }
}

final storageServiceProvider = Provider<StorageService?>((ref) => null);

final remoteControlServiceProvider = Provider<RemoteControlService>((ref) {
  return ref.watch(deviceProvider.notifier).remoteControlService;
});

typedef TransportManagerFactory = DualTransportManager Function({
  required CloudRelayClient relayClient,
  required WebRtcMeshClient meshClient,
});

final transportManagerFactoryProvider = Provider<TransportManagerFactory>((ref) {
  return ({required relayClient, required meshClient}) => DualTransportManager(
        relayClient: relayClient,
        meshClient: meshClient,
      );
});

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(DeviceNotifier.new);
