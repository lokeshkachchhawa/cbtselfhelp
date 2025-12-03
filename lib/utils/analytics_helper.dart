// lib/utils/analytics_helper.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global RouteObserver for screen open/close tracking
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// ----------------------------
/// 1) Simple feature-use tracker
/// ----------------------------
Future<void> trackFeatureUse(String featureKey) async {
  // 🔹 1. Store locally (to use later if you want batch sync)
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_feature_usage') ?? '{}';
    final Map<String, dynamic> map = jsonDecode(raw) is Map
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : <String, dynamic>{};

    final current = (map[featureKey] as int?) ?? 0;
    map[featureKey] = current + 1;
    await prefs.setString('local_feature_usage', jsonEncode(map));
  } catch (_) {
    // ignore local errors
  }

  // 🔹 2. Firestore event (simple, one document per tap)
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    await FirebaseFirestore.instance.collection('feature_events').add({
      'uid': uid,
      'featureKey': featureKey,
      'ts': FieldValue.serverTimestamp(),
      'platform': 'android', // or 'ios' / 'web' if needed
    });
  } catch (e) {
    // optional: print, but don't break UX
    debugPrint('trackFeatureUse error for $featureKey: $e');
  }
}

/// --------------------------------------
/// 2) Navigation helper with auto tracking
/// --------------------------------------
/// Usage:
///   navigateWithTracking(
///     context,
///     featureKey: 'feature_thought_record',
///     routeName: '/thought',
///   );
Future<void> navigateWithTracking(
  BuildContext context, {
  required String featureKey,
  required String routeName,
  Object? arguments,
}) async {
  await trackFeatureUse(featureKey);
  // normal navigation
  await Navigator.pushNamed(context, routeName, arguments: arguments);
}

/// ----------------------------------------------------
/// 3) Optional: sync local analytics to Firestore (daily)
/// ----------------------------------------------------
Future<void> syncLocalAnalyticsOncePerDay() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('analytics_last_sync');
    final now = DateTime.now();

    if (lastSyncStr != null) {
      final last = DateTime.tryParse(lastSyncStr);
      // already synced in last 24h -> skip
      if (last != null && now.difference(last) < const Duration(hours: 24)) {
        return;
      }
    }

    final raw = prefs.getString('local_feature_usage') ?? '{}';
    final Map<String, dynamic> map = jsonDecode(raw) is Map
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : <String, dynamic>{};

    if (map.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    await FirebaseFirestore.instance.collection('analytics_batch').add({
      'uid': uid,
      'data': map, // {featureKey: count}
      'syncedAt': FieldValue.serverTimestamp(),
    });

    await prefs.setString('analytics_last_sync', now.toIso8601String());
    await prefs.setString('local_feature_usage', '{}'); // reset
  } catch (e) {
    debugPrint('syncLocalAnalyticsOncePerDay error: $e');
  }
}

/// ------------------------------------------------------
/// 4) Route-aware helper to measure time spent on screens
/// ------------------------------------------------------
/// Example use:
///   class _ThoughtPageState extends State<ThoughtPage> with RouteAware {
///     late final TrackingRouteAware _tracker;
///
///     @override
///     void initState() {
///       super.initState();
///       _tracker = TrackingRouteAware('screen_thought');
///     }
///
///     @override
///     void didChangeDependencies() {
///       super.didChangeDependencies();
///       final route = ModalRoute.of(context);
///       if (route is PageRoute) {
///         routeObserver.subscribe(_tracker, route);
///       }
///     }
///
///     @override
///     void dispose() {
///       routeObserver.unsubscribe(_tracker);
///       super.dispose();
///     }
///   }
class TrackingRouteAware extends RouteAware {
  final String featureKey; // e.g. 'screen_thought', 'screen_relax'
  DateTime? _enteredAt;

  TrackingRouteAware(this.featureKey);

  @override
  void didPush() {
    _enteredAt = DateTime.now();
    trackFeatureUse('${featureKey}_open');
  }

  @override
  void didPop() {
    _logDuration();
  }

  @override
  void didPushNext() {
    // another page pushed above -> treat like leaving
    _logDuration();
  }

  @override
  void didPopNext() {
    // returning to this page
    _enteredAt = DateTime.now();
    trackFeatureUse('${featureKey}_resume');
  }

  void _logDuration() {
    if (_enteredAt == null) return;
    final diff = DateTime.now().difference(_enteredAt!);
    final seconds = diff.inSeconds.clamp(0, 3600); // cap at 1 hour per session

    trackFeatureUse('${featureKey}_seconds_$seconds');
    _enteredAt = null;
  }
}
