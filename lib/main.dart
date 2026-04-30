import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/skill_selection_screen.dart';
import 'services/onboarding_preferences_service.dart';
import 'services/firestore_service.dart';
import 'services/agora_chat_service.dart';
import 'models/intent_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Agora Chat SDK once at startup
  await AgoraChatService.instance.init();

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
          // Ensure chat is logged out when Firebase signs out
          AgoraChatService.instance.logout();
          return const OnboardingScreen();
        }

        // Login to Agora Chat whenever a Firebase user is detected
        AgoraChatService.instance.loginCurrentUser();

        // User is logged in, check if they have completed skill setup
        return FutureBuilder(
          future: () async {
            var data = await OnboardingPreferencesService().loadSkills();
            if (data == null || (data.skillsToLearn.isEmpty && data.skillsToTeach.isEmpty)) {
              // Check Firestore
              final profile = await FirestoreService.loadUserProfile();
              if (profile != null) {
                final intentStr = profile['intent'] as String? ?? 'both';
                final intent = IntentMode.values.firstWhere((e) => e.name == intentStr, orElse: () => IntentMode.both);
                final lSkills = List<String>.from(profile['skillsToLearn'] ?? []);
                final tSkills = List<String>.from(profile['skillsToTeach'] ?? []);
                
                if (lSkills.isNotEmpty || tSkills.isNotEmpty) {
                  // Sync to local preferences
                  await OnboardingPreferencesService().saveSkills(
                    intent: intent,
                    skillsToLearn: lSkills,
                    skillsToTeach: tSkills,
                  );
                  data = (intent: intent, skillsToLearn: lSkills, skillsToTeach: tSkills);
                }
              }
            }
            return data;
          }(),
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
            // If data is still null, brand new user, send to setup
            if (data == null || (data.skillsToLearn.isEmpty && data.skillsToTeach.isEmpty)) {
              return const SkillSelectionScreen(intent: IntentMode.both);
            }

            final allSkills = {...data.skillsToLearn, ...data.skillsToTeach}.toList();
            // Fully setup, go to home screen
            return HomeScreen(
              intent: data.intent,
              selectedSkills: allSkills,
              skillsToLearn: data.skillsToLearn,
              skillsToTeach: data.skillsToTeach,
            );
          },
        );
      },
    );
  }
}
