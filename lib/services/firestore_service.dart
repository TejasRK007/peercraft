import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/intent_mode.dart';
import '../models/mock_matching.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Save or update the current user's profile to Firestore.
  static Future<void> saveUserProfile({
    required IntentMode intent,
    required List<String> skillsToLearn,
    required List<String> skillsToTeach,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';

    await _usersRef.doc(user.uid).set({
      'name': displayName,
      'email': user.email ?? '',
      'skillsToTeach': skillsToTeach,
      'skillsToLearn': skillsToLearn,
      'intent': intent.name,
      'rating': 4.5,
      'skillLevel': 'Intermediate',
      'experienceYears': 1,
      'sessionsCompleted': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Submit a rating for a teacher after a session.
  static Future<void> submitRating(String teacherUid, int rating) async {
    final docRef = _usersRef.doc(teacherUid);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;

      final data = doc.data()!;
      int count = (data['ratingCount'] as num?)?.toInt() ?? 1;
      double sum = (data['ratingSum'] as num?)?.toDouble() ??
          ((data['rating'] as num?)?.toDouble() ?? 4.5) * count;

      count += 1;
      sum += rating;

      final newAverage = sum / count;

      List<dynamic> history = data['ratingHistory'] ?? [4.5];
      history.add(rating.toDouble());

      transaction.update(docRef, {
        'ratingCount': count,
        'ratingSum': sum,
        'rating': newAverage,
        'ratingHistory': history,
      });
    });
  }

  /// Stream current user's profile
  static Stream<Map<String, dynamic>?> streamCurrentUserProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _usersRef.doc(uid).snapshots().map((doc) => doc.data());
  }

  /// Stream real-time matches from Firestore.
  /// Returns all users except the current user, converted to MockMatch objects.
  static Stream<List<MockMatch>> streamMatches({
    required IntentMode intent,
    required List<String> selectedSkills,
  }) {
    final currentUid = _auth.currentUser?.uid;

    return _usersRef.snapshots().map((snapshot) {
      final allUsers = <MockUser>[];

      for (final doc in snapshot.docs) {
        // Skip current user
        if (doc.id == currentUid) continue;
        final data = doc.data();
        allUsers.add(MockUser.fromFirestore(doc.id, data));
      }

      // Run matching logic against real users
      return _computeMatches(intent, selectedSkills, allUsers);
    });
  }

  /// One-shot fetch of matches (non-streaming).
  static Future<List<MockMatch>> getMatches({
    required IntentMode intent,
    required List<String> selectedSkills,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    final snapshot = await _usersRef.get();

    final allUsers = <MockUser>[];
    for (final doc in snapshot.docs) {
      if (doc.id == currentUid) continue;
      final data = doc.data();
      allUsers.add(MockUser.fromFirestore(doc.id, data));
    }

    return _computeMatches(intent, selectedSkills, allUsers);
  }

  /// Matching logic against real Firestore users.
  static List<MockMatch> _computeMatches(
    IntentMode intent,
    List<String> selectedSkills,
    List<MockUser> users,
  ) {
    final skills = selectedSkills
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    if (skills.isEmpty) return [];

    final matches = <MockMatch>[];

    for (final user in users) {
      // Check overlap with user's skillsToTeach
      final teachOverlap =
          _overlapInOrder(selected: skills, possible: user.skillsToTeach);

      // Check overlap with user's skillsToLearn
      final learnOverlap =
          _overlapInOrder(selected: skills, possible: user.skillsToLearn);

      // Combine all overlapping skills (deduplicated)
      final allOverlap = {...teachOverlap, ...learnOverlap}.toList();

      if (allOverlap.isNotEmpty) {
        final best = allOverlap.first;

        // Determine tag based on what overlapped
        String tag;
        MatchSection section;
        if (teachOverlap.isNotEmpty && learnOverlap.isNotEmpty) {
          tag = 'Peer Match';
          section = MatchSection.learnFromThem;
        } else if (teachOverlap.isNotEmpty) {
          tag = 'Can Teach You';
          section = MatchSection.learnFromThem;
        } else {
          tag = 'Wants to Learn';
          section = MatchSection.teachThem;
        }

        matches.add(MockMatch(
          user: user,
          section: section,
          matchScore: _scoreForOverlap(
              user.rating, allOverlap.length, skills.length),
          matchSkill: best,
          tag: tag,
          matchReason: 'Shared interest in $best',
        ));
      }
    }

    // Sort by match score, then rating
    matches.sort((a, b) {
      final scoreCmp = b.matchScore.compareTo(a.matchScore);
      if (scoreCmp != 0) return scoreCmp;
      return b.user.rating.compareTo(a.user.rating);
    });

    return matches.take(20).toList(growable: false);
  }

  static int _scoreForOverlap(
      double rating, int overlapCount, int totalSelected) {
    final overlapBoost = (overlapCount * 18).clamp(0, 54);
    final selectedBoost =
        (totalSelected <= 1) ? 12 : (12 - (totalSelected - 1) * 2);
    final ratingBoost = ((rating - 4.0) * 28).round();
    final score = 66 + overlapBoost + selectedBoost + ratingBoost;
    return score.clamp(62, 99);
  }

  static List<String> _overlapInOrder({
    required List<String> selected,
    required List<String> possible,
  }) {
    final possibleLower = possible.map((p) => p.toLowerCase()).toSet();
    final overlap = <String>[];
    for (final s in selected) {
      if (possibleLower.contains(s.toLowerCase())) overlap.add(s);
    }
    return overlap;
  }
}
