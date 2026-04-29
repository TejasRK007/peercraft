import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/skill_selection_screen.dart';
import 'services/onboarding_preferences_service.dart';
import 'models/intent_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const PeerCraftApp());
}

class PeerCraftApp extends StatefulWidget {
  const PeerCraftApp({super.key});

  @override
  State<PeerCraftApp> createState() => _PeerCraftAppState();
}

class _PeerCraftAppState extends State<PeerCraftApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundWhite,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            ),
          );
        }

        final user = snapshot.data;
        // User is not logged in
        if (user == null) {
          return const OnboardingScreen();
        }

        // User is logged in, check if they have completed skill setup
        return FutureBuilder<({IntentMode intent, List<String> skills})?>(
          future: OnboardingPreferencesService().load(),
          builder: (context, prefSnapshot) {
            if (prefSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.backgroundWhite,
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                ),
              );
            }

            final data = prefSnapshot.data;
            // If local data isn't found, send them to setup their skills
            if (data == null || data.skills.isEmpty) {
              return const SkillSelectionScreen(intent: IntentMode.learn);
            }

            // Fully setup, go to home screen
            return HomeScreen(
              intent: data.intent,
              selectedSkills: data.skills,
            );
          },
        );
      },
    );
  }
}
