import 'package:flutter/material.dart';

import '../models/intent_mode.dart';

enum MatchSection {
  learnFromThem,
  teachThem,
}

class MockUser {
  final String name;
  final List<String> skillsToTeach;
  final List<String> skillsToLearn;
  final double rating;
  final Color avatarColor;
  final bool isTopMentor;
  final String skillLevel;
  final int experienceYears;
  final int sessionsCompleted;

  const MockUser({
    required this.name,
    required this.skillsToTeach,
    required this.skillsToLearn,
    required this.rating,
    required this.avatarColor,
    required this.isTopMentor,
    required this.skillLevel,
    required this.experienceYears,
    required this.sessionsCompleted,
  });
}

class MockMatch {
  final MockUser user;
  final MatchSection section;
  final int matchScore; // 0-100
  final String matchSkill;
  final String tag; // "Can Teach You" / "Wants to Learn"
  final String matchReason; // e.g. "Matches your interest in Python"

  const MockMatch({
    required this.user,
    required this.section,
    required this.matchScore,
    required this.matchSkill,
    required this.tag,
    required this.matchReason,
  });
}

const List<MockUser> mockUsers = [
  MockUser(
    name: 'Rahul Sharma',
    skillsToTeach: ['Python', 'Data Science', 'Interview Prep'],
    skillsToLearn: ['Flutter', 'UI/UX Design'],
    rating: 4.8,
    avatarColor: Color(0xFF7C5CFC),
    isTopMentor: true,
    skillLevel: 'Advanced',
    experienceYears: 4,
    sessionsCompleted: 45,
  ),
  MockUser(
    name: 'Aanya Verma',
    skillsToTeach: ['Flutter', 'UI/UX Design'],
    skillsToLearn: ['Python', 'Public Speaking'],
    rating: 4.7,
    avatarColor: Color(0xFF4A2FA3),
    isTopMentor: true,
    skillLevel: 'Intermediate',
    experienceYears: 2,
    sessionsCompleted: 12,
  ),
  MockUser(
    name: 'Rohan Mehta',
    skillsToTeach: ['Web Development', 'React', 'Java'],
    skillsToLearn: ['Guitar', 'Public Speaking'],
    rating: 4.6,
    avatarColor: Color(0xFFFF7B54),
    isTopMentor: false,
    skillLevel: 'Advanced',
    experienceYears: 3,
    sessionsCompleted: 28,
  ),
  MockUser(
    name: 'Maya Iyer',
    skillsToTeach: ['UI/UX Design', 'Communication Skills', 'Drawing'],
    skillsToLearn: ['Video Editing', 'Photography'],
    rating: 4.9,
    avatarColor: Color(0xFFFFB347),
    isTopMentor: true,
    skillLevel: 'Advanced',
    experienceYears: 5,
    sessionsCompleted: 60,
  ),
  MockUser(
    name: 'Dev Patel',
    skillsToTeach: ['Web Development', 'DevOps', 'Cybersecurity'],
    skillsToLearn: ['Data Science', 'AI/ML'],
    rating: 4.5,
    avatarColor: Color(0xFFB39DDB),
    isTopMentor: false,
    skillLevel: 'Intermediate',
    experienceYears: 2,
    sessionsCompleted: 8,
  ),
  MockUser(
    name: 'Zara Khan',
    skillsToTeach: ['Data Science', 'AI/ML', 'Python'],
    skillsToLearn: ['Blockchain', 'DevOps'],
    rating: 4.8,
    avatarColor: Color(0xFF2D1B69),
    isTopMentor: true,
    skillLevel: 'Advanced',
    experienceYears: 6,
    sessionsCompleted: 85,
  ),
  MockUser(
    name: 'Ethan Joseph',
    skillsToTeach: ['Public Speaking', 'Communication Skills'],
    skillsToLearn: ['Interview Prep', 'Resume Building'],
    rating: 4.6,
    avatarColor: Color(0xFF7E57C2),
    isTopMentor: false,
    skillLevel: 'Intermediate',
    experienceYears: 3,
    sessionsCompleted: 19,
  ),
  MockUser(
    name: 'Sophia Lin',
    skillsToTeach: ['Photography', 'Video Editing', 'Marketing'],
    skillsToLearn: ['React', 'Aptitude'],
    rating: 4.4,
    avatarColor: Color(0xFFFF7F7F),
    isTopMentor: false,
    skillLevel: 'Beginner',
    experienceYears: 1,
    sessionsCompleted: 3,
  ),
];

// Helper: used by matching UI to show initials.
String initialsForName(String name) {
  final parts = name.trim().split(RegExp(r'\\s+'));
  final first = parts.isNotEmpty ? parts.first : '';
  final second = parts.length > 1 ? parts[1] : '';
  final chars = (first + second).replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (chars.isEmpty) return name.isNotEmpty ? name[0].toUpperCase() : '';
  final take = chars.length >= 2 ? chars.substring(0, 2) : chars.substring(0, 1);
  return take.toUpperCase();
}

// Keep this here so you can extend matching rules easily later.
String intentToSubtitle(IntentMode intent) {
  switch (intent) {
    case IntentMode.learn:
      return 'People who can teach you';
    case IntentMode.teach:
      return 'People who want to learn from you';
    case IntentMode.both:
      return 'Learn from them and teach them';
  }
}

