// lib/screens/signin_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/auth_router.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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

  // --- NEW: Register/save FCM token for this user (Android/iOS only) ---
  Future<void> _registerFcmToken(User user) async {
    try {
      if (kIsWeb) return; // skip web
      // Request permission (Android 13+/iOS) – safe on older versions too.
      await FirebaseMessaging.instance.requestPermission();

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platformStr = Theme.of(context).platform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens.$token': {
          'platform': platformStr,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      // Also keep future refreshes in sync (app lifetime)
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _firestore.collection('users').doc(user.uid).set({
          'fcmTokens.$t': {
            'platform': platformStr,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
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

  /// Post-sign-in navigation.
  /// - If user doc has role == 'doctor' -> /doctor/home
  /// - Otherwise call shared navigateAfterSignIn(context, user: user)
  Future<void> _postSignInNavigation(User? user) async {
    if (!mounted) return;

    // Ensure basic user doc exists / update lastLogin
    await _ensureUserDoc(user);

    // NEW: register FCM token ASAP after sign-in
    if (user != null) {
      await _registerFcmToken(user);
    }

    // If we don't have a firebase user for some reason, delegate to shared router
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
      // Read the user's Firestore document to look for role field
      final docRef = _firestore.collection('users').doc(uid);
      final snap = await docRef.get();

      if (snap.exists) {
        final data = snap.data() ?? <String, dynamic>{};
        final roleField = data['role'];
        if (roleField != null) {
          final role = roleField is String ? roleField : roleField.toString();
          debugPrint('User $uid role from Firestore: $role');
          // route doctor explicitly if role indicates doctor
          if (role.toLowerCase() == 'doctor') {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/doctor/home');
            return;
          }
        }
      } else {
        debugPrint(
          'User doc for $uid does not exist (unexpected at this point).',
        );
      }
    } catch (e, st) {
      debugPrint('Failed to read user doc role: $e\n$st');
      // We'll fall through to the shared router if reading role fails
    }

    // Default: use shared router which contains onboarding/baseline logic
    try {
      await navigateAfterSignIn(context, user: user);
    } catch (e, st) {
      debugPrint(
        'navigateAfterSignIn failed when called with Firebase User: $e\n$st',
      );
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return; // user cancelled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      // best-effort: update firestore / profile if missing
      await _ensureUserDoc(user);

      // NEW: register token before we route away
      if (user != null) {
        await _registerFcmToken(user);
      }

      await _postSignInNavigation(user ?? _auth.currentUser);
    } on FirebaseAuthException catch (e) {
      await _showError(_friendlyFirebaseMessage(e));
    } catch (e) {
      await _showError('Google sign-in failed: ${e.toString()}');
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
          backgroundColor: Colors.teal.shade700,
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
            title: const Text('Reset password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the email associated with your account.'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tempCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate())
                    Navigator.of(dctx).pop(tempCtrl.text.trim());
                },
                child: const Text('Send'),
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
                    Column(
                      children: [
                        Image.asset(
                          'images/logo1.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
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
                        const SizedBox(height: 4),
                        const Text(
                          'Self-help CBT tools',
                          style: TextStyle(fontSize: 14, color: Colors.teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

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
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
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
                          'or sign in with email',
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
                                focusNode: _emailFocus,
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
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
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
                                textInputAction: TextInputAction.done,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Please enter your password.';
                                  if (value.length < 6)
                                    return 'Password must be at least 6 characters.';
                                  return null;
                                },
                                onFieldSubmitted: (_) => _signInWithEmail(),
                              ),

                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _isResetting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _forgotPassword,
                                          child: const Text('Forgot password?'),
                                        ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _signInWithEmail,
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
                                    'Sign in with email',
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

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.black54),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _navigateToSignup,
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: Colors.teal),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
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
    );
  }
}
