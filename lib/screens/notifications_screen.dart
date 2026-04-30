import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Resolves a sender's display name from Firestore when [storedTitle] is blank.
Future<String> _resolveSenderName(String senderId, String storedTitle) async {
  if (storedTitle.trim().isNotEmpty) return storedTitle.trim();
  if (senderId.isEmpty) return 'Unknown';
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    final name = doc.data()?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = doc.data()?['email'] as String?;
    if (email != null && email.contains('@')) return email.split('@').first;
  } catch (_) {}
  return 'Unknown';
}

/// Notification inbox — shows all notifications for the current user.
/// Tapping a chat notification opens the relevant [ChatScreen].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when user opens the screen
    ChatService.instance.markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(14),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.deepPurple, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Notifications',
                      style: AppTheme.headingSmall.copyWith(fontSize: 20),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: ChatService.instance.markAllNotificationsRead,
                      child: Text(
                        'Mark all read',
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List ───────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<AppNotification>>(
                  stream: ChatService.instance.streamNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryPurple),
                      );
                    }

                    final notifications = snapshot.data ?? [];

                    if (notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 56,
                                color: AppTheme.textMuted.withAlpha(80)),
                            const SizedBox(height: 14),
                            Text(
                              'No notifications yet',
                              style: AppTheme.subtitleStyle
                                  .copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return _NotifCard(
                          notif: notif,
                          onTap: () {
                            ChatService.instance.markNotificationRead(notif.id);
                            if (notif.type == 'chat' &&
                                notif.senderId.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    peerId: notif.senderId,
                                    peerName: notif.title,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card — resolves sender name from Firestore for legacy records
// ─────────────────────────────────────────────────────────────────────────────
class _NotifCard extends StatefulWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  late Future<String> _nameFuture;

  @override
  void initState() {
    super.initState();
    // Resolve the real sender name — fixes old records where title was ''
    _nameFuture =
        _resolveSenderName(widget.notif.senderId, widget.notif.title);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !widget.notif.read;

    return FutureBuilder<String>(
      future: _nameFuture,
      builder: (context, snap) {
        final senderName = snap.data ?? '';
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUnread
                  ? AppTheme.primaryPurple.withAlpha(10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnread
                    ? AppTheme.primaryPurple.withAlpha(40)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar — shows first letter of resolved sender name
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: widget.notif.type == 'chat'
                        ? Text(
                            senderName.isNotEmpty
                                ? senderName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppTheme.primaryPurple,
                            ),
                          )
                        : const Icon(Icons.notifications_rounded,
                            color: AppTheme.primaryPurple, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              // Show resolved name as title; if still loading
                              // show the message body as fallback
                              senderName.isNotEmpty
                                  ? senderName
                                  : (snap.connectionState ==
                                          ConnectionState.done
                                      ? widget.notif.body
                                      : '…'),
                              style: AppTheme.labelStyle.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryPurple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.notif.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(widget.notif.createdAt),
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
