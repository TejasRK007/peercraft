import 'package:flutter/material.dart';

import '../models/intent_mode.dart';

enum MatchSection {
  learnFromThem,
  teachThem,
}

class MockUser {
  final String uid;
  final String name;
  final String email;
  final List<String> skillsToTeach;
  final List<String> skillsToLearn;
  final double rating;
  final Color avatarColor;
  final bool isTopMentor;
  final String skillLevel;
  final int experienceYears;
  final int sessionsCompleted;

  const MockUser({
    this.uid = '',
    required this.name,
    this.email = '',
    required this.skillsToTeach,
    required this.skillsToLearn,
    required this.rating,
    required this.avatarColor,
    required this.isTopMentor,
    required this.skillLevel,
    required this.experienceYears,
    required this.sessionsCompleted,
  });

  /// Create a MockUser from a Firestore document snapshot.
  factory MockUser.fromFirestore(String docId, Map<String, dynamic> data) {
    // Parse avatar color from stored int, or generate from name hash
    final colorValue = data['avatarColor'] as int?;
    final name = (data['name'] as String?) ?? 'User';
    final avatarColor = colorValue != null
        ? Color(colorValue)
        : _colorFromName(name);

    return MockUser(
      uid: docId,
      name: name,
      email: (data['email'] as String?) ?? '',
      skillsToTeach: List<String>.from(data['skillsToTeach'] ?? []),
      skillsToLearn: List<String>.from(data['skillsToLearn'] ?? []),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      avatarColor: avatarColor,
      isTopMentor: (data['sessionsCompleted'] as int? ?? 0) >= 20,
      skillLevel: (data['skillLevel'] as String?) ?? 'Intermediate',
      experienceYears: (data['experienceYears'] as int?) ?? 1,
      sessionsCompleted: (data['sessionsCompleted'] as int?) ?? 0,
    );
  }

  /// Convert this user to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'skillsToTeach': skillsToTeach,
      'skillsToLearn': skillsToLearn,
      'rating': rating,
      'avatarColor': avatarColor.toARGB32(),
      'skillLevel': skillLevel,
      'experienceYears': experienceYears,
      'sessionsCompleted': sessionsCompleted,
    };
  }

  static Color _colorFromName(String name) {
    const palette = [
      Color(0xFF7C5CFC), Color(0xFF4A2FA3), Color(0xFFFF7B54),
      Color(0xFFFFB347), Color(0xFFB39DDB), Color(0xFF2D1B69),
      Color(0xFF7E57C2), Color(0xFFFF7F7F),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    return palette[hash % palette.length];
  }
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




// Helper: used by matching UI to show initials.
String initialsForName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
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

