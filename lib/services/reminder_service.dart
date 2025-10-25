import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();
const _kRemindersKey = 'reminders_v1';

enum ReminderRecurrence { none, daily, weekly, weekdays } // extend as needed

class Reminder {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledAt; // local time
  final ReminderRecurrence recurrence;
  final bool enabled;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.recurrence = ReminderRecurrence.none,
    this.enabled = true,
  });

  Reminder copyWith({
    String? title,
    String? body,
    DateTime? scheduledAt,
    ReminderRecurrence? recurrence,
    bool? enabled,
  }) => Reminder(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    recurrence: recurrence ?? this.recurrence,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'scheduledAt': scheduledAt.toIso8601String(),
    'recurrence': recurrence.index,
    'enabled': enabled,
  };

  static Reminder fromMap(Map<String, dynamic> m) => Reminder(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    scheduledAt: DateTime.parse(m['scheduledAt'] as String).toLocal(),
    recurrence: ReminderRecurrence.values[(m['recurrence'] as int?) ?? 0],
    enabled: m['enabled'] as bool? ?? true,
  );

  static Reminder create({
    required String title,
    required String body,
    required DateTime scheduledAt,
    ReminderRecurrence recurrence = ReminderRecurrence.none,
    required String id,
  }) => Reminder(
    id: _uuid.v4(),
    title: title,
    body: body,
    scheduledAt: scheduledAt,
    recurrence: recurrence,
    enabled: true,
  );
}

class ReminderStorage {
  Future<List<Reminder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRemindersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => Reminder.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<Reminder> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRemindersKey,
      json.encode(items.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> add(Reminder r) async {
    final all = await loadAll();
    all.add(r);
    await saveAll(all);
  }

  Future<void> update(Reminder r) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      all[idx] = r;
      await saveAll(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }
}
