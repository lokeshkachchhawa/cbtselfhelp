// lib/screens/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  Future<void> _acceptConsent(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      try {
        await docRef.set({
          'consentGiven': true,
          'consentGivenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        // ignore write error (but you may show a toast)
      }
    }
    // Navigate to baseline assessment screen
    Navigator.pushReplacementNamed(context, '/baseline');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'This app provides CBT self-help tools and is not a substitute for professional care.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Please confirm you understand:'),
            const SizedBox(height: 8),
            const Text(
              '• This app is educational and self-guided.\n• If you are in crisis, use the Get Help button.',
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _acceptConsent(context),
              child: const Text('I understand & agree'),
            ),
            TextButton(
              onPressed: () {
                // allow anonymous/demo path if you support it
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Use app without consenting (limited)'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
