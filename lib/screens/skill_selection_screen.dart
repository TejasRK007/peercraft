import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/intent_mode.dart';
import '../services/onboarding_preferences_service.dart';
import 'home_screen.dart';

class SkillSelectionScreen extends StatefulWidget {
  final IntentMode intent;

  const SkillSelectionScreen({super.key, required this.intent});

  @override
  State<SkillSelectionScreen> createState() => _SkillSelectionScreenState();
}

class _SkillSelectionScreenState extends State<SkillSelectionScreen>
    with TickerProviderStateMixin {
  final _prefs = OnboardingPreferencesService();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  final List<String> _selectedSkills = [];

  bool _isSaving = false;

  // Primary (card) skills.
  static const List<_PrimarySkill> _primarySkills = [
    _PrimarySkill('Python', Icons.code_rounded, color: Color(0xFF7C5CFC)),
    _PrimarySkill(
      'Web Development',
      Icons.web_rounded,
      color: Color(0xFF4A2FA3),
    ),
    _PrimarySkill('Flutter', Icons.phone_android_rounded,
        color: Color(0xFF2D1B69)),
    _PrimarySkill('UI/UX Design', Icons.design_services_rounded,
        color: Color(0xFF7C5CFC)),
    _PrimarySkill(
      'Public Speaking',
      Icons.mic_rounded,
      color: Color(0xFFFF7B54),
    ),
    _PrimarySkill('Guitar', Icons.music_note_rounded,
        color: Color(0xFFB39DDB)),
    _PrimarySkill(
      'Video Editing',
      Icons.video_library_rounded,
      color: Color(0xFF7C5CFC),
    ),
    _PrimarySkill('Data Science', Icons.analytics_rounded,
        color: Color(0xFF4A2FA3)),
    _PrimarySkill('Photography', Icons.camera_alt_rounded,
        color: Color(0xFFFF7B54)),
    _PrimarySkill('Dance', Icons.directions_run_rounded,
        color: Color(0xFF2D1B69)),
  ];

  // Secondary (dropdown) skills.
  static const List<String> _moreSkillOptions = [
    'React',
    'Java',
    'C++',
    'AI/ML',
    'Cybersecurity',
    'DevOps',
    'Blockchain',
    'Aptitude',
    'Interview Prep',
    'Resume Building',
    'Communication Skills',
    'Singing',
    'Drawing',
    'Chess',
    'Marketing',
  ];

  String get _subtitle {
    switch (widget.intent) {
      case IntentMode.learn:
        return 'What do you want to learn?';
      case IntentMode.teach:
        return 'What can you teach?';
      case IntentMode.both:
        return 'What do you want to learn?\nWhat can you teach?';
    }
  }

  bool get _canContinue => _selectedSkills.isNotEmpty && !_isSaving;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _togglePrimarySkill(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  void _addSkill(String skill) {
    final normalized = skill.trim();
    if (normalized.isEmpty) return;
    if (_selectedSkills.contains(normalized)) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedSkills.add(normalized));
  }

  Future<void> _onContinue() async {
    if (_selectedSkills.isEmpty) return;
    if (_isSaving) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    try {
      await _prefs.save(intent: widget.intent, selectedSkills: _selectedSkills);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (_, __, ___) => HomeScreen(
          selectedSkills: List<String>.from(_selectedSkills),
          intent: widget.intent,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
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
                FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
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
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Skills',
                        style: AppTheme.headlineStyle.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Text(
                          'Tap to select (you can pick multiple)',
                          style: AppTheme.labelStyle.copyWith(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _primarySkills.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1 / 0.92,
                          ),
                          itemBuilder: (context, index) {
                            final s = _primarySkills[index];
                            final selected = _selectedSkills.contains(s.name);
                            return _SkillCard(
                              skill: s.name,
                              icon: s.icon,
                              color: s.color,
                              isSelected: selected,
                              onTap: () => _togglePrimarySkill(s.name),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        _AddMoreSkillsSection(
                          onAddSkillPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (sheetContext) {
                                return _AddSkillModal(
                                  options: _moreSkillOptions,
                                  onAddSkill: (skill) {
                                    _addSkill(skill);
                                  },
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        Text(
                          'Selected Skills',
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 10),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: _selectedSkills.isEmpty
                              ? Text(
                                  'No skills selected yet.',
                                  key: const ValueKey('empty'),
                                  style: AppTheme.subtitleStyle,
                                )
                              : Wrap(
                                  key: const ValueKey('chips'),
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedSkills.map((skill) {
                                    return Chip(
                                      label: Text(
                                        skill,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        side: BorderSide(
                                          color: AppTheme.primaryPurple
                                              .withAlpha(110),
                                          width: 1,
                                        ),
                                      ),
                                      deleteIcon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppTheme.primaryPurple,
                                      ),
                                      onDeleted: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedSkills.remove(skill));
                                      },
                                    );
                                  }).toList(),
                                ),
                        ),

                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        gradient: _canContinue
                            ? AppTheme.buttonGradient
                            : const LinearGradient(
                                colors: [Color(0xFFCEC8E4), Color(0xFFCEC8E4)],
                              ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: _canContinue
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2D1B69).withAlpha(70),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _canContinue ? _onContinue : null,
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Continue',
                                      style: AppTheme.buttonTextStyle,
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(30),
                                        borderRadius:
                                            BorderRadius.circular(50),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final String skill;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillCard({
    required this.skill,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isSelected ? 10 : 6),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(25) : color.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Icon(icon,
                  color: isSelected ? color : AppTheme.deepPurple, size: 20),
            ),
            const Spacer(),
            Text(
              skill,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w800,
                fontSize: 13.8,
                color: AppTheme.textDark,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMoreSkillsSection extends StatelessWidget {
  final VoidCallback onAddSkillPressed;

  const _AddMoreSkillsSection({required this.onAddSkillPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(160),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Didn't find your skill?",
              style: AppTheme.headingSmall.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAddSkillPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Add Skill',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _AddSkillModal extends StatefulWidget {
  final List<String> options;
  final ValueChanged<String> onAddSkill;

  const _AddSkillModal({
    required this.options,
    required this.onAddSkill,
  });

  @override
  State<_AddSkillModal> createState() => _AddSkillModalState();
}

class _AddSkillModalState extends State<_AddSkillModal> {
  String? _dropdownValue;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustom() {
    final text = _customController.text;
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    widget.onAddSkill(normalized);
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withAlpha(30),
              blurRadius: 28,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add a Skill',
                style: AppTheme.headingSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Pick from the list or type your own.',
                style: AppTheme.subtitleStyle,
              ),
              const SizedBox(height: 18),

              Text(
                'Popular skills',
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _dropdownValue,
                    hint: const Text('Select a skill'),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    style: AppTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                    ),
                    items: widget.options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      widget.onAddSkill(v);
                      setState(() => _dropdownValue = null);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                'Custom skill',
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withAlpha(110),
                          width: 1.1,
                        ),
                      ),
                      child: TextField(
                        controller: _customController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Competitive Programming',
                          hintStyle: AppTheme.labelStyle,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addCustom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimarySkill {
  final String name;
  final IconData icon;
  final Color color;

  const _PrimarySkill(
    this.name,
    this.icon, {
    required this.color,
  });
}

