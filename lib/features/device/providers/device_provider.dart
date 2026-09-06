import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/instance_info.dart';
import '../../../core/network/cloud_relay_client.dart';
import '../../../core/network/dual_transport_manager.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/webrtc_mesh_client.dart';
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

  const DeviceState({
    this.devices = const [],
    this.activeDevice,
    this.isConnecting = false,
    this.connectionError,
    this.environment = CloudEnvironment.production,
    this.accessToken,
    this.isDemoMode = true,
    this.activeTransport = TransportType.p2p,
    this.currentLatencyMs = 14,
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
    bool? isDemoMode,
    TransportType? activeTransport,
    int? currentLatencyMs,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      activeDevice: clearActiveDevice ? null : (activeDevice ?? this.activeDevice),
      isConnecting: isConnecting ?? this.isConnecting,
      connectionError: clearError ? null : (connectionError ?? this.connectionError),
      environment: environment ?? this.environment,
      accessToken: accessToken ?? this.accessToken,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      activeTransport: activeTransport ?? this.activeTransport,
      currentLatencyMs: currentLatencyMs ?? this.currentLatencyMs,
    );
  }
}

class DeviceNotifier extends Notifier<DeviceState> {
  DualTransportManager? _transportManager;
  StreamSubscription? _transportSub;
  StreamSubscription? _latencySub;
  RemoteControlService? _remoteControlService;

  RemoteControlService get remoteControlService =>
      _remoteControlService ??= RemoteControlService(
        isDemoMode: state.isDemoMode,
        transportManager: _transportManager,
      );

  @override
  DeviceState build() {
    final storage = ref.watch(storageServiceProvider);

    ref.onDispose(() {
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

      final list = saved.isNotEmpty ? saved : MockAntigravityService.instance.getMockInstances();
      final defaultDev = list.firstWhere((e) => e.isDefault, orElse: () => list.first);

      return DeviceState(
        devices: list,
        activeDevice: defaultDev,
        environment: env,
        accessToken: token,
        isDemoMode: isDemo,
        activeTransport: defaultDev.transport,
        currentLatencyMs: defaultDev.latencyMs ?? 14,
      );
    } else {
      final list = MockAntigravityService.instance.getMockInstances();
      return DeviceState(
        devices: list,
        activeDevice: list.first,
        isDemoMode: true,
      );
    }
  }

  StorageService? get _storageService => ref.read(storageServiceProvider);
  DualTransportManager? get transportManager => _transportManager;

  void toggleDemoMode(bool enabled) {
    state = state.copyWith(isDemoMode: enabled);
    _storageService?.setDemoMode(enabled);
    _remoteControlService?.updateConfiguration(
      isDemoMode: enabled,
      transportManager: _transportManager,
    );
  }

  void setEnvironment(CloudEnvironment env) {
    state = state.copyWith(environment: env);
    _storageService?.setEnvironment(env);
  }

  void setAccessToken(String token) {
    state = state.copyWith(accessToken: token);
    _storageService?.setAccessToken(token);
  }

  Future<void> addDevice({
    required String instanceId,
    String? name,
    String? hostname,
  }) async {
    final shortId = instanceId.length > 8 ? instanceId.substring(0, 8) : instanceId;
    final devName = name ?? hostname ?? 'Antigravity ($shortId)';
    final newDevice = InstanceInfo(
      instanceId: instanceId,
      uuid: 'uuid-$instanceId',
      name: devName,
      status: InstanceConnectionStatus.connected,
      transport: TransportType.p2p,
      latencyMs: 16,
      lastSeen: DateTime.now(),
      isDefault: state.devices.isEmpty,
    );

    final updated = [newDevice, ...state.devices.where((d) => d.instanceId != instanceId)];
    state = state.copyWith(
      devices: updated,
      activeDevice: newDevice,
    );
    await _storageService?.saveInstance(newDevice);

    if (!state.isDemoMode) {
      await connectToDevice(newDevice);
    }
  }

  Future<void> connectToDevice(InstanceInfo device) async {
    state = state.copyWith(
      isConnecting: true,
      clearError: true,
      activeDevice: device,
    );

    if (state.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isConnecting: false,
        activeTransport: device.transport,
        currentLatencyMs: device.latencyMs ?? 14,
      );
      return;
    }

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

      _transportSub?.cancel();
      _latencySub?.cancel();

      _transportManager = DualTransportManager(
        relayClient: relayClient,
        meshClient: meshClient,
      );

      _transportSub = _transportManager!.transportStream.listen((transport) {
        state = state.copyWith(activeTransport: transport);
      });

      _latencySub = _transportManager!.latencyStream.listen((lat) {
        state = state.copyWith(currentLatencyMs: lat);
      });

      await _transportManager!.connectAll();

      _remoteControlService?.updateConfiguration(
        isDemoMode: state.isDemoMode,
        transportManager: _transportManager,
      );

      state = state.copyWith(
        isConnecting: false,
        activeTransport: _transportManager!.currentTransport,
        currentLatencyMs: _transportManager!.currentLatencyMs,
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        connectionError: e.toString(),
      );
    }
  }

  void selectDevice(InstanceInfo device) {
    state = state.copyWith(activeDevice: device);
    connectToDevice(device);
  }

  Future<void> removeDevice(String instanceId) async {
    final updated = state.devices.where((d) => d.instanceId != instanceId).toList();
    InstanceInfo? nextActive;
    if (state.activeDevice?.instanceId == instanceId) {
      nextActive = updated.isNotEmpty ? updated.first : null;
    } else {
      nextActive = state.activeDevice;
    }

    state = state.copyWith(
      devices: updated,
      activeDevice: nextActive,
      clearActiveDevice: nextActive == null,
    );
    await _storageService?.removeInstance(instanceId);
  }
}

final storageServiceProvider = Provider<StorageService?>((ref) => null);

final remoteControlServiceProvider = Provider<RemoteControlService>((ref) {
  return ref.watch(deviceProvider.notifier).remoteControlService;
});

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(DeviceNotifier.new);
