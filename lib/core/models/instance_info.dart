enum InstanceConnectionStatus {
  unspecified,
  connected,
  disconnected,
  idle,
}

enum TransportType {
  p2p,
  relay,
  offline,
}

class InstanceInfo {
  final String instanceId;
  final String uuid;
  final String name;
  final String version;
  final InstanceConnectionStatus status;
  final TransportType transport;
  final int? latencyMs;
  final DateTime lastSeen;
  final bool isDefault;

  const InstanceInfo({
    required this.instanceId,
    required this.uuid,
    required this.name,
    this.version = '2.12.2',
    this.status = InstanceConnectionStatus.connected,
    this.transport = TransportType.relay,
    this.latencyMs,
    required this.lastSeen,
    this.isDefault = false,
  });

  InstanceInfo copyWith({
    String? instanceId,
    String? uuid,
    String? name,
    String? version,
    InstanceConnectionStatus? status,
    TransportType? transport,
    int? latencyMs,
    DateTime? lastSeen,
    bool? isDefault,
  }) {
    return InstanceInfo(
      instanceId: instanceId ?? this.instanceId,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      version: version ?? this.version,
      status: status ?? this.status,
      transport: transport ?? this.transport,
      latencyMs: latencyMs ?? this.latencyMs,
      lastSeen: lastSeen ?? this.lastSeen,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'instanceId': instanceId,
    'uuid': uuid,
    'name': name,
    'version': version,
    'status': status.name,
    'transport': transport.name,
    'latencyMs': latencyMs,
    'lastSeen': lastSeen.toIso8601String(),
    'isDefault': isDefault,
  };

  factory InstanceInfo.fromJson(Map<String, dynamic> json) {
    return InstanceInfo(
      instanceId: json['instanceId'] as String? ?? '',
      uuid: json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? 'Antigravity Desktop',
      version: json['version'] as String? ?? '2.12.2',
      status: InstanceConnectionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InstanceConnectionStatus.connected,
      ),
      transport: TransportType.values.firstWhere(
        (e) => e.name == json['transport'],
        orElse: () => TransportType.relay,
      ),
      latencyMs: json['latencyMs'] as int?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
