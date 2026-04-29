import 'package:shared_preferences/shared_preferences.dart';

import '../models/intent_mode.dart';

class OnboardingPreferencesService {
  static const String _intentKey = 'onboarding_intent_mode';
  static const String _skillsKey = 'onboarding_selected_skills';

  /// Saves onboarding selections locally on-device.
  Future<void> save({
    required IntentMode intent,
    required List<String> selectedSkills,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_intentKey, intent.name);
    await prefs.setStringList(_skillsKey, selectedSkills);
  }

  Future<({IntentMode intent, List<String> skills})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final intentName = prefs.getString(_intentKey);
    final skills = prefs.getStringList(_skillsKey);

    if (intentName == null || skills == null) return null;

    final intent = IntentMode.values.firstWhere(
      (e) => e.name == intentName,
      orElse: () => IntentMode.both,
    );

    return (intent: intent, skills: skills);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_intentKey);
    await prefs.remove(_skillsKey);
  }
}

