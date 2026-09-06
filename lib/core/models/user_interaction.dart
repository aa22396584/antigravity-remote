enum UserInteractionType {
  askPermission,
  askQuestion,
  custom,
}

enum InteractionStatus {
  pending,
  approved,
  rejected,
  timedOut,
}

class UserInteractionRequest {
  final String interactionId;
  final UserInteractionType type;
  final String title;
  final String description;
  final String actionTarget; // e.g. command string or file path
  final String actionName; // e.g. "command", "write_file", "run_command"
  final List<String> options; // for questions
  final bool isMultiSelect;
  final bool isDestructive; // warnings for rm, sudo, git reset
  final InteractionStatus status;
  final String? userFeedback;
  final DateTime requestedAt;

  const UserInteractionRequest({
    required this.interactionId,
    required this.type,
    required this.title,
    required this.description,
    required this.actionTarget,
    this.actionName = 'command',
    this.options = const [],
    this.isMultiSelect = false,
    this.isDestructive = false,
    this.status = InteractionStatus.pending,
    this.userFeedback,
    required this.requestedAt,
  });

  UserInteractionRequest copyWith({
    String? interactionId,
    UserInteractionType? type,
    String? title,
    String? description,
    String? actionTarget,
    String? actionName,
    List<String>? options,
    bool? isMultiSelect,
    bool? isDestructive,
    InteractionStatus? status,
    String? userFeedback,
    DateTime? requestedAt,
  }) {
    return UserInteractionRequest(
      interactionId: interactionId ?? this.interactionId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      actionTarget: actionTarget ?? this.actionTarget,
      actionName: actionName ?? this.actionName,
      options: options ?? this.options,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      isDestructive: isDestructive ?? this.isDestructive,
      status: status ?? this.status,
      userFeedback: userFeedback ?? this.userFeedback,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'interactionId': interactionId,
    'type': type.name,
    'title': title,
    'description': description,
    'actionTarget': actionTarget,
    'actionName': actionName,
    'options': options,
    'isMultiSelect': isMultiSelect,
    'isDestructive': isDestructive,
    'status': status.name,
    'userFeedback': userFeedback,
    'requestedAt': requestedAt.toIso8601String(),
  };

  factory UserInteractionRequest.fromJson(Map<String, dynamic> json) {
    return UserInteractionRequest(
      interactionId: json['interactionId'] as String? ?? '',
      type: UserInteractionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => UserInteractionType.askPermission,
      ),
      title: json['title'] as String? ?? '請求授權',
      description: json['description'] as String? ?? '',
      actionTarget: json['actionTarget'] as String? ?? '',
      actionName: json['actionName'] as String? ?? 'command',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isMultiSelect: json['isMultiSelect'] as bool? ?? false,
      isDestructive: json['isDestructive'] as bool? ?? false,
      status: InteractionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InteractionStatus.pending,
      ),
      userFeedback: json['userFeedback'] as String?,
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
