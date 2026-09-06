import 'user_interaction.dart';

enum StepStatus {
  running,
  waitingUserInteraction,
  completed,
  failed,
  rejected,
}

enum StepType {
  toolCall,
  thinking,
  terminalOutput,
  fileChange,
  statusNotice,
}

class TrajectoryStep {
  final String stepId;
  final StepType type;
  final String toolName;
  final String summary;
  final String description;
  final Map<String, dynamic> arguments;
  final String? output;
  final String? codeDiff;
  final StepStatus status;
  final UserInteractionRequest? interaction;
  final DateTime timestamp;
  final Duration? executionDuration;

  const TrajectoryStep({
    required this.stepId,
    required this.type,
    required this.toolName,
    required this.summary,
    this.description = '',
    this.arguments = const {},
    this.output,
    this.codeDiff,
    this.status = StepStatus.running,
    this.interaction,
    required this.timestamp,
    this.executionDuration,
  });

  TrajectoryStep copyWith({
    String? stepId,
    StepType? type,
    String? toolName,
    String? summary,
    String? description,
    Map<String, dynamic>? arguments,
    String? output,
    String? codeDiff,
    StepStatus? status,
    UserInteractionRequest? interaction,
    DateTime? timestamp,
    Duration? executionDuration,
  }) {
    return TrajectoryStep(
      stepId: stepId ?? this.stepId,
      type: type ?? this.type,
      toolName: toolName ?? this.toolName,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      arguments: arguments ?? this.arguments,
      output: output ?? this.output,
      codeDiff: codeDiff ?? this.codeDiff,
      status: status ?? this.status,
      interaction: interaction ?? this.interaction,
      timestamp: timestamp ?? this.timestamp,
      executionDuration: executionDuration ?? this.executionDuration,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'type': type.name,
    'toolName': toolName,
    'summary': summary,
    'description': description,
    'arguments': arguments,
    'output': output,
    'codeDiff': codeDiff,
    'status': status.name,
    'interaction': interaction?.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'executionDurationMs': executionDuration?.inMilliseconds,
  };

  factory TrajectoryStep.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? json['step_type'])?.toString();
    final rawStatus = (json['status'] ?? json['step_status'])?.toString();
    final durationMs = json['executionDurationMs'] ?? json['execution_duration_ms'];

    return TrajectoryStep(
      stepId: (json['stepId'] ?? json['step_id']) as String? ?? '',
      type: StepType.values.firstWhere(
        (e) =>
            e.name == rawType ||
            e.name.toLowerCase() == rawType?.toLowerCase().replaceAll('_', ''),
        orElse: () => StepType.toolCall,
      ),
      toolName: (json['toolName'] ?? json['tool_name']) as String? ?? '',
      summary: json['summary'] as String? ?? '執行工具',
      description: json['description'] as String? ?? '',
      arguments: (json['arguments'] ?? json['args'] as Map<String, dynamic>?) ??
          const {},
      output: json['output'] as String?,
      codeDiff: (json['codeDiff'] ?? json['code_diff']) as String?,
      status: StepStatus.values.firstWhere(
        (e) =>
            e.name == rawStatus ||
            e.name.toLowerCase() == rawStatus?.toLowerCase().replaceAll('_', ''),
        orElse: () => StepStatus.completed,
      ),
      interaction: (json['interaction'] ?? json['user_interaction']) != null
          ? UserInteractionRequest.fromJson(
              (json['interaction'] ?? json['user_interaction'])
                  as Map<String, dynamic>)
          : null,
      timestamp: (json['timestamp'] ?? json['created_at']) != null
          ? DateTime.tryParse(
                  (json['timestamp'] ?? json['created_at']) as String) ??
              DateTime.now()
          : DateTime.now(),
      executionDuration: durationMs != null
          ? Duration(milliseconds: (durationMs as num).toInt())
          : null,
    );
  }
}
