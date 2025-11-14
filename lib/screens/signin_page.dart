// lib/screens/signin_page.dart
import 'package:cbt_drktv/config/google_oauth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/auth_router.dart';
import 'package:cbt_drktv/services/fcm_token_registry.dart';

/// Match HomePage palette
const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isResetting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool _showEmailForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: teal4));
  }

  String _friendlyFirebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset your password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method for that email.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;
    try {
      final uid = user.uid;
      final docRef = _firestore.collection('users').doc(uid);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        final derivedName =
            user.displayName ?? (user.email?.split('@').first ?? 'User');
        await docRef.set({
          'name': derivedName,
          'email': user.email,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
          'consentGiven': false,
          'baselineCompleted': false,
        }, SetOptions(merge: true));
      } else {
        await docRef.update({'lastLogin': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('ensureUserDoc failed: $e');
    }
  }

  Future<void> _postSignInNavigation(User? user) async {
    if (!mounted) return;

    await _ensureUserDoc(user);
    if (user != null) {
      await FcmTokenRegistry.registerForUser(user.uid);
    }

    if (user == null) {
      try {
        await navigateAfterSignIn(context, user: null);
        return;
      } catch (e, st) {
        debugPrint('navigateAfterSignIn(null) failed: $e\n$st');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
    }

    final uid = user.uid;
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (snap.exists) {
        final roleField = snap.data()?['role'];
        if (roleField != null &&
            roleField.toString().toLowerCase() == 'doctor') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/doctor/home');
          return;
        }
      }
    } catch (e, st) {
      debugPrint('Failed to read user doc role: $e\n$st');
    }

    try {
      await navigateAfterSignIn(context, user: user);
    } catch (e, st) {
      debugPrint('navigateAfterSignIn failed: $e\n$st');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _postSignInNavigation(cred.user ?? _auth.currentUser);
    } on FirebaseAuthException catch (e) {
      await _showError(_friendlyFirebaseMessage(e));
    } catch (e) {
      await _showError('Sign in failed: ${e.toString()}');
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
      // ✅ Web Client ID dena zaroori hai idToken ke liye
      final googleSignIn = GoogleSignIn(
        serverClientId: kGoogleWebClientId,
        scopes: const ['email'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // user cancelled
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      // Defensive check
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

      await _ensureUserDoc(user);
      if (user != null) {
        await FcmTokenRegistry.registerForUser(user.uid);
      }

      await _postSignInNavigation(user ?? _auth.currentUser);
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        'Google sign-in FirebaseAuthException: ${e.code} / ${e.message}\n$st',
      );
      await _showError(_friendlyFirebaseMessage(e));
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      await _showError('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: teal4,
        ),
      );
    } on FirebaseAuthException catch (e) {
      await _showError(_friendlyFirebaseMessage(e));
    } catch (e) {
      await _showError('Failed to send reset email: ${e.toString()}');
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final currentEmail = _emailController.text.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    String? emailToUse;
    if (currentEmail.isNotEmpty && emailRegex.hasMatch(currentEmail)) {
      emailToUse = currentEmail;
    } else {
      final tempCtrl = TextEditingController(text: currentEmail);
      final formKey = GlobalKey<FormState>();
      final result = await showDialog<String?>(
        context: context,
        builder: (dctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF021515),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text(
              'Reset password',
              style: TextStyle(color: Colors.white),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the email associated with your account.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tempCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return 'Please enter your email.';
                      if (!emailRegex.hasMatch(val))
                        return 'Enter a valid email.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dctx).pop(tempCtrl.text.trim());
                  }
                },
                child: const Text(
                  'Send',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
      emailToUse = result;
    }

    if (emailToUse == null || emailToUse.isEmpty) return;

    setState(() {
      _isResetting = true;
      _errorMessage = null;
    });

    try {
      await _sendPasswordResetEmail(emailToUse);
      if (mounted) _passwordController.clear();
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  void _navigateToSignup() {
    if (!mounted) return;
    Navigator.of(context).pushNamed('/signup');
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
    // Dark-inputs to match HomePage
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
      // ----- Gradient background (same vibe as HomePage) -----
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
                      // ---------------- Header / Branding ----------------
                      Column(
                        children: [
                          // Rounded logo with white glowing border
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
                          const SizedBox(height: 4),
                          Text(
                            'Self-help CBT tools',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ---------------- Google Sign-in ----------------
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  shadowColor: teal3.withOpacity(0.5),
                                ),
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Image.asset(
                                    'images/google_logo.png',
                                    width: 20,
                                    height: 20,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.login,
                                              size: 20,
                                              color: teal6,
                                            ),
                                  ),
                                ),
                                label: const Text(
                                  'Continue with Google',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      // --------------- Divider "or" ----------------
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

                      // ----------- Toggle email form (Outlined) -----------
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
                                ? 'Hide email sign-in'
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

                      // --------------- Animated email form ---------------
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
                                        if (v.isEmpty)
                                          return 'Please enter your email.';
                                        final emailRegex = RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        );
                                        if (!emailRegex.hasMatch(v))
                                          return 'Enter a valid email.';
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
                                      textInputAction: TextInputAction.done,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password.';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters.';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) =>
                                          _signInWithEmail(),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _isResetting
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : TextButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _forgotPassword,
                                                child: const Text(
                                                  'Forgot password?',
                                                ),
                                              ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _signInWithEmail,
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
                                        child: const Text('Sign in with email'),
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

                      const SizedBox(height: 16),

                      // ------------------- Signup link -------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _navigateToSignup,
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
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
