class EmailLogModel {
  final String id;
  final String? taskId;
  final String recipientEmail;
  final String eventType;
  final String subject;
  final String contentPreview;
  final String status; // 'pending', 'sent', 'failed'
  final int attempts;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime createdAt;

  EmailLogModel({
    required this.id,
    this.taskId,
    required this.recipientEmail,
    required this.eventType,
    required this.subject,
    required this.contentPreview,
    required this.status,
    required this.attempts,
    this.errorMessage,
    this.sentAt,
    required this.createdAt,
  });

  factory EmailLogModel.fromJson(Map<String, dynamic> json) {
    return EmailLogModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString(),
      recipientEmail: json['recipientEmail'] ?? '',
      eventType: json['eventType'] ?? 'general',
      subject: json['subject'] ?? '',
      contentPreview: json['contentPreview'] ?? '',
      status: json['status'] ?? 'pending',
      attempts: (json['attempts'] as num?)?.toInt() ?? 1,
      errorMessage: json['errorMessage'],
      sentAt: json['sentAt'] != null ? DateTime.tryParse(json['sentAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';
}
