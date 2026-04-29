import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onboarding_preferences_service.dart';

import '../app_theme.dart';
import '../models/intent_mode.dart';
import '../models/mock_matching.dart';
import '../services/matching_service.dart';
import 'match_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<String> selectedSkills;
  final IntentMode intent;

  const HomeScreen({
    super.key,
    required this.selectedSkills,
    required this.intent,
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
    await Future.delayed(const Duration(milliseconds: 900));

    setState(() {
      _loadingStage = 'Finding best matches...';
    });
    await Future.delayed(const Duration(milliseconds: 850));

    final computed = getMatches(_currentIntent, widget.selectedSkills);
    if (!mounted) return;
    setState(() {
      _matches = computed;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
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
                      searchController: _searchController,
                      learnFromThem: learnFromThem,
                      teachThem: teachThem,
                      onReload: _loadMatches,
                      onOpenMatchProfile: _openMatchProfile,
                      onQuickAction: (action) {
                        if (action == 'Find Match') {
                          _loadMatches();
                          return;
                        }
                        if (action == 'Start Session') {
                          if (_matches.isEmpty) {
                            _showSnack('No matches yet. Tap Find Match.');
                            return;
                          }
                          _openMatchProfile(_matches.first);
                          return;
                        }
                        if (action == 'Teach Now') {
                          _showSnack('Teach Now (demo)');
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
                    'Using mock data — matching updates instantly.',
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
            _MatchesSection(
              title: section.$1,
              subtitle: section.$2,
              matches: section.$3,
              onOpenMatchProfile: onOpenMatchProfile,
            ),

            const SizedBox(height: 22),

            Text(
              'Your Skills',
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

            const SizedBox(height: 22),

            Text(
              'Quick Actions',
              style: AppTheme.headingSmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            _QuickActions(onAction: onQuickAction),

            const SizedBox(height: 22),
            const SizedBox(height: 30),
            _CreditsSection(credits: 100),
          ],
        ),
      ),
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
  final ValueChanged<String> onAction;
  const _QuickActions({required this.onAction});

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
                onTap: () => onAction('Find Match'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Start Session',
                icon: Icons.history_rounded,
                onTap: () => onAction('Start Session'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'Teach Now',
          icon: Icons.lightbulb_rounded,
          onTap: () => onAction('Teach Now'),
        ),
      ],
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 88),
        children: [
          Text(
            'Sessions',
            style: AppTheme.headingSmall.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 12),
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
            child: Text(
              'Session requests and schedules will appear here. (Demo placeholder)',
              style: AppTheme.subtitleStyle,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => onAction('Start a session (demo)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Start Session',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
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
                        'Tejas',
                        style: AppTheme.headingSmall.copyWith(fontSize: 18),
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
                // The StreamBuilder in main.dart will automatically catch this and redirect to OnboardingScreen!
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

