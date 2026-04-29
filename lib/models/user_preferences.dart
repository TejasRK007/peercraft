import 'package:flutter/foundation.dart';
import 'intent_mode.dart';

enum SkillLevel {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  final String label;
  const SkillLevel(this.label);
}

enum SessionType {
  oneOnOne('1:1'),
  group('Group');

  final String label;
  const SessionType(this.label);
}

enum LearningStyle {
  practical('Practical'),
  theory('Theory'),
  mixed('Mixed');

  final String label;
  const LearningStyle(this.label);
}

@immutable
class SkillSetupData {
  final IntentMode intent;
  final List<String> skillsToTeach;
  final List<String> skillsToLearn;
  final SkillLevel? teachLevel;
  final SkillLevel? learnLevel;
  final SessionType sessionType;
  final LearningStyle learningStyle;

  const SkillSetupData({
    required this.intent,
    this.skillsToTeach = const [],
    this.skillsToLearn = const [],
    this.teachLevel,
    this.learnLevel,
    this.sessionType = SessionType.oneOnOne,
    this.learningStyle = LearningStyle.practical,
  });

  @override
  String toString() {
    return 'SkillSetupData(\n'
        '  intent: $intent,\n'
        '  skillsToTeach: $skillsToTeach ($teachLevel),\n'
        '  skillsToLearn: $skillsToLearn ($learnLevel),\n'
        '  session: $sessionType,\n'
        '  style: $learningStyle\n'
        ')';
  }
}
