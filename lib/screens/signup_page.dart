// lib/screens/signup_page.dart
import 'dart:io' show Platform;

import 'package:cbt_drktv/config/google_oauth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/auth_router.dart';
import 'package:cbt_drktv/services/fcm_token_registry.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Match Home/Sign-In palette
const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes for smooth flow
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // Expand/collapse email form
  bool _showEmailForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is malformed.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account exists with a different sign-in method for that email.';
      default:
        return e.message ?? 'Sign up failed. Please try again.';
    }
  }

  String _extractNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final parts = email.split('@');
    if (parts.isEmpty || parts[0].isEmpty) return 'User';
    var namePart = parts[0];
    if (namePart.contains('+')) namePart = namePart.split('+').first;
    namePart = namePart.replaceAll(RegExp(r'[^a-zA-Z0-9._\\-]'), '');
    if (namePart.isEmpty) return 'User';
    final normalized = namePart.toLowerCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Future<void> _createOrUpdateFirestoreUser(User user) async {
    if (user.uid.isEmpty) return;
    final docRef = _firestore.collection('users').doc(user.uid);

    final data = <String, dynamic>{
      'name': user.displayName ?? _extractNameFromEmail(user.email),
      'email': user.email,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'isAnonymous': user.isAnonymous,
      'consentGiven': false,
      'baselineCompleted': false,
    };

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null) throw Exception('User creation failed unexpectedly.');

      final derivedName = _extractNameFromEmail(user.email);
      try {
        await user.updateDisplayName(derivedName);
        await user.reload();
      } catch (e) {
        debugPrint('updateDisplayName failed: $e');
      }

      await _createOrUpdateFirestoreUser(user);
      await FcmTokenRegistry.registerForUser(user.uid);

      try {
        await user.sendEmailVerification();
      } catch (_) {}

      if (!mounted) return;
      await navigateAfterSignIn(context, user: user);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyAuthMessage(e));
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message ?? 'Database error: $e');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: kGoogleWebClientId,
        scopes: const ['email'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return; // cancelled
      }

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          'Google auth tokens null (idToken/accessToken). '
          'Web Client ID / SHA fingerprints check karein.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) throw Exception('Google sign-in failed.');

      await _createOrUpdateFirestoreUser(user);
      await FcmTokenRegistry.registerForUser(user.uid);

      if (!mounted) return;
      await navigateAfterSignIn(context, user: user);
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        'Google sign-in FirebaseAuthException: ${e.code} / ${e.message}\n$st',
      );
      if (mounted) setState(() => _errorMessage = _friendlyAuthMessage(e));
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      if (mounted) setState(() => _errorMessage = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCred = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(oauthCred);
      var user = userCred.user;
      if (user == null) throw Exception('Apple sign-in failed.');

      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((p) => p != null && p.trim().isNotEmpty).join(' ');

      if (fullName.isNotEmpty &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        try {
          await user.updateDisplayName(fullName);
          await user.reload();
          user = _auth.currentUser;
        } catch (e) {
          debugPrint('updateDisplayName (Apple signup) failed: $e');
        }
      }

      await _createOrUpdateFirestoreUser(user!);
      await FcmTokenRegistry.registerForUser(user.uid);

      if (!mounted) return;
      await navigateAfterSignIn(context, user: user);
    } on SignInWithAppleAuthorizationException catch (e, st) {
      debugPrint('Apple sign-in auth exception: $e\n$st');
      if (e.code == AuthorizationErrorCode.canceled) {
        // user cancelled
      } else {
        if (mounted) {
          setState(() => _errorMessage = 'Apple sign-in failed: ${e.message}');
        }
      }
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        'Apple sign-in FirebaseAuthException: ${e.code} / ${e.message}\n$st',
      );
      if (mounted) setState(() => _errorMessage = _friendlyAuthMessage(e));
    } catch (e, st) {
      debugPrint('Apple sign-in failed: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = 'Apple sign-in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignIn() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/signin');
  }

  Future<void> _toggleEmailForm() async {
    setState(() => _showEmailForm = !_showEmailForm);
    if (_showEmailForm) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (mounted) _emailFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dark inputs to match gradient theme
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white60),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: teal2, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              teal1,
              Color.fromARGB(255, 3, 3, 3),
              Color.fromARGB(255, 9, 36, 29),
              teal4,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --------- Header / Branding (glowing logo) ---------
                      Column(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.85),
                                  blurRadius: 22,
                                  spreadRadius: 1.2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'images/logo1.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.self_improvement,
                                    size: 96,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'CBT Self-Guided',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create your account',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          "Sign Up with",
                          style: TextStyle(
                            color: const Color.fromARGB(
                              255,
                              255,
                              226,
                              3,
                            ).withOpacity(0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ---------------- Google + Apple row ----------------
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 52,
                                      child: OutlinedButton(
                                        onPressed: _signInWithGoogle,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.06),
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Image.asset(
                                          'images/google_logo.png',
                                          width: 22,
                                          height: 22,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.login,
                                                    size: 22,
                                                    color: Colors.white,
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (Platform.isIOS) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: _signInWithApple,
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withOpacity(0.06),
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(
                                                0.25,
                                              ),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.apple,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),

                      const SizedBox(height: 12),

                      // ---------------- Divider "or" ----------------
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'or',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ---------- Toggle email form (Outlined) ----------
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _toggleEmailForm,
                          icon: Icon(
                            _showEmailForm
                                ? Icons.keyboard_arrow_up
                                : Icons.email_outlined,
                            color: Colors.white,
                          ),
                          label: Text(
                            _showEmailForm
                                ? 'Hide email sign-up'
                                : 'Continue with Email',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // ------------- Animated email form -------------
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Card(
                            color: Colors.white.withOpacity(0.06),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      decoration: inputDecoration.copyWith(
                                        labelText: 'Email',
                                        hintText: 'you@example.com',
                                        prefixIcon: const Icon(
                                          Icons.email,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'Please enter your email.';
                                        }
                                        final emailRegex = RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        );
                                        if (!emailRegex.hasMatch(v)) {
                                          return 'Enter a valid email.';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      decoration: inputDecoration.copyWith(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock,
                                          color: Colors.white70,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: Colors.white70,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a password.';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters.';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) =>
                                          _confirmFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      focusNode: _confirmFocus,
                                      decoration: inputDecoration.copyWith(
                                        labelText: 'Confirm Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: Colors.white70,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirm
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: Colors.white70,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      obscureText: _obscureConfirm,
                                      textInputAction: TextInputAction.done,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please confirm your password.';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Passwords do not match.';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _signUp(),
                                    ),

                                    const SizedBox(height: 14),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _signUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: teal3,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Sign up with email'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        crossFadeState: _showEmailForm
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                      ),

                      const SizedBox(height: 12),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _goToSignIn,
                            child: const Text(
                              'Log In',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
