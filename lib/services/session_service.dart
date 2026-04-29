import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String skill;
  final String slot;
  final String sessionType;
  final String status; // pending, accepted, rejected
  final String channelName;
  final String teacherUid;
  final DateTime? createdAt;

  const SessionRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.skill,
    required this.slot,
    required this.sessionType,
    required this.status,
    required this.channelName,
    required this.teacherUid,
    this.createdAt,
  });

  factory SessionRequest.fromFirestore(String docId, Map<String, dynamic> data) {
    // Safely parse createdAt — it may be null if serverTimestamp hasn't resolved yet
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    }

    return SessionRequest(
      id: docId,
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      toName: (data['toName'] as String?) ?? '',
      skill: (data['skill'] as String?) ?? '',
      slot: (data['slot'] as String?) ?? '',
      sessionType: (data['sessionType'] as String?) ?? '1:1',
      status: (data['status'] as String?) ?? 'pending',
      channelName: (data['channelName'] as String?) ?? '',
      teacherUid: (data['teacherUid'] as String?) ?? '',
      createdAt: created,
    );
  }

  /// Whether the current user is the sender.
  bool get isSentByMe {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return fromUid == uid;
  }
}

class SessionService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('session_requests');

  // ── Send ──────────────────────────────────────────────────────────────

  /// Send a session request to a peer.
  static Future<void> sendRequest({
    required String toUid,
    required String toName,
    required String skill,
    required String slot,
    required String sessionType,
    required String teacherUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final myName = user.displayName ?? user.email?.split('@').first ?? 'User';

    // Deterministic channel name from sorted UIDs
    final ids = [user.uid, toUid]..sort();
    final a = ids[0].length >= 6 ? ids[0].substring(0, 6) : ids[0];
    final b = ids[1].length >= 6 ? ids[1].substring(0, 6) : ids[1];
    final channelName = 'peer_${a}_$b';

    await _ref.add({
      'fromUid': user.uid,
      'fromName': myName,
      'toUid': toUid,
      'toName': toName,
      'skill': skill,
      'slot': slot,
      'sessionType': sessionType,
      'status': 'pending',
      'channelName': channelName,
      'teacherUid': teacherUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Streams ───────────────────────────────────────────────────────────
  // NOTE: We use simple .where() queries WITHOUT .orderBy() to avoid
  // requiring Firestore composite indexes. Sorting is done client-side.

  /// Stream incoming requests (requests sent TO me).
  static Stream<List<SessionRequest>> streamIncomingRequests() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _ref
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SessionRequest.fromFirestore(doc.id, doc.data()))
          .toList();
      // Sort newest first (client-side)
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return list;
    }).handleError((error) {
      // Log but don't crash — return empty list on error
      // ignore: avoid_print
      print('[SessionService] streamIncomingRequests error: $error');
      return <SessionRequest>[];
    });
  }

  /// Stream requests I've sent (to see status updates).
  static Stream<List<SessionRequest>> streamSentRequests() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _ref
        .where('fromUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SessionRequest.fromFirestore(doc.id, doc.data()))
          .toList();
      // Sort newest first (client-side)
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return list;
    }).handleError((error) {
      // ignore: avoid_print
      print('[SessionService] streamSentRequests error: $error');
      return <SessionRequest>[];
    });
  }

  /// Stream count of pending incoming requests (for badge).
  static Stream<int> streamPendingCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _ref
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      // Count only 'pending' status docs client-side
      return snap.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'pending';
      }).length;
    }).handleError((error) {
      // ignore: avoid_print
      print('[SessionService] streamPendingCount error: $error');
      return 0;
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────

  /// Accept a session request.
  static Future<void> acceptRequest(String docId) async {
    await _ref.doc(docId).update({'status': 'accepted'});
  }

  /// Reject a session request.
  static Future<void> rejectRequest(String docId) async {
    await _ref.doc(docId).update({'status': 'rejected'});
  }
}
