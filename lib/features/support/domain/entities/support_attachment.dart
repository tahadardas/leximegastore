class SupportAttachment {
  final int id;
  final int ticketId;
  final int? messageId;
  final int wpAttachmentId;
  final String url;
  final String mimeType;
  final int sizeBytes;
  final String createdAt;

  const SupportAttachment({
    required this.id,
    required this.ticketId,
    required this.messageId,
    required this.wpAttachmentId,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    return SupportAttachment(
      id: toInt(json['id']),
      ticketId: toInt(json['ticket_id']),
      messageId: json['message_id'] == null ? null : toInt(json['message_id']),
      wpAttachmentId: toInt(json['wp_attachment_id']),
      url: (json['url'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      sizeBytes: toInt(json['size_bytes']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticket_id': ticketId,
    'message_id': messageId,
    'wp_attachment_id': wpAttachmentId,
    'url': url,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'created_at': createdAt,
  };
}
