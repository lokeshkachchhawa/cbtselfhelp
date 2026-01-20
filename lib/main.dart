// lib/main.dart
import 'package:cbt_drktv/screens/community_discussions_page.dart';

import 'package:cbt_drktv/programs/programs_page.dart';
import 'package:cbt_drktv/relax/relax_sounds_page.dart';
import 'package:cbt_drktv/relax/grounding_54321_page.dart';
import 'package:cbt_drktv/relax/mini_meditation_timer.dart';
import 'package:cbt_drktv/relax/relax_breath_page.dart';
import 'package:cbt_drktv/relax/relax_pmr_page.dart';
import 'package:cbt_drktv/screens/abcd_worksheet.dart';
import 'package:cbt_drktv/screens/cancel_subscription_screen.dart';
import 'package:cbt_drktv/screens/cbt_game.dart';
import 'package:cbt_drktv/screens/course_detail_page.dart';
import 'package:cbt_drktv/screens/doctor_home.dart';
import 'package:cbt_drktv/screens/drktv_chat_screen.dart';
import 'package:cbt_drktv/screens/good_moments_diary.dart';
import 'package:cbt_drktv/screens/home_page.dart';
import 'package:cbt_drktv/screens/relax_page.dart';

import 'package:cbt_drktv/screens/thought_record_page.dart';
import 'package:cbt_drktv/screens/safety_page.dart';
import 'package:cbt_drktv/services/push_service.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Screens & utils
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/baseline_page.dart';
import 'utils/auth_router.dart';
import 'screens/paywall_screen.dart'; // <-- ADD THIS

// App theme
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // DeviceOrientation.portraitDown, // अगर उल्टा भी चाहिये तो uncomment करें
  ]);
  // --- Firebase ---
  await Firebase.initializeApp();
  await PushService.init();

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
          '/minimeditation': (_) => const GuidedMeditationPlayer(),
          '/sounds': (_) => const RelaxSoundsPage(),
          '/programs': (_) => const ProgramsPage(),
          '/drktv_chat': (ctx) => const DrKtvChatScreen(),
          '/doctor/home': (ctx) => const DoctorHome(),
          '/course_detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String? courseId;

            if (args is Map && args['courseId'] is String) {
              courseId = args['courseId'] as String;
            }

            return CourseDetailPage(courseId: courseId);
          },
          '/paywall': (_) => const PaywallScreen(),
          "/cbt-game": (_) => const CBTGameScreen(),
          '/cancel': (_) => const CancelSubscriptionScreen(),
          '/community': (_) => const CommunityDiscussionsPage(),
          '/good-moments': (context) => const GoodMomentsDiaryPage(),
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
