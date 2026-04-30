import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/intent_mode.dart';
import '../models/mock_matching.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Load user profile from Firestore.
  static Future<Map<String, dynamic>?> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _usersRef.doc(user.uid).get();
    return doc.data();
  }

  /// Save or update the current user's profile to Firestore.
  static Future<void> saveUserProfile({
    required IntentMode intent,
    required List<String> skillsToLearn,
    required List<String> skillsToTeach,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';

    // On first save, initialize 100 credits if not yet set
    await _firestore.runTransaction((tx) async {
      final docRef = _usersRef.doc(user.uid);
      final docSnap = await tx.get(docRef);
      final isNew = !docSnap.exists || !(docSnap.data()?.containsKey('credits') ?? false);
      tx.set(
        docRef,
        {
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
          if (isNew) 'credits': 100,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Persist skill proficiency levels from quiz results.
  static Future<void> saveSkillLevels(Map<String, String> levels) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _usersRef.doc(uid).update({'skillLevels': levels});
  }

  /// Transfer [creditsToTransfer] from the current learner to the teacher.
  /// Uses a Firestore transaction to ensure atomicity.
  static Future<void> processSessionCredits({
    required String teacherUid,
    required int creditsToTransfer,
  }) async {
    final learnerUid = _auth.currentUser?.uid;
    if (learnerUid == null) return;

    final learnerRef = _usersRef.doc(learnerUid);
    final teacherRef = _usersRef.doc(teacherUid);

    await _firestore.runTransaction((tx) async {
      final learnerSnap = await tx.get(learnerRef);
      final teacherSnap = await tx.get(teacherRef);

      final learnerCredits =
          (learnerSnap.data()?['credits'] as num?)?.toInt() ?? 0;
      final teacherCredits =
          (teacherSnap.data()?['credits'] as num?)?.toInt() ?? 0;

      // Deduct from learner (floor at 0)
      tx.update(learnerRef,
          {'credits': (learnerCredits - creditsToTransfer).clamp(0, 9999)});
      // Add to teacher
      tx.update(teacherRef, {'credits': teacherCredits + creditsToTransfer});
    });
  }

  /// Write an in-app notification document for [toUid].
  static Future<void> sendNotification({
    required String toUid,
    required String title,
    required String body,
  }) async {
    final fromUid = _auth.currentUser?.uid ?? '';
    await _firestore.collection('notifications').add({
      'toUid': toUid,
      'fromUid': fromUid,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
  /// Computes a true skill-overlap percentage between the current user and
  /// every other user. Pass both [skillsToLearn] and [skillsToTeach] for
  /// directional matching; falls back to [selectedSkills] if not provided.
  static Stream<List<MockMatch>> streamMatches({
    required IntentMode intent,
    required List<String> selectedSkills,
    List<String> skillsToLearn = const [],
    List<String> skillsToTeach = const [],
  }) {
    final currentUid = _auth.currentUser?.uid;
    return _usersRef.snapshots().map((snapshot) {
      final allUsers = <MockUser>[];
      for (final doc in snapshot.docs) {
        if (doc.id == currentUid) continue;
        allUsers.add(MockUser.fromFirestore(doc.id, doc.data()));
      }
      return _computeMatches(
        intent: intent,
        myLearnSkills: skillsToLearn.isNotEmpty ? skillsToLearn : selectedSkills,
        myTeachSkills: skillsToTeach,
        users: allUsers,
      );
    });
  }

  /// One-shot fetch of matches (non-streaming).
  static Future<List<MockMatch>> getMatches({
    required IntentMode intent,
    required List<String> selectedSkills,
    List<String> skillsToLearn = const [],
    List<String> skillsToTeach = const [],
  }) async {
    final currentUid = _auth.currentUser?.uid;
    final snapshot = await _usersRef.get();
    final allUsers = <MockUser>[];
    for (final doc in snapshot.docs) {
      if (doc.id == currentUid) continue;
      allUsers.add(MockUser.fromFirestore(doc.id, doc.data()));
    }
    return _computeMatches(
      intent: intent,
      myLearnSkills: skillsToLearn.isNotEmpty ? skillsToLearn : selectedSkills,
      myTeachSkills: skillsToTeach,
      users: allUsers,
    );
  }

  // ── Core Matching Engine ──────────────────────────────────────────────────
  //
  // Match logic:
  //   LEARN intent  → Look for users whose skillsToTeach overlaps my skillsToLearn
  //   TEACH intent  → Look for users whose skillsToLearn overlaps my skillsToTeach
  //   BOTH intent   → Average of both directions
  //
  // Match % = (overlapping skills / my required skills) x 100 (true 0–100 value)

  static List<MockMatch> _computeMatches({
    required IntentMode intent,
    required List<String> myLearnSkills,
    required List<String> myTeachSkills,
    required List<MockUser> users,
  }) {
    final myLearn = _normalise(myLearnSkills);
    final myTeach = _normalise(myTeachSkills);

    if (myLearn.isEmpty && myTeach.isEmpty) return [];

    final matches = <MockMatch>[];

    for (final user in users) {
      final theirTeach = _normalise(user.skillsToTeach);
      final theirLearn = _normalise(user.skillsToLearn);

      // Learner score: how much of what I need can they teach?
      final learnOverlap = _intersect(myLearn, theirTeach);
      final learnScore = myLearn.isEmpty
          ? 0
          : (learnOverlap.length / myLearn.length * 100).round();

      // Teacher score: how much of what I can teach do they want to learn?
      final teachOverlap = _intersect(myTeach, theirLearn);
      final teachScore = myTeach.isEmpty
          ? 0
          : (teachOverlap.length / myTeach.length * 100).round();

      final int matchScore;
      final List<String> relevantOverlap;
      final String tag;
      final MatchSection section;

      switch (intent) {
        case IntentMode.learn:
          if (learnScore == 0) continue;
          matchScore = learnScore;
          relevantOverlap = learnOverlap;
          tag = 'Can Teach You';
          section = MatchSection.learnFromThem;
          break;
        case IntentMode.teach:
          if (teachScore == 0) continue;
          matchScore = teachScore;
          relevantOverlap = teachOverlap;
          tag = 'Wants to Learn';
          section = MatchSection.teachThem;
          break;
        case IntentMode.both:
          final allOverlap = {...learnOverlap, ...teachOverlap}.toList();
          if (allOverlap.isEmpty) continue;
          final sides = (myLearn.isNotEmpty ? 1 : 0) + (myTeach.isNotEmpty ? 1 : 0);
          matchScore = sides == 0 ? 0 : ((learnScore + teachScore) ~/ sides);
          if (matchScore == 0) continue;
          relevantOverlap = allOverlap;
          tag = (learnScore > 0 && teachScore > 0)
              ? 'Peer Match'
              : (learnScore > 0 ? 'Can Teach You' : 'Wants to Learn');
          section = learnScore >= teachScore
              ? MatchSection.learnFromThem
              : MatchSection.teachThem;
          break;
      }

      if (relevantOverlap.isEmpty) continue;

      matches.add(MockMatch(
        user: user,
        section: section,
        matchScore: matchScore.clamp(1, 100),
        matchSkill: _titleCase(relevantOverlap.first),
        tag: tag,
        matchReason: _buildMatchReason(relevantOverlap, tag),
      ));
    }

    matches.sort((a, b) {
      final s = b.matchScore.compareTo(a.matchScore);
      return s != 0 ? s : b.user.rating.compareTo(a.user.rating);
    });

    return matches.take(20).toList(growable: false);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Set<String> _normalise(List<String> skills) =>
      skills.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();

  static List<String> _intersect(Set<String> a, Set<String> b) =>
      a.intersection(b).toList();

  static String _buildMatchReason(List<String> overlap, String tag) {
    if (overlap.isEmpty) return 'Skill match';
    if (overlap.length == 1) return 'Matched on ${_titleCase(overlap.first)}';
    return 'Matched on ${_titleCase(overlap.first)} +${overlap.length - 1} more';
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
