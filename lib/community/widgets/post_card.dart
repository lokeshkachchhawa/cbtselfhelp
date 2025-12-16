import 'package:flutter/material.dart';
import '../models/community_post.dart';

const Color teal3 = Color(0xFF008F89);

class PostCard extends StatelessWidget {
  final CommunityPost post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Post detail page later
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    post.authorLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  _categoryBadge(post.category),
                ],
              ),

              const SizedBox(height: 10),

              // Content
              Text(
                post.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              // Actions
              Row(
                children: [
                  _iconText(Icons.favorite_border, post.likes),
                  const SizedBox(width: 16),
                  _iconText(Icons.chat_bubble_outline, post.replies),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconText(IconData icon, int value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 4),
        Text(value.toString(), style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _categoryBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: teal3.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.replaceAll('_', ' '),
        style: const TextStyle(
          color: teal3,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
