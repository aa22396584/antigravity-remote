import 'trajectory_step.dart';

enum MessageRole { user, assistant, system }

/// 訊息交付狀態 (Issue #19)
enum MessageDeliveryStatus { sending, confirmed, failed, unknown }

class CascadeMessage {
  final String id;
  final String cascadeId;
  final MessageRole role;
  final String content;
  final String? thinking;
  final bool isThinking;
  final Duration? thinkingDuration;
  final List<TrajectoryStep> trajectorySteps;
  final bool isStreaming;
  final DateTime timestamp;
  final MessageDeliveryStatus deliveryStatus;

  const CascadeMessage({
    required this.id,
    required this.cascadeId,
    required this.role,
    required this.content,
    this.thinking,
    this.isThinking = false,
    this.thinkingDuration,
    this.trajectorySteps = const [],
    this.isStreaming = false,
    required this.timestamp,
    this.deliveryStatus = MessageDeliveryStatus.confirmed,
  });

  CascadeMessage copyWith({
    String? id,
    String? cascadeId,
    MessageRole? role,
    String? content,
    String? thinking,
    bool? isThinking,
    Duration? thinkingDuration,
    List<TrajectoryStep>? trajectorySteps,
    bool? isStreaming,
    DateTime? timestamp,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return CascadeMessage(
      id: id ?? this.id,
      cascadeId: cascadeId ?? this.cascadeId,
      role: role ?? this.role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      isThinking: isThinking ?? this.isThinking,
      thinkingDuration: thinkingDuration ?? this.thinkingDuration,
      trajectorySteps: trajectorySteps ?? this.trajectorySteps,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp ?? this.timestamp,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cascadeId': cascadeId,
    'role': role.name,
    'content': content,
    'thinking': thinking,
    'isThinking': isThinking,
    'thinkingDurationMs': thinkingDuration?.inMilliseconds,
    'trajectorySteps': trajectorySteps.map((s) => s.toJson()).toList(),
    'isStreaming': isStreaming,
    'timestamp': timestamp.toIso8601String(),
    'deliveryStatus': deliveryStatus.name,
  };

  factory CascadeMessage.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] ?? json['message_role'])?.toString();
    final normRole = rawRole?.toLowerCase().replaceAll('_', '');
    final durationMs =
        json['thinkingDurationMs'] ?? json['thinking_duration_ms'];
    final rawIsThinking = json['isThinking'] ?? json['is_thinking'];
    final rawIsStreaming = json['isStreaming'] ?? json['is_streaming'];
    final rawDelivery = json['deliveryStatus']?.toString();

    return CascadeMessage(
      id: (json['id'] ?? json['message_id'] ?? json['msg_id']) as String? ?? '',
      cascadeId: (json['cascadeId'] ?? json['cascade_id']) as String? ?? '',
      role: MessageRole.values.firstWhere((e) {
        final target = e.name.toLowerCase();
        return e.name == rawRole ||
            target == normRole ||
            (normRole != null && normRole.endsWith(target));
      }, orElse: () => MessageRole.assistant),
      content:
          (json['content'] ?? json['text'] ?? json['message'])?.toString() ??
          '',
      thinking: (json['thinking'] ?? json['thinking_content'])?.toString(),
      isThinking:
          rawIsThinking == true ||
          rawIsThinking == 1 ||
          rawIsThinking == 'true',
      thinkingDuration: durationMs != null
          ? Duration(milliseconds: (durationMs as num).toInt())
          : null,
      trajectorySteps:
          ((json['trajectorySteps'] ??
                      json['trajectory_steps'] ??
                      json['steps'])
                  as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => TrajectoryStep.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      isStreaming:
          rawIsStreaming == true ||
          rawIsStreaming == 1 ||
          rawIsStreaming == 'true',
      timestamp: (json['timestamp'] ?? json['created_at']) != null
          ? DateTime.tryParse(
                  (json['timestamp'] ?? json['created_at']) as String,
                ) ??
                DateTime.now()
          : DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == rawDelivery,
        orElse: () => MessageDeliveryStatus.confirmed,
      ),
    );
  }
}
