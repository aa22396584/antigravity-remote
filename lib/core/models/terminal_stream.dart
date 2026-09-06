class TerminalChunk {
  final String text;
  final bool isError;
  final DateTime timestamp;

  const TerminalChunk({
    required this.text,
    this.isError = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isError': isError,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TerminalChunk.fromJson(Map<String, dynamic> json) {
    return TerminalChunk(
      text: json['text'] as String? ?? '',
      isError: json['isError'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
