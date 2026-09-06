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
    return CascadeMessage(
      id: json['id'] as String? ?? '',
      cascadeId: json['cascadeId'] as String? ?? '',
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      thinking: json['thinking'] as String?,
      isThinking: json['isThinking'] as bool? ?? false,
      thinkingDuration: json['thinkingDurationMs'] != null
          ? Duration(milliseconds: json['thinkingDurationMs'] as int)
          : null,
      trajectorySteps: (json['trajectorySteps'] as List<dynamic>?)
              ?.map((e) => TrajectoryStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isStreaming: json['isStreaming'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
