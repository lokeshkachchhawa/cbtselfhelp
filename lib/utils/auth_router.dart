// lib/utils/auth_router.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Robust navigateAfterSignIn:
/// Now removes baseline flow. New users are routed to /paywall.
/// Existing users: doctor -> /doctor/home, active subscription -> /home, else -> /paywall.
Future<void> navigateAfterSignIn(BuildContext context, {User? user}) async {
  user ??= FirebaseAuth.instance.currentUser;

  debugPrint(
    'navigateAfterSignIn called with type: ${user?.runtimeType} uid: ${user?.uid}',
  );

  if (user == null) {
    Navigator.pushReplacementNamed(context, '/onboarding');
    return;
  }

  // ---------- STEP 1: Try custom claims ----------
  try {
    final idTokenResult = await user.getIdTokenResult(true);
    final claims = idTokenResult.claims ?? <String, dynamic>{};
    final role =
        (claims['role'] as String?) ?? (claims['customRole'] as String?);
    debugPrint('Claims: $claims');
    if (role != null && role.toLowerCase() == 'doctor') {
      debugPrint('→ Routing via CLAIMS to doctor home');
      Navigator.pushReplacementNamed(context, '/doctor/home');
      return;
    }
  } catch (e) {
    debugPrint('Failed to read id token claims: $e');
  }

  // ---------- STEP 2: Check Firestore role field ----------
  final uid = user.uid;
  final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
  DocumentSnapshot<Map<String, dynamic>> snap;

  try {
    snap = await userDocRef.get();
  } catch (e) {
    debugPrint('Firestore user doc read failed: $e');
    // If we can't read, fallback to home to avoid blocking user
    Navigator.pushReplacementNamed(context, '/home');
    return;
  }

  Map<String, dynamic> data = snap.data() ?? {};

  // If user doc missing, create minimal one and send to paywall (baseline removed)
  if (!snap.exists) {
    try {
      await userDocRef.set({
        'name': user.displayName ?? (user.email?.split('@').first ?? 'User'),
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
        'consentGiven': false,
        // baseline feature removed - but keep field if other code expects it
        'baselineCompleted': true,
        // initialize default subscription (inactive)
        'subscription': {'status': 'inactive'},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to create minimal user doc: $e');
    }

    // After signup: send to paywall
    Navigator.pushReplacementNamed(context, '/paywall');
    return;
  }

  // Firestore doctor role check (again, in case doc exists with role)
  final fsRole = (data['role']?.toString().toLowerCase() ?? '');
  if (fsRole == 'doctor') {
    debugPrint('→ Routing via Firestore role to doctor home');
    Navigator.pushReplacementNamed(context, '/doctor/home');
    return;
  }

  // ---------- STEP 3 — SUBSCRIPTION CHECK ----------
  final Map<String, dynamic> sub = (data['subscription'] is Map)
      ? Map<String, dynamic>.from(data['subscription'])
      : {};

  final String status = (sub['status'] ?? '').toString().toLowerCase();
  // allow access if active OR cancel is scheduled (access continues until period end)
  final bool allowAccess = status == 'active' || status == 'cancel_scheduled';

  if (!allowAccess) {
    debugPrint('→ Subscription not eligible (status: $status) → paywall');
    Navigator.pushReplacementNamed(context, '/paywall');
    return;
  }

  // ---------- STEP 4: Update lastLogin and route to home ----------
  try {
    await userDocRef.update({'lastLogin': FieldValue.serverTimestamp()});
  } catch (e) {
    debugPrint('Failed to update lastLogin: $e');
  }

  // Baseline/PHQ logic removed — proceed to home for eligible users
  final safeUserMap = <String, dynamic>{
    'uid': user.uid,
    'email': user.email,
    'displayName': user.displayName,
    'photoUrl': user.photoURL,
  };

  debugPrint('→ Routing to main home (default after subscription OK)');
  Navigator.pushReplacementNamed(
    context,
    '/home',
    arguments: {'user': safeUserMap},
  );
}
