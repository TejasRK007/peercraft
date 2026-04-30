import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firestore schema
// ─────────────────────────────────────────────────────────────────────────────
//  chats/{conversationId}
//    ├── participants: [uid1, uid2]
//    ├── lastMessage: String
//    ├── lastMessageAt: Timestamp
//    └── messages/{messageId}
//          ├── senderId: String
//          ├── text: String
//          ├── createdAt: Timestamp
//          └── read: bool
//
//  users/{uid}/notifications/{notifId}
//          ├── type: 'chat'
//          ├── title: String
//          ├── body: String
//          ├── senderId: String
//          ├── conversationId: String
//          ├── createdAt: Timestamp
//          └── read: bool
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single chat message.
class ChatMsg {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool read;

  const ChatMsg({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.read,
  });

  bool get isMe => senderId == FirebaseAuth.instance.currentUser?.uid;

  factory ChatMsg.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChatMsg(
      id: doc.id,
      senderId: d['senderId'] as String,
      text: d['text'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }
}

/// Represents a notification item.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String senderId;
  final String conversationId;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.senderId,
    required this.conversationId,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppNotification(
      id: doc.id,
      type: d['type'] as String? ?? 'chat',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      senderId: d['senderId'] as String? ?? '',
      conversationId: d['conversationId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Conversation ID ───────────────────────────────────────────────────────
  /// Deterministic conversation ID — same for both users regardless of order.
  static String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String get _myUid => _auth.currentUser!.uid;

  // ── Send Message ──────────────────────────────────────────────────────────
  /// Sends [text] to [peerId] and writes a notification to the peer's inbox.
  Future<void> sendMessage({
    required String peerId,
    required String peerName,
    required String text,
  }) async {
    final me = _auth.currentUser!;
    final myName =
        me.displayName ?? me.email?.split('@').first ?? 'Someone';
    final convId = conversationId(me.uid, peerId);
    final convRef = _db.collection('chats').doc(convId);
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();

    // 1. Upsert the conversation document
    batch.set(
      convRef,
      {
        'participants': [me.uid, peerId],
        'lastMessage': text,
        'lastMessageAt': now,
      },
      SetOptions(merge: true),
    );

    // 2. Add the message to the sub-collection
    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, {
      'senderId': me.uid,
      'text': text,
      'createdAt': now,
      'read': false,
    });

    // 3. Write a notification to the peer's inbox
    final notifRef =
        _db.collection('users').doc(peerId).collection('notifications').doc();
    batch.set(notifRef, {
      'type': 'chat',
      'title': myName,
      'body': text,
      'senderId': me.uid,
      'conversationId': convId,
      'createdAt': now,
      'read': false,
    });

    await batch.commit();
  }

  // ── Stream Messages ───────────────────────────────────────────────────────
  /// Real-time stream of messages for a conversation with [peerId].
  Stream<List<ChatMsg>> streamMessages(String peerId) {
    final convId = conversationId(_myUid, peerId);
    return _db
        .collection('chats')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMsg.fromDoc).toList());
  }

  // ── Mark Messages Read ────────────────────────────────────────────────────
  /// Marks all unread messages from [peerId] as read.
  Future<void> markMessagesRead(String peerId) async {
    final convId = conversationId(_myUid, peerId);
    final unread = await _db
        .collection('chats')
        .doc(convId)
        .collection('messages')
        .where('senderId', isEqualTo: peerId)
        .where('read', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  /// Real-time stream of all notifications for the current user, newest first.
  Stream<List<AppNotification>> streamNotifications() {
    return _db
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  /// Stream of the count of unread notifications — used for the bell badge.
  Stream<int> streamUnreadNotificationCount() {
    return _db
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Marks a single notification as read.
  Future<void> markNotificationRead(String notifId) {
    return _db
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  /// Marks ALL notifications as read (called when user opens the inbox).
  Future<void> markAllNotificationsRead() async {
    final unread = await _db
        .collection('users')
        .doc(_myUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
