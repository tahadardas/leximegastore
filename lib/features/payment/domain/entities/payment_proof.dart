enum PaymentProofStatus { pending, approved, rejected }

class PaymentProof {
  final String orderId;
  final String? imageUrl;
  final String? localFilePath;
  final PaymentProofStatus status;
  final String? note;

  const PaymentProof({
    required this.orderId,
    this.imageUrl,
    this.localFilePath,
    this.status = PaymentProofStatus.pending,
    this.note,
  });

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString().trim().toLowerCase();

    final status = switch (rawStatus) {
      'approved' || 'accepted' || 'done' => PaymentProofStatus.approved,
      'rejected' || 'failed' || 'declined' => PaymentProofStatus.rejected,
      _ => PaymentProofStatus.pending,
    };

    return PaymentProof(
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      imageUrl: _nullableText(json['image_url'] ?? json['url']),
      localFilePath: _nullableText(json['local_file_path']),
      status: status,
      note: _nullableText(json['note'] ?? json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'image_url': imageUrl,
      'local_file_path': localFilePath,
      'status': status.name,
      'note': note,
    };
  }

  PaymentProof copyWith({
    String? orderId,
    String? imageUrl,
    String? localFilePath,
    PaymentProofStatus? status,
    String? note,
  }) {
    return PaymentProof(
      orderId: orderId ?? this.orderId,
      imageUrl: imageUrl ?? this.imageUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
