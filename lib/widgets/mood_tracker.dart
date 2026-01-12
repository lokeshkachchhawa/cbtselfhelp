// lib/services/mood_tracker.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a single mood record.
class MoodRecord {
  final int score;
  final DateTime createdAt; // stored as UTC
  MoodRecord({required this.score, required this.createdAt});
}

/// Model for a day's mood summary (for display).
class DayMood {
  final DateTime date; // local date for display
  final int? score;
  final DateTime? createdAt; // original timestamp (if any)
  DayMood({required this.date, required this.score, this.createdAt});
}

/// Service for managing local mood tracking.
class MoodTracker {
  static const String _localMoodKey = 'local_mood_logs';

  /// Saves a mood score locally, appending to the log (keeps up to 365 recent entries).
  static Future<void> saveMood(int score, {DateTime? createdAt}) async {
    final now = createdAt ?? DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localMoodKey) ?? <String>[];
    final entry = {'score': score, 'createdAt': now.toIso8601String()};
    raw.add(json.encode(entry));
    // Keep recent N entries
    const int maxEntries = 365;
    final keep = raw.length <= maxEntries
        ? raw
        : raw.sublist(raw.length - maxEntries);
    await prefs.setStringList(_localMoodKey, keep);
  }

  /// Retrieves all local mood records as [MoodRecord] instances.
  static Future<List<MoodRecord>> getLocalMoodRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localMoodKey) ?? <String>[];
    final out = <MoodRecord>[];
    for (final s in raw) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        final score = int.tryParse(m['score']?.toString() ?? '');
        final iso = m['createdAt']?.toString();
        if (score != null && iso != null) {
          final dt = DateTime.parse(iso).toUtc();
          out.add(MoodRecord(score: score, createdAt: dt));
        }
      } catch (_) {
        // ignore malformed entry
      }
    }
    return out;
  }

  /// Computes the average mood score from the latest entry per day over the last 7 days.
  static Future<double?> calculateAverageMoodLast7Days() async {
    final recs = await getLocalMoodRecords();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final filtered = recs
        .where((r) => !r.createdAt.isBefore(start.toUtc()))
        .toList();
    // pick latest per day, then average those scores
    final Map<String, MoodRecord> latestPerDay = {};
    for (final r in filtered) {
      final dtLocal = r.createdAt.toLocal();
      final key =
          '${dtLocal.year}-${dtLocal.month.toString().padLeft(2, '0')}-${dtLocal.day.toString().padLeft(2, '0')}';
      final existing = latestPerDay[key];
      if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
        latestPerDay[key] = r;
      }
    }
    final scores = latestPerDay.values.map((e) => e.score).toList();
    if (scores.isNotEmpty) {
      return scores.reduce((a, b) => a + b) / scores.length;
    }
    return null;
  }

  /// Gets a summary of mood for the last 7 calendar days (oldest first).
  static Future<List<DayMood>> getLast7Days() async {
    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6)); // 7 days inclusive
    // load local entries and compute latest per calendar day
    final local = await getLocalMoodRecords();
    // Map dateKey -> latest record for that date (by createdAt)
    final Map<String, MoodRecord> latestPerDay = {};
    for (final r in local) {
      if (r.createdAt.isBefore(startDate.toUtc())) continue;
      final dtLocal = r.createdAt.toLocal();
      final key =
          '${dtLocal.year}-${dtLocal.month.toString().padLeft(2, '0')}-${dtLocal.day.toString().padLeft(2, '0')}';
      final existing = latestPerDay[key];
      if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
        latestPerDay[key] = r;
      }
    }
    // Build ordered list for display (oldest -> newest)
    final List<DayMood> days = [];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final rec = latestPerDay[key];
      days.add(DayMood(date: d, score: rec?.score, createdAt: rec?.createdAt));
    }
    return days;
  }

  /// Human-readable label for a mood score (0-10).
  static String moodLabel(int m) {
    if (m <= 2) return 'Low';
    if (m <= 4) return 'Down';
    if (m <= 6) return 'Okay';
    if (m <= 8) return 'Good';
    return 'Great';
  }

  /// Formats a date as a short label (e.g., "Mon 6 Oct").
  static String formatDateLabel(DateTime d) {
    const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = wk[(d.weekday - 1) % 7];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[d.month - 1];
    return '$weekday ${d.day} $monthName';
  }

  /// Formats a time as "HH:MM".
  static String formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
