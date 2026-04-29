import 'package:shared_preferences/shared_preferences.dart';
import '../models/intent_mode.dart';

class OnboardingPreferencesService {
  static const String _intentKey = 'onboarding_intent_mode';
  static const String _learnKey = 'onboarding_skills_to_learn';
  static const String _teachKey = 'onboarding_skills_to_teach';
  // Legacy key kept for reading old installs
  static const String _legacySkillsKey = 'onboarding_selected_skills';

  Future<void> saveSkills({
    required IntentMode intent,
    required List<String> skillsToLearn,
    required List<String> skillsToTeach,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_intentKey, intent.name);
    await prefs.setStringList(_learnKey, skillsToLearn);
    await prefs.setStringList(_teachKey, skillsToTeach);
  }

  /// Legacy save — delegates to saveSkills with mirrored lists.
  Future<void> save({
    required IntentMode intent,
    required List<String> selectedSkills,
  }) async {
    await saveSkills(
      intent: intent,
      skillsToLearn: selectedSkills,
      skillsToTeach: selectedSkills,
    );
  }

  Future<({IntentMode intent, List<String> skillsToLearn, List<String> skillsToTeach})?> loadSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final intentName = prefs.getString(_intentKey);
    if (intentName == null) return null;

    final intent = IntentMode.values.firstWhere(
      (e) => e.name == intentName,
      orElse: () => IntentMode.both,
    );

    // Prefer new keys; fall back to legacy
    final learn = prefs.getStringList(_learnKey) ?? prefs.getStringList(_legacySkillsKey) ?? [];
    final teach = prefs.getStringList(_teachKey) ?? prefs.getStringList(_legacySkillsKey) ?? [];

    return (intent: intent, skillsToLearn: learn, skillsToTeach: teach);
  }

  /// Legacy load — used by parts of app that only need a flat skills list.
  Future<({IntentMode intent, List<String> skills})?> load() async {
    final result = await loadSkills();
    if (result == null) return null;
    final allSkills = {...result.skillsToLearn, ...result.skillsToTeach}.toList();
    return (intent: result.intent, skills: allSkills);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_intentKey);
    await prefs.remove(_learnKey);
    await prefs.remove(_teachKey);
    await prefs.remove(_legacySkillsKey);
  }
}
