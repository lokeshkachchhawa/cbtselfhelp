// lib/screens/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/auth_router.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    namePart = namePart.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '');
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

      try {
        await user.sendEmailVerification();
      } catch (_) {}

      if (!mounted) return;
      await navigateAfterSignIn(context, user: user);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyAuthMessage(e));
    } on FirebaseException catch (e) {
      if (mounted)
        setState(() => _errorMessage = e.message ?? 'Database error: $e');
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return; // cancelled
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) throw Exception('Google sign-in failed.');

      // write user doc
      await _createOrUpdateFirestoreUser(user);

      if (!mounted) return;
      await navigateAfterSignIn(context, user: user);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyAuthMessage(e));
    } catch (e) {
      if (mounted)
        setState(
          () => _errorMessage = 'Google sign-in failed: ${e.toString()}',
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignIn() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/signin');
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: Colors.teal.shade700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.teal.shade700),
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'images/logo1.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.self_improvement,
                        size: 96,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CBT Self-Guided',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your account',
                      style: TextStyle(fontSize: 14, color: Colors.teal),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.login,
                                        size: 20,
                                        color: Colors.teal,
                                      ),
                                ),
                              ),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        SizedBox(width: 8),
                        Text(
                          'or sign up with email',
                          style: TextStyle(color: Colors.black54),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  prefixIcon: const Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
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
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Please enter a password.';
                                  if (value.length < 6)
                                    return 'Password must be at least 6 characters.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Please confirm your password.';
                                  if (value != _passwordController.text)
                                    return 'Passwords do not match.';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: BorderSide(
                                      color: Colors.teal.shade200,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign up with email',
                                    style: TextStyle(
                                      color: Colors.teal.shade800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.black54),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _goToSignIn,
                          child: const Text(
                            'Log In',
                            style: TextStyle(color: Colors.teal),
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
    );
  }
}
