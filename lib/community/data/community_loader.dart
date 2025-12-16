import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/community_post.dart';

class CommunityLoader {
  static Future<List<CommunityPost>> loadPosts() async {
    final raw = await rootBundle.loadString(
      'assets/community/community_posts.json',
    );

    final List data = json.decode(raw);
    return data.map((e) => CommunityPost.fromJson(e)).toList();
  }
}
