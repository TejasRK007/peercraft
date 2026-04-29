import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../app_theme.dart';
import '../models/mock_matching.dart';
import '../services/session_service.dart';
import 'chat_screen.dart';

class MatchProfileScreen extends StatefulWidget {
  final MockMatch match;

  const MatchProfileScreen({super.key, required this.match});

  @override
  State<MatchProfileScreen> createState() => _MatchProfileScreenState();
}

class _MatchProfileScreenState extends State<MatchProfileScreen> {
  final _sessionTypes = const ['1:1', 'Group'];
  String _selectedSessionType = '1:1';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String get _formattedSlot {
    if (_selectedDate == null || _selectedTime == null) return 'Pick a date & time';
    final d = _selectedDate!;
    final t = _selectedTime!;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final min = t.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$min $period';
  }

  bool get _hasSchedule => _selectedDate != null && _selectedTime != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryPurple,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryPurple,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                _HeaderBar(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileTop(
                          name: match.user.name,
                          avatarColor: match.user.avatarColor,
                          rating: match.user.rating,
                          showTopMentorBadge: match.user.isTopMentor,
                        ),
                        const SizedBox(height: 18),

                        const _VerifiedPeer(),
                        const SizedBox(height: 18),

                        Text(
                          'Skills They Teach',
                          style: AppTheme.headingSmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        _SkillChips(skills: match.user.skillsToTeach),
                        const SizedBox(height: 18),

                        Text(
                          'Skills They Want',
                          style: AppTheme.headingSmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        _SkillChips(skills: match.user.skillsToLearn),
                        const SizedBox(height: 22),

                        _AiCompatibilityCard(
                          matchPercent: match.matchScore,
                          reasonText: match.matchReason,
                        ),
                        const SizedBox(height: 22),

                        Text(
                          'Expertise & Experience',
                          style: AppTheme.headingSmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        _SkillLevelBreakdown(skillLevel: match.user.skillLevel),
                        const SizedBox(height: 12),
                        _ExperienceGraph(
                          experienceYears: match.user.experienceYears,
                          avatarColor: match.user.avatarColor,
                        ),
                        const SizedBox(height: 22),

                        Text(
                          'Platform Stats',
                          style: AppTheme.headingSmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SessionHistory(sessionsCompleted: match.user.sessionsCompleted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _RatingBreakdown(rating: match.user.rating),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // ── Schedule Session ─────────────────────
                        Text(
                          'Schedule Session',
                          style: AppTheme.headingSmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 10),

                        _SessionTypePicker(
                          value: _selectedSessionType,
                          options: _sessionTypes,
                          onChanged: (v) =>
                              setState(() => _selectedSessionType = v),
                        ),
                        const SizedBox(height: 14),

                        // Date & Time pickers
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(230),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedDate != null
                                          ? AppTheme.primaryPurple.withAlpha(160)
                                          : AppTheme.primaryPurple.withAlpha(60),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded,
                                          size: 18,
                                          color: _selectedDate != null
                                              ? AppTheme.primaryPurple
                                              : AppTheme.textMuted),
                                      const SizedBox(width: 10),
                                      Text(
                                        _selectedDate != null
                                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                            : 'Select Date',
                                        style: AppTheme.labelStyle.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _selectedDate != null
                                              ? AppTheme.deepPurple
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(230),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedTime != null
                                          ? AppTheme.primaryPurple.withAlpha(160)
                                          : AppTheme.primaryPurple.withAlpha(60),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded,
                                          size: 18,
                                          color: _selectedTime != null
                                              ? AppTheme.primaryPurple
                                              : AppTheme.textMuted),
                                      const SizedBox(width: 10),
                                      Text(
                                        _selectedTime != null
                                            ? _selectedTime!.format(context)
                                            : 'Select Time',
                                        style: AppTheme.labelStyle.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _selectedTime != null
                                              ? AppTheme.deepPurple
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Selected summary
                        if (_hasSchedule)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withAlpha(12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.primaryPurple.withAlpha(50)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded,
                                    size: 18, color: AppTheme.primaryPurple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$_formattedSlot • $_selectedSessionType',
                                    style: AppTheme.labelStyle.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.deepPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),

                _BottomActions(
                  canSend: _hasSchedule,
                  onRequestSession: () async {
                    if (!_hasSchedule || !mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final slot = _formattedSlot;
                    final sType = _selectedSessionType;
                    try {
                      await SessionService.sendRequest(
                        toUid: match.user.uid,
                        toName: match.user.name,
                        skill: match.matchSkill,
                        slot: slot,
                        sessionType: sType,
                        teacherUid: match.section == MatchSection.learnFromThem
                            ? match.user.uid
                            : FirebaseAuth.instance.currentUser!.uid,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF4CAF50),
                          duration: const Duration(seconds: 2),
                          content: Text(
                            'Session request sent to ${match.user.name}!\n$slot • $sType',
                            style: AppTheme.subtitleStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 3),
                          content: Text(
                            'Failed to send request: $e',
                            style: AppTheme.subtitleStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  onChatFirst: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration:
                            const Duration(milliseconds: 420),
                        pageBuilder: (_, __, ___) =>
                            ChatScreen(peerName: match.user.name),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final VoidCallback onBack;
  const _HeaderBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.deepPurple,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProfileTop extends StatelessWidget {
  final String name;
  final Color avatarColor;
  final double rating;
  final bool showTopMentorBadge;

  const _ProfileTop({
    required this.name,
    required this.avatarColor,
    required this.rating,
    required this.showTopMentorBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withAlpha(230),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withAlpha(80),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -8,
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: avatarColor.withAlpha(220),
                  child: Text(
                    initialsForName(name),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),
          Text(
            name,
            style: AppTheme.headingSmall.copyWith(fontSize: 20),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC857), size: 18),
              const SizedBox(width: 8),
              Text(
                ' ${rating.toStringAsFixed(1)}',
                style: AppTheme.labelStyle.copyWith(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (showTopMentorBadge)
            _Badge(
              text: 'Top Mentor',
              icon: Icons.verified_rounded,
              color: AppTheme.primaryPurple,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _Badge({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTheme.labelStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedPeer extends StatelessWidget {
  const _VerifiedPeer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: AppTheme.primaryPurple),
          const SizedBox(width: 10),
          Text(
            'Verified Peer',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.primaryPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChips extends StatelessWidget {
  final List<String> skills;
  const _SkillChips({required this.skills});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((s) {
        return Chip(
          label: Text(
            s,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppTheme.primaryPurple.withAlpha(110), width: 1),
          ),
        );
      }).toList(),
    );
  }
}

class _AiCompatibilityCard extends StatelessWidget {
  final int matchPercent;
  final String reasonText;

  const _AiCompatibilityCard({
    required this.matchPercent,
    required this.reasonText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFC), Color(0xFF4A2FA3)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withAlpha(70),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatchPercentAnimated(target: matchPercent),
          const SizedBox(height: 6),
          Text(
            'Why you matched',
            style: AppTheme.headingSmall.copyWith(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reasonText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.subtitleStyle.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: Colors.white.withAlpha(230),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPercentAnimated extends StatelessWidget {
  final int target;
  const _MatchPercentAnimated({required this.target});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 52, end: target.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          ),
          child: Text(
            '${value.round()}% Match',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _SessionTypePicker extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SessionTypePicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Type',
          style: AppTheme.labelStyle.copyWith(
            fontWeight: FontWeight.w900,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: options.map((t) {
            final selected = t == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 46,
                  margin: EdgeInsets.only(
                    right: t == options.first ? 10 : 0,
                    left: t == options.last ? 10 : 0,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected ? AppTheme.buttonGradient : null,
                    color: selected ? null : Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : AppTheme.primaryPurple.withAlpha(90),
                      width: 1.2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withAlpha(60),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      t,
                      style: AppTheme.labelStyle.copyWith(
                        color: selected ? Colors.white : AppTheme.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool canSend;
  final Future<void> Function() onRequestSession;
  final VoidCallback onChatFirst;

  const _BottomActions({
    required this.canSend,
    required this.onRequestSession,
    required this.onChatFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Row(
        children: [
          // Request Session
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canSend ? onRequestSession : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Request Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Chat
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onChatFirst,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(230),
                foregroundColor: AppTheme.primaryPurple,
                side: BorderSide(
                  color: AppTheme.primaryPurple.withAlpha(160),
                  width: 1.3,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillLevelBreakdown extends StatelessWidget {
  final String skillLevel;
  const _SkillLevelBreakdown({required this.skillLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(10), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.leaderboard_rounded, color: AppTheme.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Level',
                  style: AppTheme.labelStyle.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  skillLevel,
                  style: AppTheme.headingSmall.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceGraph extends StatelessWidget {
  final int experienceYears;
  final Color avatarColor;
  
  const _ExperienceGraph({required this.experienceYears, required this.avatarColor});

  @override
  Widget build(BuildContext context) {
    final int maxYears = 10;
    final int displayBars = 10;
    final int activeBars = ((experienceYears / maxYears) * displayBars).clamp(1, displayBars).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Experience',
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$experienceYears+ Years',
                style: AppTheme.labelStyle.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(displayBars, (index) {
              final isActive = index < activeBars;
              return Container(
                width: 20,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? avatarColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SessionHistory extends StatelessWidget {
  final int sessionsCompleted;
  const _SessionHistory({required this.sessionsCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_edu_rounded, color: AppTheme.primaryPurple, size: 26),
          const SizedBox(height: 10),
          Text(
            '$sessionsCompleted',
            style: AppTheme.headingSmall.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            'Sessions Done',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  final double rating;
  const _RatingBreakdown({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 26),
          const SizedBox(height: 10),
          Text(
            rating.toStringAsFixed(1),
            style: AppTheme.headingSmall.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            'Average Rating',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
