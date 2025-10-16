// lib/utils/auth_router.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Robust navigateAfterSignIn:
/// - Accepts optional [user], falls back to FirebaseAuth.instance.currentUser
/// - Ensures user doc exists / updates lastLogin
/// - Routes to onboarding / baseline / safety / home
/// - If possible, checks custom claims for role == 'doctor' and routes to '/doctor/home'
/// - When sending user info to /home, forwards a small safe Map (never a raw User nor a List)
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
    Navigator.pushReplacementNamed(context, '/home');
    return;
  }

  Map<String, dynamic> data = snap.data() ?? {};

  // If user doc missing, create minimal one
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
        'baselineCompleted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to create minimal user doc: $e');
    }
    Navigator.pushReplacementNamed(context, '/onboarding');
    return;
  }

  // Firestore doctor role check
  final fsRole = (data['role']?.toString().toLowerCase() ?? '');
  if (fsRole == 'doctor') {
    debugPrint('→ Routing via Firestore role to doctor home');
    Navigator.pushReplacementNamed(context, '/doctor/home');
    return;
  }

  // ---------- STEP 3: Normal flow ----------
  try {
    await userDocRef.update({'lastLogin': FieldValue.serverTimestamp()});
  } catch (e) {
    debugPrint('Failed to update lastLogin: $e');
  }

  final consentGiven = data['consentGiven'] == true;
  final baselineCompleted = data['baselineCompleted'] == true;

  if (!consentGiven) {
    Navigator.pushReplacementNamed(context, '/onboarding');
    return;
  }

  if (consentGiven && !baselineCompleted) {
    Navigator.pushReplacementNamed(context, '/baseline');
    return;
  }

  final lastScore = data['lastBaselineScore'];
  if (lastScore != null) {
    final scoreNum = int.tryParse(lastScore.toString()) ?? -1;
    if (scoreNum >= 20) {
      Navigator.pushReplacementNamed(
        context,
        '/safety',
        arguments: {'reason': 'high_phq9'},
      );
      return;
    }
  }

  final safeUserMap = <String, dynamic>{
    'uid': user.uid,
    'email': user.email,
    'displayName': user.displayName,
    'photoUrl': user.photoURL,
  };

  debugPrint('→ Routing to main home (default)');
  Navigator.pushReplacementNamed(
    context,
    '/home',
    arguments: {'user': safeUserMap},
  );
}
