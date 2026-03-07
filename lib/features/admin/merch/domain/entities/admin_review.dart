class AdminReview {
  final int id;
  final int productId;
  final String productName;
  final String author;
  final String authorEmail;
  final String content;
  final int rating;
  final String status;
  final DateTime createdAt;

  const AdminReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.author,
    required this.authorEmail,
    required this.content,
    required this.rating,
    required this.status,
    required this.createdAt,
  });

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    return AdminReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: (json['product_name'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      authorEmail: (json['author_email'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  AdminReview copyWith({
    String? status,
  }) {
    return AdminReview(
      id: id,
      productId: productId,
      productName: productName,
      author: author,
      authorEmail: authorEmail,
      content: content,
      rating: rating,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
