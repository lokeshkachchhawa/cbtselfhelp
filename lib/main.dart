// lib/main.dart
import 'package:cbt_drktv/relax/relax_sounds_page.dart';
import 'package:cbt_drktv/relax/grounding_54321_page.dart';
import 'package:cbt_drktv/relax/mini_meditation_timer.dart';
import 'package:cbt_drktv/relax/relax_breath_page.dart';
import 'package:cbt_drktv/relax/relax_pmr_page.dart';
import 'package:cbt_drktv/screens/abcd_worksheet.dart';
import 'package:cbt_drktv/screens/activities_page.dart';
import 'package:cbt_drktv/screens/home_page.dart';
import 'package:cbt_drktv/screens/relax_page.dart';
import 'package:cbt_drktv/screens/thought_record_page.dart';
import 'package:cbt_drktv/screens/safety_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

// Screens & utils
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/baseline_page.dart';
import 'utils/auth_router.dart';

// App theme
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

class AppState extends ChangeNotifier {
  User? user = FirebaseAuth.instance.currentUser;

  AppState() {
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CBT Self-Guided',
        theme: appTheme(), // use centralized theme
        home: const EntryRouter(),
        routes: {
          '/home': (_) => const HomePage(),
          '/onboarding': (_) => OnboardingPage(),
          '/baseline': (_) => BaselinePage(),
          '/thought': (_) => const ThoughtRecordPage(),
          '/signin': (_) => const SignInScreen(),
          '/signup': (_) => const SignUpPage(),
          '/safety': (_) => const SafetyPage(),
          '/activities': (_) => const ActivitiesPage(),
          '/abcd': (_) => const AbcdWorksheetPage(),
          '/relax': (_) => const RelaxPage(),
          '/relax/breath': (_) => const RelaxBreathPage(),
          '/relax_pmr': (_) => const RelaxPmrPage(),
          '/grounding': (_) => const RelaxGroundingPage(),
          '/minimeditation': (_) => const MiniMeditationTimer(),
          '/sounds': (_) => const RelaxSoundsPage(),
        },
      ),
    );
  }
}

class EntryRouter extends StatelessWidget {
  const EntryRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    if (app.user == null) {
      return const SignInScreen();
    }

    // Defer navigation to avoid calling Navigator during build
    Future.microtask(() async {
      await navigateAfterSignIn(context, user: app.user);
    });

    // Simple loading state while router decides destination
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
