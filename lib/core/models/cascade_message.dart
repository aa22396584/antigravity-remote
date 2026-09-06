import 'trajectory_step.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

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
  };

  factory CascadeMessage.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    final durationMs = json['thinkingDurationMs'] ?? json['thinking_duration_ms'];

    return CascadeMessage(
      id: json['id'] as String? ?? '',
      cascadeId: (json['cascadeId'] ?? json['cascade_id']) as String? ?? '',
      role: MessageRole.values.firstWhere(
        (e) =>
            e.name == rawRole ||
            rawRole?.toUpperCase().contains(e.name.toUpperCase()) == true,
        orElse: () => MessageRole.assistant,
      ),
      content: (json['content'] ?? json['text']) as String? ?? '',
      thinking: json['thinking'] as String?,
      isThinking: (json['isThinking'] ?? json['is_thinking']) as bool? ?? false,
      thinkingDuration: durationMs != null
          ? Duration(milliseconds: (durationMs as num).toInt())
          : null,
      trajectorySteps: ((json['trajectorySteps'] ??
                  json['trajectory_steps'] ??
                  json['steps']) as List<dynamic>?)
              ?.map((e) => TrajectoryStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isStreaming:
          (json['isStreaming'] ?? json['is_streaming']) as bool? ?? false,
      timestamp: (json['timestamp'] ?? json['created_at']) != null
          ? DateTime.tryParse(
                  (json['timestamp'] ?? json['created_at']) as String) ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}
