import '../models/intent_mode.dart';
import '../models/mock_matching.dart';

List<MockMatch> getMatches(IntentMode intent, List<String> selectedSkills) {
  final skills = selectedSkills
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // Avoid pathological empty input: fallback to a sensible default.
  final safeSkills = skills.isEmpty ? const ['Python'] : skills;

  final canTeach = <MockMatch>[];
  final wantsToLearn = <MockMatch>[];

  for (final user in mockUsers) {
    final teachOverlap =
        _overlapInOrder(selected: safeSkills, possible: user.skillsToTeach);
    if (teachOverlap.isNotEmpty) {
      final best = teachOverlap.first;
      canTeach.add(
        MockMatch(
          user: user,
          section: MatchSection.learnFromThem,
          matchScore: _scoreForOverlap(user.rating, teachOverlap.length, safeSkills.length),
          matchSkill: best,
          tag: 'Can Teach You',
          matchReason: 'Matches your interest in $best',
        ),
      );
    }

    final learnOverlap =
        _overlapInOrder(selected: safeSkills, possible: user.skillsToLearn);
    if (learnOverlap.isNotEmpty) {
      final best = learnOverlap.first;
      wantsToLearn.add(
        MockMatch(
          user: user,
          section: MatchSection.teachThem,
          matchScore: _scoreForOverlap(user.rating, learnOverlap.length, safeSkills.length),
          matchSkill: best,
          tag: 'Wants to Learn',
          matchReason: 'Matches your interest in $best',
        ),
      );
    }
  }

  // Intent-specific output with “never empty” fallback.
  List<MockMatch> result;
  switch (intent) {
    case IntentMode.learn:
      result = canTeach;
      if (result.isEmpty) {
        result = _fallbackMatches(
          safeSkills: safeSkills,
          tag: 'Can Teach You',
          section: MatchSection.learnFromThem,
        );
      }
      break;
    case IntentMode.teach:
      result = wantsToLearn;
      if (result.isEmpty) {
        result = _fallbackMatches(
          safeSkills: safeSkills,
          tag: 'Wants to Learn',
          section: MatchSection.teachThem,
        );
      }
      break;
    case IntentMode.both:
      result = [...canTeach, ...wantsToLearn];
      if (result.isEmpty) {
        // If neither side overlaps, show fallback in both sections.
        result = [
          ..._fallbackMatches(
            safeSkills: safeSkills,
            tag: 'Can Teach You',
            section: MatchSection.learnFromThem,
          ),
          ..._fallbackMatches(
            safeSkills: safeSkills,
            tag: 'Wants to Learn',
            section: MatchSection.teachThem,
          ),
        ];
      }
      break;
  }

  // Stable sorting: higher score first, then rating.
  result.sort((a, b) {
    final scoreCmp = b.matchScore.compareTo(a.matchScore);
    if (scoreCmp != 0) return scoreCmp;
    return b.user.rating.compareTo(a.user.rating);
  });

  // Keep UI neat.
  return result.take(8).toList(growable: false);
}

List<MockMatch> _fallbackMatches({
  required List<String> safeSkills,
  required String tag,
  required MatchSection section,
}) {
  final bestSkill = safeSkills.first;
  final fallbackUsers = mockUsers
      .toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));

  return fallbackUsers.take(6).map((u) {
    final score = 78 + (u.rating - 4.0).round() * 3;
    return MockMatch(
      user: u,
      section: section,
      matchScore: score.clamp(70, 96),
      matchSkill: bestSkill,
      tag: tag,
      matchReason: 'Matches your interest in $bestSkill',
    );
  }).toList(growable: false);
}

int _scoreForOverlap(double rating, int overlapCount, int totalSelected) {
  final overlapBoost = (overlapCount * 18).clamp(0, 54);
  final selectedBoost = (totalSelected <= 1) ? 12 : (12 - (totalSelected - 1) * 2);
  final ratingBoost = ((rating - 4.0) * 28).round(); // roughly [-14..28]
  final score = 66 + overlapBoost + selectedBoost + ratingBoost;
  return score.clamp(62, 99);
}

List<String> _overlapInOrder({
  required List<String> selected,
  required List<String> possible,
}) {
  final possibleSet = possible.toSet();
  final overlap = <String>[];
  for (final s in selected) {
    if (possibleSet.contains(s)) overlap.add(s);
  }
  return overlap;
}

