class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.message,
    required this.configJson,
    required this.dataJson,
    required this.createdAt,
  });

  final String id;
  final String message;
  final Map<String, dynamic> configJson;
  final Map<String, dynamic> dataJson;
  final String createdAt;

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: (json['id'] ?? '').toString(),
      message: (json['message'] ?? 'Sync update').toString(),
      configJson: Map<String, dynamic>.from(json['configJson'] ?? const {}),
      dataJson: Map<String, dynamic>.from(json['dataJson'] ?? const {}),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'configJson': configJson,
        'dataJson': dataJson,
        'createdAt': createdAt,
      };
}
