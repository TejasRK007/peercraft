import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../app_theme.dart';
import '../models/intent_mode.dart';
import '../services/session_service.dart';
import 'video_call_screen.dart';

class SessionRequestsScreen extends StatefulWidget {
  final IntentMode intent;
  const SessionRequestsScreen({super.key, required this.intent});

  @override
  State<SessionRequestsScreen> createState() => _SessionRequestsScreenState();
}

class _SessionRequestsScreenState extends State<SessionRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
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
                                color: AppTheme.bluePurple.withAlpha(14),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.deepPurple,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Sessions',
                        style: AppTheme.headlineStyle.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),

                // Conditional UI based on IntentMode
                if (widget.intent == IntentMode.teach)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _IncomingTab(),
                    ),
                  )
                else if (widget.intent == IntentMode.learn)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _SentTab(),
                    ),
                  )
                else ...[
                  // Tab bar (only when intent is Both)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.bluePurple.withAlpha(10),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.bluePurple.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: AppTheme.buttonGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textMuted,
                      labelStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      tabs: const [
                        Tab(text: 'Incoming'),
                        Tab(text: 'Sent'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_IncomingTab(), _SentTab()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Incoming Requests Tab ───────────────────────────────────────────────────

class _IncomingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionRequest>>(
      stream: SessionService.streamIncomingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Could not load requests.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTheme.subtitleStyle.copyWith(color: Colors.redAccent),
              ),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No incoming requests',
            subtitle: 'When someone wants to connect,\nit will show up here.',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return _RequestCard(request: req, isIncoming: true);
          },
        );
      },
    );
  }
}

// ─── Sent Requests Tab ──────────────────────────────────────────────────────

class _SentTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionRequest>>(
      stream: SessionService.streamSentRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Could not load sent requests.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTheme.subtitleStyle.copyWith(color: Colors.redAccent),
              ),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.send_rounded,
            title: 'No sent requests',
            subtitle: 'Requests you send to peers\nwill appear here.',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return _RequestCard(request: req, isIncoming: false);
          },
        );
      },
    );
  }
}

// ─── Request Card ───────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final SessionRequest request;
  final bool isIncoming;

  const _RequestCard({required this.request, required this.isIncoming});

  Color get _statusColor {
    switch (request.status) {
      case 'pending':
        return const Color(0xFFFFB347);
      case 'accepted':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return Colors.redAccent;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get _peerName => isIncoming ? request.fromName : request.toName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bluePurple.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name + status badge
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFC), Color(0xFF4A2FA3)],
                  ),
                ),
                child: Center(
                  child: Text(
                    _peerName.isNotEmpty ? _peerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _peerName,
                      style: AppTheme.headingSmall.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIncoming ? 'wants to connect with you' : 'request sent',
                      style: AppTheme.labelStyle.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 14, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      request.status[0].toUpperCase() +
                          request.status.substring(1),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Info chips row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.auto_awesome_rounded, text: request.skill),
              _InfoChip(icon: Icons.schedule_rounded, text: request.slot),
              _InfoChip(icon: Icons.people_rounded, text: request.sessionType),
            ],
          ),
          const SizedBox(height: 14),

          // Action buttons
          if (isIncoming && request.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await SessionService.acceptRequest(request.id);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await SessionService.rejectRequest(request.id);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.3,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Join Call button for accepted sessions
          if (request.status == 'accepted')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoCallScreen(
                        channelName: request.channelName,
                        peerName: _peerName,
                        teacherUid: request.teacherUid,
                        skill: request.skill,
                        isTeacher:
                            FirebaseAuth.instance.currentUser?.uid ==
                            request.teacherUid,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: const Text('Join Video Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryPurple),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppTheme.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.primaryPurple),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppTheme.headingSmall.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
