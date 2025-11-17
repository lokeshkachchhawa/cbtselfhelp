// lib/services/course_cache_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseCacheService {
  static const _prefix = 'course_cache:';

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String _key(String courseId) => '$_prefix$courseId';

  /// Read cached JSON for course (returns null if none)
  Future<Map<String, dynamic>?> readCache(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(courseId));
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return m;
    } catch (_) {
      return null;
    }
  }

  /// Save cache object (meta + sessions + updatedAtIso)
  Future<void> writeCache(String courseId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(courseId), json.encode(payload));
  }

  /// Remove cache
  Future<void> clearCache(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(courseId));
  }

  /// Check remote updatedAt (or version) quickly WITHOUT fetching sessions.
  /// Returns {needsUpdate: bool, remoteUpdatedAtIso: String?}
  Future<Map<String, dynamic>> checkIfRemoteNewer(String courseId) async {
    final docRef = _fs.collection('courses').doc(courseId);
    final snap = await docRef.get(); // single small read
    if (!snap.exists) return {'needsUpdate': false, 'remote': null};

    final data = snap.data()!;
    // prefer updatedAt (Timestamp) else version
    final remoteTs = data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
        : null;
    final remoteVersion = data['version']; // int or null

    return {
      'remoteUpdatedAt': remoteTs,
      'remoteVersion': remoteVersion,
      'needsUpdate': true, // caller will compare with local
    };
  }

  /// Fetch meta + all sessions and return payload that should be cached.
  Future<Map<String, dynamic>> fetchFullCourseAndSessions(
    String courseId,
  ) async {
    final courseSnap = await _fs
        .collection('courses')
        .doc(courseId)
        .get(); // one read
    if (!courseSnap.exists) {
      throw Exception('Course not found');
    }
    final meta = courseSnap.data() ?? {};
    String updatedAtIso = '';
    if (meta['updatedAt'] is Timestamp) {
      updatedAtIso = (meta['updatedAt'] as Timestamp)
          .toDate()
          .toIso8601String();
    } else if (meta['version'] != null) {
      updatedAtIso = meta['version'].toString();
    }

    // fetch sessions collection
    final sessionsSnap = await _fs
        .collection('courses')
        .doc(courseId)
        .collection('sessions')
        .orderBy('order', descending: false)
        .get(); // one read + N documents in this read (counts as reads for each doc initially)
    final sessions = sessionsSnap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = d.id;
      return m;
    }).toList();

    final payload = {
      'meta': meta,
      'sessions': sessions,
      'updatedAt': updatedAtIso,
    };

    // write to cache
    await writeCache(courseId, payload);

    return payload;
  }

  /// High level: returns cached payload (if exists) and also ensures we refresh from server
  /// only when remote updatedAt/version is newer than local. Caller can await this or not.
  Future<Map<String, dynamic>?> loadCachedThenMaybeRefresh(
    String courseId,
  ) async {
    final local = await readCache(courseId);
    try {
      // Get remote small doc
      final docRef = _fs.collection('courses').doc(courseId);
      final snap = await docRef.get();
      if (!snap.exists) {
        // fallback: return local if exists
        return local;
      }
      final data = snap.data()!;
      final remoteTs = data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null;
      final remoteVersion = data['version']; // int?

      // Compare with local.updatedAt (which we stored as ISO or version string)
      if (local != null) {
        final localUpdated = local['updatedAt'] as String?;
        bool needFetch = false;
        if (remoteTs != null && localUpdated != null) {
          final localDt = DateTime.tryParse(localUpdated);
          if (localDt == null || remoteTs.isAfter(localDt)) needFetch = true;
        } else if (remoteVersion != null && localUpdated != null) {
          // localUpdated stored version string
          final lv = int.tryParse(localUpdated) ?? -1;
          if (remoteVersion is int && remoteVersion > lv) needFetch = true;
        } else {
          // fallback: if local exists but we can't compare, avoid fetching to save reads
          needFetch = false;
        }

        if (needFetch) {
          final payload = await fetchFullCourseAndSessions(courseId);
          return payload;
        } else {
          // no update needed
          return local;
        }
      } else {
        // no local cache -> fetch full
        final payload = await fetchFullCourseAndSessions(courseId);
        return payload;
      }
    } catch (e) {
      // On any error, return local (may be null)
      return local;
    }
  }
}
