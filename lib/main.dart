// lib/main.dart
import 'package:cbt_drktv/programs/programs_page.dart';
import 'package:cbt_drktv/relax/relax_sounds_page.dart';
import 'package:cbt_drktv/relax/grounding_54321_page.dart';
import 'package:cbt_drktv/relax/mini_meditation_timer.dart';
import 'package:cbt_drktv/relax/relax_breath_page.dart';
import 'package:cbt_drktv/relax/relax_pmr_page.dart';
import 'package:cbt_drktv/screens/abcd_worksheet.dart';
import 'package:cbt_drktv/screens/doctor_home.dart';
import 'package:cbt_drktv/screens/drktv_chat_screen.dart';
import 'package:cbt_drktv/screens/home_page.dart';
import 'package:cbt_drktv/screens/relax_page.dart';
import 'package:cbt_drktv/screens/thought_detective_game.dart';
import 'package:cbt_drktv/screens/thought_record_page.dart';
import 'package:cbt_drktv/screens/safety_page.dart';
import 'package:cbt_drktv/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Screens & utils
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/baseline_page.dart';
import 'utils/auth_router.dart';
import 'screens/paywall_screen.dart'; // <-- ADD THIS

// App theme
import 'theme.dart';

// Notifications / timezone
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- dotenv (optional) ---
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('dotenv loaded from project root');
  } catch (e) {
    debugPrint('dotenv root load failed: $e — trying assets/.env');
    try {
      await dotenv.load(fileName: 'assets/.env');
      debugPrint('dotenv loaded from assets/.env');
    } catch (e2) {
      debugPrint('dotenv load from assets failed: $e2');
    }
  }

  // --- Firebase ---
  await Firebase.initializeApp();
  await PushService.init();

  // --- Timezone init ---
  tz.initializeTimeZones();
  final local = tz.local;
  tz.setLocalLocation(local);
  debugPrint('Local timezone: ${local.name}');

  runApp(const MyApp());
}

// --- AppState ---
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

// --- MyApp ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CBT Self-Guided',
        theme: appTheme(),
        home: const EntryRouter(),
        routes: {
          '/home': (_) => const HomePage(),
          '/onboarding': (_) => OnboardingPage(),
          '/baseline': (_) => BaselinePage(),
          '/thought': (_) => const ThoughtRecordPage(),
          '/signin': (_) => const SignInScreen(),
          '/signup': (_) => const SignUpPage(),
          '/safety': (_) => const SafetyPage(),
          '/abcd': (_) => const ABCDEWorksheetPage(),
          '/relax': (_) => const RelaxPage(),
          '/relax/breath': (_) => const RelaxBreathPage(),
          '/relax_pmr': (_) => const RelaxPmrPage(),
          '/grounding': (_) => const RelaxGroundingPage(),
          '/minimeditation': (_) => const MiniMeditationTimer(),
          '/sounds': (_) => const RelaxSoundsPage(),
          '/programs': (_) => const ProgramsPage(),
          '/drktv_chat': (ctx) => const DrKtvChatScreen(),
          '/doctor/home': (ctx) => const DoctorHome(),
          '/thought_game': (context) => const ThoughtDetectiveGame(),
          '/paywall': (_) => const PaywallScreen(), // <-- ADD THIS
        },
      ),
    );
  }
}

// --- EntryRouter ---
class EntryRouter extends StatelessWidget {
  const EntryRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    if (app.user == null) {
      return const SignInScreen();
    }

    // Defer to subscription-aware router you updated
    Future.microtask(() async {
      await navigateAfterSignIn(context, user: app.user);
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
