import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'models/intent_mode.dart';
import 'services/onboarding_preferences_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final _prefs = OnboardingPreferencesService();
  late final Future<({IntentMode intent, List<String> skills})?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _prefs.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<({IntentMode intent, List<String> skills})?>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _GateSplash();
          }

          final data = snapshot.data;
          final hasSetup = data != null && data.skills.isNotEmpty;
          if (hasSetup) {
            return HomeScreen(
              selectedSkills: data!.skills,
              intent: data.intent,
            );
          }

          return const OnboardingScreen();
        },
      ),
    );
  }
}

class _GateSplash extends StatelessWidget {
  const _GateSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: const SafeArea(
          child: Center(
            child: SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
