class CommunityPost {
  final String id;
  final String content;
  final String category;
  final int likes;
  final int replies;
  final int week;
  final String authorLabel;
  final DateTime createdAt;
  final bool isSeed;

  CommunityPost({
    required this.id,
    required this.content,
    required this.category,
    required this.likes,
    required this.replies,
    required this.week,
    required this.authorLabel,
    required this.createdAt,
    required this.isSeed,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'],
      content: json['content'],
      category: json['category'],
      likes: json['likes'] ?? 0,
      replies: json['replies'] ?? 0,
      week: json['week'] ?? 0,
      authorLabel: json['authorLabel'] ?? 'Anonymous',
      createdAt: DateTime.parse(json['createdAt']),
      isSeed: json['isSeed'] ?? true,
    );
  }
}
