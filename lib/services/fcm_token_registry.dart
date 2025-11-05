// lib/services/fcm_token_registry.dart
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmTokenRegistry {
  static final _fs = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  /// Call after sign-in and at app boot.
  static Future<void> registerForUser(String uid) async {
    // Ask permission if needed (safe on Android/iOS)
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      await _upsert(uid, token);
    }

    // keep in sync only when token actually changes
    _messaging.onTokenRefresh.listen((newToken) async {
      await _upsert(uid, newToken);
    });
  }

  /// Remove current token when the user logs out (best effort).
  static Future<void> removeCurrentToken(String uid) async {
    try {
      final t = await _messaging.getToken();
      if (t != null && t.isNotEmpty) {
        await _fs.collection('users').doc(uid).set({
          'fcmTokens.$t': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
    try {
      await _messaging.deleteToken(); // make sure we don’t reuse stale token
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_fcm_token');
  }

  static Future<void> _upsert(String uid, String token) async {
    if (token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSaved = prefs.getString('last_fcm_token');
    if (lastSaved == token) return; // de-dupe: unchanged token → skip write

    final platform = Platform.operatingSystem; // 'android' | 'ios' | ...

    await _fs.collection('users').doc(uid).set({
      'fcmTokens': {
        token: {
          'platform': platform,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));

    await prefs.setString('last_fcm_token', token);

    // keep the doc tidy
    await _prune(uid, maxKeep: 6, maxAgeDays: 45);
  }

  /// Keep only the newest [maxKeep] tokens and drop tokens older than [maxAgeDays].
  static Future<void> _prune(
    String uid, {
    int maxKeep = 6,
    int maxAgeDays = 45,
  }) async {
    final doc = await _fs.collection('users').doc(uid).get();
    final map = Map<String, dynamic>.from(doc.data()?['fcmTokens'] ?? {});
    if (map.isEmpty) return;

    final items = <_Tok>[];
    map.forEach((tok, val) {
      final v = Map<String, dynamic>.from(val ?? {});
      final ts = v['updatedAt'];
      final ms = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
      items.add(_Tok(tok, ms));
    });

    items.sort((a, b) => b.ms.compareTo(a.ms)); // newest first

    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = Duration(days: maxAgeDays).inMilliseconds;

    final toDelete = <String>{};

    // drop extras beyond maxKeep
    for (final extra in items.skip(maxKeep)) {
      toDelete.add(extra.token);
    }

    // drop too-old among those we kept
    for (final keep in items.take(maxKeep)) {
      final age = now - keep.ms;
      if (keep.ms > 0 && age > maxAgeMs) toDelete.add(keep.token);
    }

    if (toDelete.isEmpty) return;

    final updates = <String, dynamic>{};
    for (final t in toDelete) {
      updates['fcmTokens.$t'] = FieldValue.delete();
    }
    await _fs
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }
}

class _Tok {
  final String token;
  final int ms;
  _Tok(this.token, this.ms);
}
