import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/intent_mode.dart';
import '../services/onboarding_preferences_service.dart';
import 'skill_selection_screen.dart';

class IntentSelectionScreen extends StatefulWidget {
  const IntentSelectionScreen({super.key});

  @override
  State<IntentSelectionScreen> createState() => _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends State<IntentSelectionScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _entranceController;
  late final AnimationController _buttonController;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _titleSlide;
  late final Animation<Offset> _card1Slide;
  late final Animation<Offset> _card2Slide;
  late final Animation<Offset> _card3Slide;
  late final Animation<double> _buttonScale;

  // ── Selection state ───────────────────────────────────────────────────────
  bool _learnSelected = false;
  bool _teachSelected = false;

  final _prefs = OnboardingPreferencesService();
  bool _isNavigating = false;

  bool get _anySelected => _learnSelected || _teachSelected;

  IntentMode get _resolvedIntent {
    if (_learnSelected && _teachSelected) return IntentMode.both;
    if (_teachSelected) return IntentMode.teach;
    return IntentMode.learn;
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));

    _card1Slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _card2Slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.95, curve: Curves.easeOutCubic),
    ));

    _card3Slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  // ── Select an intent option ───────────────────────────────────────────────
  void _toggle(IntentMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      final isSameOption = (mode == IntentMode.learn && _learnSelected && !_teachSelected) ||
          (mode == IntentMode.teach && _teachSelected && !_learnSelected) ||
          (mode == IntentMode.both && _learnSelected && _teachSelected);

      if (isSameOption) {
        _learnSelected = false;
        _teachSelected = false;
        return;
      }

      _learnSelected = mode.includesLearn;
      _teachSelected = mode.includesTeach;
    });
  }

  // ── Navigate to Skill Setup ───────────────────────────────────────────────
  Future<void> _onContinue() async {
    if (!_anySelected || _isNavigating) return;
    HapticFeedback.lightImpact();

    setState(() => _isNavigating = true);

    await _buttonController.forward();
    await _buttonController.reverse();

    // Persist intent selection locally (skills will be saved next screen).
    await _prefs.save(intent: _resolvedIntent, selectedSkills: const []);

    if (!mounted) return;

    // Small loading indicator between screens (demo-friendly).
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future<void>.delayed(const Duration(milliseconds: 420), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return const _SmallLoadingDialog(message: 'Preparing your matches...');
      },
    );

    if (!mounted) return;
    setState(() => _isNavigating = false);

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, animation, __) =>
            SkillSelectionScreen(intent: _resolvedIntent),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
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
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Back arrow ────────────────────────────────────────
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

                    const SizedBox(height: 36),

                    // ── Title ─────────────────────────────────────────────
                    SlideTransition(
                      position: _titleSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What do you want\nto do today?',
                            style: AppTheme.headlineStyle,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose your path to get started.\nYou can always change this later.',
                            style: AppTheme.subtitleStyle,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Learn card ────────────────────────────────────────
                    SlideTransition(
                      position: _card1Slide,
                      child: _IntentCard(
                        isSelected: _learnSelected,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C5CFC), Color(0xFF9B7DFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconBgColor: const Color(0xFFEDE7FF),
                        icon: Icons.school_rounded,
                        iconColor: const Color(0xFF7C5CFC),
                        emoji: '📚',
                        title: 'Learn a Skill',
                        description:
                            'Find peers who can teach you what you love.',
                        tag: 'Explorer',
                        tagColor: const Color(0xFF7C5CFC),
                        onTap: () => _toggle(IntentMode.learn),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Teach card ────────────────────────────────────────
                    SlideTransition(
                      position: _card2Slide,
                      child: _IntentCard(
                        isSelected: _teachSelected,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7B54), Color(0xFFFF9A7B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconBgColor: const Color(0xFFFFEDE7),
                        icon: Icons.lightbulb_rounded,
                        iconColor: const Color(0xFFFF7B54),
                        emoji: '💡',
                        title: 'Teach a Skill',
                        description:
                            'Share your knowledge and earn credits doing it.',
                        tag: 'Mentor',
                        tagColor: const Color(0xFFFF7B54),
                        onTap: () => _toggle(IntentMode.teach),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Both card (explicit option) ────────────────────────────
                    SlideTransition(
                      position: _card3Slide,
                      child: _IntentCard(
                        isSelected: _learnSelected && _teachSelected,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C5CFC), Color(0xFF2D1B69)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconBgColor: const Color(0xFFEDE7FF),
                        icon: Icons.swap_horiz_rounded,
                        iconColor: AppTheme.primaryPurple,
                        emoji: '🔁',
                        title: 'Both',
                        description: 'Learn from others and teach what you know.',
                        tag: 'Learner & Mentor',
                        tagColor: AppTheme.primaryPurple,
                        onTap: () => _toggle(IntentMode.both),
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 12),

                    // ── Selection hint ────────────────────────────────────
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _anySelected ? 1.0 : 0.0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withAlpha(15),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            _learnSelected && _teachSelected
                                ? '✨ Learner & Mentor — great combo!'
                                : _learnSelected
                                    ? '📚 You\'ll be matched with mentors'
                                    : '💡 You\'ll share knowledge with peers',
                            style: AppTheme.labelStyle.copyWith(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Continue button ───────────────────────────────────
                    AnimatedBuilder(
                      animation: _buttonScale,
                      builder: (_, child) => Transform.scale(
                        scale: _buttonScale.value,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _anySelected ? _onContinue : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: _anySelected
                                ? AppTheme.buttonGradient
                                : const LinearGradient(colors: [
                                    Color(0xFFCEC8E4),
                                    Color(0xFFCEC8E4),
                                  ]),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: _anySelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2D1B69)
                                          .withAlpha(70),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: AppTheme.buttonTextStyle,
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallLoadingDialog extends StatelessWidget {
  final String message;

  const _SmallLoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      elevation: 0,
      backgroundColor: Colors.white.withAlpha(235),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      content: SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.headingSmall.copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intent Card widget
// ─────────────────────────────────────────────────────────────────────────────

class _IntentCard extends StatelessWidget {
  final bool isSelected;
  final LinearGradient gradient;
  final Color iconBgColor;
  final IconData icon;
  final Color iconColor;
  final String emoji;
  final String title;
  final String description;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _IntentCard({
    required this.isSelected,
    required this.gradient,
    required this.iconBgColor,
    required this.icon,
    required this.iconColor,
    required this.emoji,
    required this.title,
    required this.description,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isSelected ? iconBgColor : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? iconColor.withAlpha(45)
                  : Colors.black.withAlpha(12),
              blurRadius: isSelected ? 24 : 12,
              offset: const Offset(0, 6),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Icon bubble ───────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: isSelected ? gradient : null,
                color: isSelected ? null : iconBgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: iconColor.withAlpha(55),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),

            const SizedBox(width: 18),

            // ── Text content ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      // ── Check badge ───────────────────────────────────
                      AnimatedScale(
                        scale: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.elasticOut,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.labelStyle.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  // Role tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tagColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
