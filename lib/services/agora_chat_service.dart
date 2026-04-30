import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ⚠️  FILL IN YOUR AGORA CREDENTIALS BEFORE TESTING
// ─────────────────────────────────────────────────────────────────────────────
// 1. App Key  → Agora Console → Chat → App Key  (e.g. "1234567890#peercraft")
// 2. Per-user Agora token → Agora Console → Chat → Users → Generate token,
//    then store it in Firestore:  users/{uid}.agoraChatToken
//
// ⚠️  Never hard-code tokens in production. Use a backend token server.
// ─────────────────────────────────────────────────────────────────────────────

/// Agora Chat App Key from the Agora Console.
const String _agoraAppKey = 'YOUR_APP_KEY'; // ← replace before testing

// ignore: avoid_print
void _log(String msg) => print('[AgoraChat] $msg');

class AgoraChatService {
  AgoraChatService._();
  static final AgoraChatService instance = AgoraChatService._();

  bool _initialized = false;
  bool _loggedIn = false;

  /// Callbacks that the UI can subscribe to for incoming messages.
  final List<void Function(List<ChatMessage>)> _onMessagesReceived = [];

  // ── Init ─────────────────────────────────────────────────────────────────
  /// Call once at app startup (after Firebase.initializeApp()).
  Future<void> init() async {
    if (_initialized) return;

    final options = ChatOptions(
      appKey: _agoraAppKey,
      autoLogin: false,
    );

    await ChatClient.getInstance.init(options);
    _initialized = true;
    _log('Initialized ✅');
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  /// Login using the current Firebase UID as the Agora Chat user ID and
  /// the Agora user token stored in Firestore under users/{uid}.agoraChatToken
  Future<void> loginCurrentUser() async {
    if (!_initialized) await init();
    if (_loggedIn) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _log('No Firebase user — cannot login.');
      return;
    }

    // Fetch the per-user Agora token from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    final agoraToken = doc.data()?['agoraChatToken'] as String?;

    if (agoraToken == null || agoraToken.isEmpty) {
      _log(
        '⚠️  No agoraChatToken in Firestore for uid=${firebaseUser.uid}.\n'
        '  → Go to Agora Console → Chat → Users, generate a token,\n'
        '    then write it to Firestore: users/${firebaseUser.uid}.agoraChatToken',
      );
      return;
    }

    try {
      // We use the Firebase UID as the Agora Chat userId so each user is
      // uniquely and consistently identified across both systems.
      await ChatClient.getInstance.loginWithToken(
        firebaseUser.uid,
        agoraToken,
      );
      _loggedIn = true;
      _setupListeners();
      _log('Logged in as ${firebaseUser.uid} ✅');
    } on ChatError catch (e) {
      _log('Login error: ${e.code} — ${e.description}');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (!_loggedIn) return;
    try {
      await ChatClient.getInstance.logout();
    } on ChatError catch (_) {}
    _loggedIn = false;
    _log('Logged out.');
  }

  // ── Listeners ─────────────────────────────────────────────────────────────
  void _setupListeners() {
    ChatClient.getInstance.chatManager.addEventHandler(
      'peercraft_chat_handler',
      ChatEventHandler(
        onMessagesReceived: (messages) {
          _log('Received ${messages.length} message(s).');
          for (final handler in _onMessagesReceived) {
            handler(messages);
          }
        },
      ),
    );
  }

  void addMessageListener(void Function(List<ChatMessage>) handler) {
    _onMessagesReceived.add(handler);
  }

  void removeMessageListener(void Function(List<ChatMessage>) handler) {
    _onMessagesReceived.remove(handler);
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  /// Send a plain-text message to [targetUserId] (the peer's Firebase UID).
  Future<bool> sendTextMessage({
    required String targetUserId,
    required String text,
  }) async {
    if (!_loggedIn) {
      _log('Not logged in — cannot send message.');
      return false;
    }

    try {
      final message = ChatMessage.createTxtSendMessage(
        targetId: targetUserId,
        content: text,
      );
      await ChatClient.getInstance.chatManager.sendMessage(message);
      _log('Sent to $targetUserId: "$text" ✅');
      return true;
    } on ChatError catch (e) {
      _log('Send error: ${e.code} — ${e.description}');
      return false;
    }
  }

  // ── Fetch History ─────────────────────────────────────────────────────────
  /// Fetch messages for a 1-on-1 conversation with [peerId] (Firebase UID).
  Future<List<ChatMessage>> fetchMessages({
    required String peerId,
    int count = 50,
  }) async {
    if (!_loggedIn) return [];

    try {
      final conversation = await ChatClient.getInstance.chatManager
          .getConversation(peerId, type: ChatConversationType.Chat);
      if (conversation == null) return [];

      final messages = await conversation.loadMessages(
        startMsgId: '',
        loadCount: count,
        direction: ChatSearchDirection.Up,
      );
      return messages;
    } on ChatError catch (e) {
      _log('Fetch error: ${e.code} — ${e.description}');
      return [];
    }
  }

  /// Get all local conversations for the chat list screen.
  Future<List<ChatConversation>> getConversations() async {
    if (!_loggedIn) return [];
    return await ChatClient.getInstance.chatManager.loadAllConversations();
  }

  bool get isLoggedIn => _loggedIn;
  bool get isInitialized => _initialized;
}
