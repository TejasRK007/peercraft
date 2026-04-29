import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onboarding_preferences_service.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';

import '../app_theme.dart';
import '../main.dart';
import '../models/intent_mode.dart';
import '../models/mock_matching.dart';
import 'match_profile_screen.dart';
import 'session_requests_screen.dart';
import 'video_call_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<String> selectedSkills;
  final List<String> skillsToLearn;
  final List<String> skillsToTeach;
  final IntentMode intent;

  const HomeScreen({
    super.key,
    required this.selectedSkills,
    required this.intent,
    this.skillsToLearn = const [],
    this.skillsToTeach = const [],
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _searchController = TextEditingController();

  late IntentMode _currentIntent;
  bool _isLoading = true;
  String _loadingStage = 'Analyzing your skills...';
  String _query = '';

  List<MockMatch> _matches = const [];
  StreamSubscription<List<MockMatch>>? _matchSub;

  @override
  void initState() {
    super.initState();
    _currentIntent = widget.intent;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _loadingStage = 'Analyzing your skills...';
    });
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _loadingStage = 'Finding best matches...');

    // Cancel any previous subscription
    _matchSub?.cancel();

    // Subscribe to real-time Firestore matches
    _matchSub = FirestoreService.streamMatches(
      intent: _currentIntent,
      selectedSkills: widget.selectedSkills,
    ).listen((firestoreMatches) {
      if (!mounted) return;
      setState(() {
        _matches = firestoreMatches;
        _isLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _matches = [];
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.deepPurple,
      ),
    );
  }

  List<MockMatch> _filteredMatches() {
    if (_query.isEmpty) return _matches;
    return _matches
        .where((m) =>
            m.user.name.toLowerCase().contains(_query) ||
            m.matchSkill.toLowerCase().contains(_query) ||
            m.tag.toLowerCase().contains(_query) ||
            m.matchReason.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  void _openMatchProfile(MockMatch match) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, __, ___) => MatchProfileScreen(match: match),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showUpcomingSessions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UpcomingSessionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMatches();
    final learnFromThem = filtered
        .where((m) => m.section == MatchSection.learnFromThem)
        .toList(growable: false);
    final teachThem = filtered
        .where((m) => m.section == MatchSection.teachThem)
        .toList(growable: false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration:
                  const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: SafeArea(
                top: true,
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _HomeTab(
                      intent: _currentIntent,
                      onIntentChanged: (newIntent) {
                        setState(() => _currentIntent = newIntent);
                        _loadMatches();
                      },
                      selectedSkills: widget.selectedSkills,
                      skillsToLearn: widget.skillsToLearn,
                      skillsToTeach: widget.skillsToTeach,
                      allMatches: _matches,
                      searchController: _searchController,
                      learnFromThem: learnFromThem,
                      teachThem: teachThem,
                      onReload: _loadMatches,
                      onOpenMatchProfile: _openMatchProfile,
                      onQuickAction: (action) {
                        if (action == 'Start Session') {
                          if (_matches.isEmpty) {
                            _showSnack('No matches yet. Use Find Match.');
                            return;
                          }
                          _openMatchProfile(_matches.first);
                          return;
                        }
                        if (action == 'Teach Now') {
                          _showUpcomingSessions();
                          return;
                        }
                        _showSnack('$action (demo)');
                      },
                    ),
                    _MatchesTab(
                      matches: filtered,
                      onOpenMatchProfile: _openMatchProfile,
                      onReload: _loadMatches,
                      onAction: _showSnack,
                    ),
                    _SessionsTab(onAction: _showSnack),
                    _ProfileTab(
                      intent: _currentIntent,
                      onIntentChanged: (newIntent) {
                        setState(() => _currentIntent = newIntent);
                        _loadMatches();
                      },
                      selectedSkills: widget.selectedSkills,
                      credits: 100,
                      onAction: _showSnack,
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading) _LoadingOverlay(message: _loadingStage),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white.withAlpha(215),
          elevation: 10,
          selectedItemColor: AppTheme.primaryPurple,
          unselectedItemColor: AppTheme.textMuted,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  final String message;
  const _LoadingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.white.withAlpha(40),
          alignment: Alignment.center,
          child: Dialog(
            backgroundColor: Colors.white.withAlpha(235),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTheme.headingSmall.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Using real-time Firestore data.',
                    textAlign: TextAlign.center,
                    style: AppTheme.subtitleStyle,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final IntentMode intent;
  final ValueChanged<IntentMode> onIntentChanged;
  final List<String> selectedSkills;
  final List<String> skillsToLearn;
  final List<String> skillsToTeach;
  final List<MockMatch> allMatches;
  final TextEditingController searchController;
  final List<MockMatch> learnFromThem;
  final List<MockMatch> teachThem;
  final VoidCallback onReload;
  final ValueChanged<MockMatch> onOpenMatchProfile;
  final ValueChanged<String> onQuickAction;

  const _HomeTab({
    required this.intent,
    required this.onIntentChanged,
    required this.selectedSkills,
    required this.skillsToLearn,
    required this.skillsToTeach,
    required this.allMatches,
    required this.searchController,
    required this.learnFromThem,
    required this.teachThem,
    required this.onReload,
    required this.onOpenMatchProfile,
    required this.onQuickAction,
  });

  (String label, String subtitle, List<MockMatch> matches) _sectionData() {
    if (intent == IntentMode.learn) {
      return ('Find mentors to learn from', 'People who can teach you', learnFromThem);
    }
    if (intent == IntentMode.teach) {
      return ('Students looking to learn from you', 'People who want to learn from you', teachThem);
    }
    return ('Recommended Matches', 'Learn from them and teach them', [
      ...learnFromThem,
      ...teachThem,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final section = _sectionData();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(intent: intent, onIntentChanged: onIntentChanged),
            const SizedBox(height: 14),
            _SearchBar(controller: searchController),
            const SizedBox(height: 18),
            if (intent == IntentMode.teach)
              const _TeacherRatingGraph()
            else
              _MatchesSection(
                title: section.$1,
                subtitle: section.$2,
                matches: section.$3,
                onOpenMatchProfile: onOpenMatchProfile,
              ),

            const SizedBox(height: 22),

            if (intent == IntentMode.teach) ...[
              Text(
                'Skills you can teach',
                style: AppTheme.headingSmall.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              _buildSkillChips(skillsToTeach),
            ] else ...[
              Text(
                'Skills to Learn',
                style: AppTheme.headingSmall.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              _buildSkillChips(skillsToLearn),
              const SizedBox(height: 22),
              Text(
                'Your Skills',
                style: AppTheme.headingSmall.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              _buildSkillChips(skillsToTeach),
            ],

            const SizedBox(height: 22),

            Text(
              'Quick Actions',
              style: AppTheme.headingSmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            _QuickActions(
              intent: intent,
              onAction: onQuickAction,
              skillsToLearn: skillsToLearn,
              allMatches: allMatches,
              onOpenMatchProfile: onOpenMatchProfile,
            ),

            const SizedBox(height: 22),
            const SizedBox(height: 30),
            _CreditsSection(credits: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChips(List<String> skills) {
    if (skills.isEmpty) {
      return Text(
        'No skills added yet.',
        style: AppTheme.labelStyle.copyWith(color: AppTheme.textMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((s) {
        return Chip(
          label: Text(
            s,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: AppTheme.primaryPurple.withAlpha(110),
              width: 1,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MatchesSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MockMatch> matches;
  final ValueChanged<MockMatch> onOpenMatchProfile;

  const _MatchesSection({
    required this.title,
    required this.subtitle,
    required this.matches,
    required this.onOpenMatchProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.headingSmall.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.subtitleStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withAlpha(14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.primaryPurple.withAlpha(55),
                  width: 1,
                ),
              ),
              child: Text(
                '${matches.length} matches',
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final m = matches[index];
              return _MatchCard(
                match: m,
                onOpenMatchProfile: onOpenMatchProfile,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TeacherRatingGraph extends StatelessWidget {
  const _TeacherRatingGraph();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FirestoreService.streamCurrentUserProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
          );
        }

        final data = snapshot.data!;
        final historyRaw = data['ratingHistory'] as List<dynamic>? ?? [4.5];
        final history = historyRaw.map((e) => (e as num).toDouble()).toList();

        // Ensure there's at least one point to draw a line
        if (history.length == 1) {
          history.insert(0, history.first); // Duplicate to draw a flat line
        }

        // Limit to last 10 ratings for graph clarity
        final displayHistory =
            history.length > 10 ? history.sublist(history.length - 10) : history;

        final spots = List.generate(
          displayHistory.length,
          (i) => FlSpot(i.toDouble(), displayHistory[i]),
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Rating Trend',
                    style: AppTheme.headingSmall.copyWith(fontSize: 18),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC857), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          (data['rating'] as num?)?.toStringAsFixed(1) ?? '4.5',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Recent feedback from learners',
                style: AppTheme.subtitleStyle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withAlpha(40),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value > 5) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (displayHistory.length - 1).toDouble(),
                    minY: 1,
                    maxY: 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.primaryPurple,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: AppTheme.primaryPurple,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryPurple.withAlpha(30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MockMatch match;
  final ValueChanged<MockMatch> onOpenMatchProfile;

  const _MatchCard({
    required this.match,
    required this.onOpenMatchProfile,
  });

  @override
  Widget build(BuildContext context) {
    // Generate experience progress bar visually (like ███████░░)
    final double maxExp = 10.0;
    final double expPercent = (match.user.experienceYears / maxExp).clamp(0.0, 1.0);
    
    return GestureDetector(
      onTap: () => onOpenMatchProfile(match),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withAlpha(15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: match.user.avatarColor.withAlpha(220),
                  child: Text(
                    initialsForName(match.user.name),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.user.name,
                        style: AppTheme.headingSmall.copyWith(fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            match.user.rating.toStringAsFixed(1),
                            style: AppTheme.labelStyle.copyWith(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Match Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: match.user.avatarColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${match.matchScore}% Match',
                    style: AppTheme.labelStyle.copyWith(
                      color: match.user.avatarColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Skill Info
            Text(
              match.tag == 'Can Teach You' 
                  ? 'Teaches: ${match.user.skillsToTeach.join(', ')}'
                  : 'Wants to learn: ${match.user.skillsToLearn.join(', ')}',
              style: AppTheme.labelStyle.copyWith(
                fontSize: 13.5,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            
            // Level & Experience
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.user.skillLevel,
                    style: AppTheme.labelStyle.copyWith(
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Text(
              'Skill Strength',
              style: AppTheme.labelStyle.copyWith(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: expPercent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(match.user.avatarColor),
              ),
            ),
            const SizedBox(height: 16),
            
            // Extra Info
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${match.user.experienceYears} yrs exp',
                      style: AppTheme.labelStyle.copyWith(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${match.user.sessionsCompleted} sessions',
                      style: AppTheme.labelStyle.copyWith(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            
            const Spacer(),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpenMatchProfile(match),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: match.user.avatarColor,
                      side: BorderSide(color: match.user.avatarColor.withAlpha(100), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onOpenMatchProfile(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: match.user.avatarColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _QuickActions extends StatelessWidget {
  final IntentMode intent;
  final ValueChanged<String> onAction;
  final List<String> skillsToLearn;
  final List<MockMatch> allMatches;
  final ValueChanged<MockMatch> onOpenMatchProfile;

  const _QuickActions({
    required this.intent,
    required this.onAction,
    required this.skillsToLearn,
    required this.allMatches,
    required this.onOpenMatchProfile,
  });

  void _showFindMatchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FindMatchSheet(
        skillsToLearn: skillsToLearn,
        allMatches: allMatches,
        onOpenMatchProfile: onOpenMatchProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Find Match',
                icon: Icons.search_rounded,
                onTap: () => _showFindMatchSheet(context),
              ),
            ),
            if (intent == IntentMode.teach) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Teach Now',
                  icon: Icons.lightbulb_rounded,
                  onTap: () => onAction('Teach Now'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Find Match Bottom Sheet ───────────────────────────────────────────────────
class _FindMatchSheet extends StatefulWidget {
  final List<String> skillsToLearn;
  final List<MockMatch> allMatches;
  final ValueChanged<MockMatch> onOpenMatchProfile;

  const _FindMatchSheet({
    required this.skillsToLearn,
    required this.allMatches,
    required this.onOpenMatchProfile,
  });

  @override
  State<_FindMatchSheet> createState() => _FindMatchSheetState();
}

class _FindMatchSheetState extends State<_FindMatchSheet> {
  String? _selectedSkill;

  List<MockMatch> get _filteredMentors {
    if (_selectedSkill == null) return [];
    final skill = _selectedSkill!.toLowerCase();
    return widget.allMatches.where((m) {
      return m.user.skillsToTeach.any((s) => s.toLowerCase() == skill);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mentors = _filteredMentors;
    final learnSkills = widget.skillsToLearn.isEmpty
        ? const ['Add skills to learn first']
        : widget.skillsToLearn;
    final hasRealSkills = widget.skillsToLearn.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 6),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withAlpha(50),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.search_rounded,
                              color: AppTheme.primaryPurple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Find a Mentor',
                                style: AppTheme.headingSmall.copyWith(fontSize: 20)),
                            Text('Which skill do you want to learn today?',
                                style: AppTheme.subtitleStyle.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Skill chips
                    Text('Your learning skills',
                        style: AppTheme.labelStyle.copyWith(
                            color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: learnSkills.map((skill) {
                        final isSelected = _selectedSkill == skill;
                        return GestureDetector(
                          onTap: hasRealSkills
                              ? () => setState(() {
                                    _selectedSkill = isSelected ? null : skill;
                                  })
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryPurple
                                  : AppTheme.primaryPurple.withAlpha(12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : AppTheme.primaryPurple.withAlpha(55),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  skill,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Mentor list header
                    if (_selectedSkill != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mentors for \'$_selectedSkill\'',
                              style: AppTheme.headingSmall.copyWith(fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withAlpha(14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${mentors.length} found',
                              style: AppTheme.labelStyle.copyWith(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),

              // Mentor list
              Expanded(
                child: _selectedSkill == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 48,
                                color: AppTheme.primaryPurple.withAlpha(80)),
                            const SizedBox(height: 12),
                            Text('Tap a skill above to\nsee available mentors',
                                textAlign: TextAlign.center,
                                style: AppTheme.subtitleStyle),
                          ],
                        ),
                      )
                    : mentors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 48,
                                    color: AppTheme.primaryPurple.withAlpha(60)),
                                const SizedBox(height: 12),
                                Text(
                                    'No mentors found for\n\'$_selectedSkill\' yet.',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.subtitleStyle),
                                const SizedBox(height: 8),
                                Text('Check back later!',
                                    style: AppTheme.labelStyle.copyWith(
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                            itemCount: mentors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final m = mentors[i];
                              return _MentorListTile(
                                match: m,
                                targetSkill: _selectedSkill!,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenMatchProfile(m);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Mentor List Tile (inside Find Match sheet) ────────────────────────────────
class _MentorListTile extends StatelessWidget {
  final MockMatch match;
  final String targetSkill;
  final VoidCallback onTap;

  const _MentorListTile({
    required this.match,
    required this.targetSkill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final u = match.user;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withAlpha(12), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: u.avatarColor.withAlpha(220),
              child: Text(
                initialsForName(u.name),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      style: AppTheme.headingSmall.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC857), size: 13),
                      const SizedBox(width: 3),
                      Text(u.rating.toStringAsFixed(1),
                          style: AppTheme.labelStyle.copyWith(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: AppTheme.textMuted,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('${u.sessionsCompleted} sessions',
                          style: AppTheme.labelStyle.copyWith(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Skill match badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Teaches: $targetSkill',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Match score + arrow
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: u.avatarColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${match.matchScore}%',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: u.avatarColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.buttonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withAlpha(35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTheme.buttonTextStyle.copyWith(
                fontSize: 14.5,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final IntentMode intent;
  final ValueChanged<IntentMode> onIntentChanged;
  const _Greeting({required this.intent, required this.onIntentChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Hey 👋',
          style: AppTheme.headlineStyle.copyWith(fontSize: 30),
        ),
        const Spacer(),
        // Notification bell with live badge
        StreamBuilder<int>(
          stream: SessionService.streamPendingCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 420),
                    pageBuilder: (_, __, ___) => SessionRequestsScreen(intent: intent),
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
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_rounded,
                      color: AppTheme.deepPurple,
                      size: 22,
                    ),
                    if (count > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        _IntentPill(intent: intent),
      ],
    );
  }
}

class _IntentPill extends StatelessWidget {
  final IntentMode intent;
  const _IntentPill({required this.intent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.primaryPurple.withAlpha(60),
          width: 1,
        ),
      ),
      child: Text(
        intent.label,
        style: AppTheme.labelStyle.copyWith(
          color: AppTheme.primaryPurple,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search skills or people',
          hintStyle: AppTheme.labelStyle.copyWith(fontSize: 13),
          border: InputBorder.none,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
          suffixIcon: controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted),
                ),
        ),
      ),
    );
  }
}



class _CreditsSection extends StatelessWidget {
  final int credits;
  const _CreditsSection({required this.credits});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppTheme.primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your Credits: $credits',
              style: AppTheme.headingSmall.copyWith(fontSize: 18),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _MatchesTab extends StatelessWidget {
  final List<MockMatch> matches;
  final ValueChanged<MockMatch> onOpenMatchProfile;
  final VoidCallback onReload;
  final ValueChanged<String> onAction;

  const _MatchesTab({
    required this.matches,
    required this.onOpenMatchProfile,
    required this.onReload,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () async => onReload(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 88),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final m = matches[index];
            return _MatchRowCard(
              match: m,
              onOpen: () => onOpenMatchProfile(m),
            );
          },
        ),
      ),
    );
  }
}

class _MatchRowCard extends StatelessWidget {
  final MockMatch match;
  final VoidCallback onOpen;

  const _MatchRowCard({
    required this.match,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(9),
              blurRadius: 18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: match.user.avatarColor.withAlpha(220),
              child: Text(
                initialsForName(match.user.name),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.user.name,
                    style: AppTheme.headingSmall.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.matchSkill,
                    style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.matchReason,
                    style: AppTheme.subtitleStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: match.user.avatarColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: match.user.avatarColor.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${match.matchScore}%',
                    style: AppTheme.labelStyle.copyWith(
                      color: match.user.avatarColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  final ValueChanged<String> onAction;
  const _SessionsTab({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
              child: Text(
                'Sessions',
                style: AppTheme.headingSmall.copyWith(fontSize: 24),
              ),
            ),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Incoming'),
                  Tab(text: 'Sent'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  _IncomingRequestsList(),
                  _SentRequestsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequestsList extends StatelessWidget {
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
            child: Text('Error: ${snapshot.error}',
                style: AppTheme.subtitleStyle.copyWith(color: Colors.redAccent)),
          );
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textMuted.withAlpha(120)),
                const SizedBox(height: 12),
                Text('No incoming requests', style: AppTheme.subtitleStyle),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: requests.length,
          itemBuilder: (context, i) => _SessionRequestCard(
            request: requests[i],
            isIncoming: true,
          ),
        );
      },
    );
  }
}

class _SentRequestsList extends StatelessWidget {
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
            child: Text('Error: ${snapshot.error}',
                style: AppTheme.subtitleStyle.copyWith(color: Colors.redAccent)),
          );
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_rounded, size: 48, color: AppTheme.textMuted.withAlpha(120)),
                const SizedBox(height: 12),
                Text('No sent requests', style: AppTheme.subtitleStyle),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: requests.length,
          itemBuilder: (context, i) => _SessionRequestCard(
            request: requests[i],
            isIncoming: false,
          ),
        );
      },
    );
  }
}

class _SessionRequestCard extends StatelessWidget {
  final SessionRequest request;
  final bool isIncoming;
  const _SessionRequestCard({required this.request, required this.isIncoming});

  Color get _statusColor {
    switch (request.status) {
      case 'pending': return const Color(0xFFFFB347);
      case 'accepted': return const Color(0xFF4CAF50);
      case 'rejected': return Colors.redAccent;
      default: return AppTheme.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case 'pending': return Icons.schedule_rounded;
      case 'accepted': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String get _peerName => isIncoming ? request.fromName : request.toName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryPurple,
                child: Text(
                  _peerName.isNotEmpty ? _peerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontFamily: 'Outfit', fontWeight: FontWeight.w900,
                    fontSize: 16, color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_peerName, style: AppTheme.headingSmall.copyWith(fontSize: 15)),
                    Text(
                      isIncoming ? 'wants to connect' : 'request sent',
                      style: AppTheme.labelStyle.copyWith(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _statusColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 12, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      request.status[0].toUpperCase() + request.status.substring(1),
                      style: TextStyle(
                        fontFamily: 'Outfit', fontWeight: FontWeight.w800,
                        fontSize: 10, color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Info row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(Icons.auto_awesome_rounded, request.skill),
              _chip(Icons.schedule_rounded, request.slot),
              _chip(Icons.people_rounded, request.sessionType),
            ],
          ),
          const SizedBox(height: 10),
          // Actions
          if (isIncoming && request.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => SessionService.acceptRequest(request.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => SessionService.rejectRequest(request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          if (request.status == 'accepted')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoCallScreen(
                        channelName: request.channelName,
                        peerName: _peerName,
                        teacherUid: request.teacherUid,
                        isTeacher: FirebaseAuth.instance.currentUser?.uid ==
                            request.teacherUid,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text('Join Video Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryPurple),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(
            fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11,
            color: AppTheme.deepPurple,
          )),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final IntentMode intent;
  final ValueChanged<IntentMode> onIntentChanged;
  final List<String> selectedSkills;
  final int credits;
  final ValueChanged<String> onAction;

  const _ProfileTab({
    required this.intent,
    required this.onIntentChanged,
    required this.selectedSkills,
    required this.credits,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 88),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(9),
                  blurRadius: 18,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryPurple,
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FirebaseAuth.instance.currentUser?.displayName ??
                            FirebaseAuth.instance.currentUser?.email?.split('@').first ??
                            'User',
                        style: AppTheme.headingSmall.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$credits credits available',
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Active Role',
            style: AppTheme.headingSmall.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onIntentChanged(IntentMode.learn),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: intent == IntentMode.learn ? AppTheme.primaryPurple : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Learner',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: intent == IntentMode.learn ? Colors.white : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onIntentChanged(IntentMode.teach),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: intent == IntentMode.teach ? AppTheme.primaryPurple : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Teacher',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: intent == IntentMode.teach ? Colors.white : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Skills Snapshot',
            style: AppTheme.headingSmall.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedSkills.map((s) {
              return Chip(
                label: Text(
                  s,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: AppTheme.primaryPurple.withAlpha(110),
                    width: 1,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onAction('Edit profile (demo)'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(230),
                foregroundColor: AppTheme.primaryPurple,
                side: BorderSide(
                  color: AppTheme.primaryPurple.withAlpha(120),
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Edit profile',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                // Clear local data and sign out of Firebase
                await OnboardingPreferencesService().clear();
                await FirebaseAuth.instance.signOut();
                // Navigate to root — AuthGate will redirect to login
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF0F0),
                foregroundColor: Colors.redAccent,
                side: BorderSide(
                  color: Colors.redAccent.withAlpha(80),
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
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

class _UpcomingSessionsSheet extends StatelessWidget {
  const _UpcomingSessionsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Upcoming Sessions',
                style: AppTheme.headingSmall.copyWith(fontSize: 20),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SessionRequest>>(
            stream: SessionService.streamTeacherAcceptedSessions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.video_camera_back_outlined,
                          size: 48, color: AppTheme.textMuted.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text(
                        'No upcoming sessions found.',
                        style: AppTheme.labelStyle
                            .copyWith(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withAlpha(10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primaryPurple.withAlpha(30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppTheme.primaryPurple.withAlpha(40),
                                child: Text(
                                  session.fromName.isNotEmpty
                                      ? session.fromName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryPurple),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.fromName,
                                      style: AppTheme.labelStyle.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Text(
                                      'Learning: ${session.skill}',
                                      style: AppTheme.labelStyle.copyWith(
                                          fontSize: 13,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 16, color: AppTheme.primaryPurple),
                              const SizedBox(width: 8),
                              Text(
                                session.slot,
                                style: AppTheme.labelStyle
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoCallScreen(
                                        channelName: session.channelName,
                                        peerName: session.fromName,
                                        teacherUid: session.teacherUid,
                                        isTeacher: true,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Join Call'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

