// lib/utils/auth_router.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Routes used in the scaffold: '/onboarding', '/baseline', '/home', '/safety'
Future<void> navigateAfterSignIn(BuildContext context, {User? user}) async {
  user ??= FirebaseAuth.instance.currentUser;
  if (user == null) {
    Navigator.pushReplacementNamed(context, '/onboarding');
    return;
  }

  final uid = user.uid;
  final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

  // Try to fetch doc; create minimal doc if missing
  DocumentSnapshot<Map<String, dynamic>> snap;
  try {
    snap = await userDocRef.get();
  } catch (e) {
    // network error — let user into home, but you may show offline banner
    Navigator.pushReplacementNamed(context, '/home');
    return;
  }

  final data = snap.data() ?? {};

  if (!snap.exists) {
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
    Navigator.pushReplacementNamed(context, '/onboarding');
    return;
  }

  // best-effort lastLogin update
  try {
    await userDocRef.update({'lastLogin': FieldValue.serverTimestamp()});
  } catch (_) {}

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

  // Optional safety check using stored lastBaselineScore
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

  Navigator.pushReplacementNamed(context, '/home');
}
