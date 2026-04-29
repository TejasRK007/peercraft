import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/intent_mode.dart';
import '../services/onboarding_preferences_service.dart';
import 'skill_quiz_screen.dart';

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

  // Separate skill lists for Learn and Teach
  final List<String> _learnSkills = [];
  final List<String> _teachSkills = [];

  bool _isSaving = false;

  static const List<_PrimarySkill> _primarySkills = [
    _PrimarySkill('Python', Icons.code_rounded, color: Color(0xFF7C5CFC)),
    _PrimarySkill('Web Development', Icons.web_rounded, color: Color(0xFF4A2FA3)),
    _PrimarySkill('Flutter', Icons.phone_android_rounded, color: Color(0xFF2D1B69)),
    _PrimarySkill('UI/UX Design', Icons.design_services_rounded, color: Color(0xFF7C5CFC)),
    _PrimarySkill('Public Speaking', Icons.mic_rounded, color: Color(0xFFFF7B54)),
    _PrimarySkill('Guitar', Icons.music_note_rounded, color: Color(0xFFB39DDB)),
    _PrimarySkill('Video Editing', Icons.video_library_rounded, color: Color(0xFF7C5CFC)),
    _PrimarySkill('Data Science', Icons.analytics_rounded, color: Color(0xFF4A2FA3)),
    _PrimarySkill('Photography', Icons.camera_alt_rounded, color: Color(0xFFFF7B54)),
    _PrimarySkill('Dance', Icons.directions_run_rounded, color: Color(0xFF2D1B69)),
  ];

  static const List<String> _moreSkillOptions = [
    'React', 'Java', 'C++', 'AI/ML', 'Cybersecurity', 'DevOps',
    'Blockchain', 'Aptitude', 'Interview Prep', 'Resume Building',
    'Communication Skills', 'Singing', 'Drawing', 'Chess', 'Marketing',
  ];

  // Both sections are always required regardless of intent.
  bool get _canContinue =>
      _learnSkills.isNotEmpty && _teachSkills.isNotEmpty && !_isSaving;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleSkill(String skill, List<String> list) {
    HapticFeedback.selectionClick();
    setState(() {
      if (list.contains(skill)) {
        list.remove(skill);
      } else {
        list.add(skill);
      }
    });
  }

  void _addSkill(String skill, List<String> list) {
    final normalized = skill.trim();
    if (normalized.isEmpty || list.contains(normalized)) return;
    HapticFeedback.selectionClick();
    setState(() => list.add(normalized));
  }

  void _openAddModal(List<String> targetList, String sectionLabel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSkillModal(
        options: _moreSkillOptions,
        sectionLabel: sectionLabel,
        onAddSkill: (skill) => _addSkill(skill, targetList),
      ),
    );
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final learnList = List<String>.from(_learnSkills);
    final teachList = List<String>.from(_teachSkills);

    // Only save learn skills now; teach skills will be finalised after quiz
    try {
      await _prefs.saveSkills(
        intent: widget.intent,
        skillsToLearn: learnList,
        skillsToTeach: teachList,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;

    // Navigate to quiz — it will save final teach skills + levels
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (_, __, ___) => SkillQuizScreen(
          teachSkills: teachList,
          learnSkills: learnList,
          intent: widget.intent,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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
            child: Column(
              children: [
                // App bar
                FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: AppTheme.deepPurple, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Your Skills', style: AppTheme.headlineStyle.copyWith(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        'Add skills you want to learn AND skills you can teach — at least 1 from each.',
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── LEARN SECTION (always shown) ──
                        ...[
                          _SectionHeader(
                            icon: Icons.school_rounded,
                            color: const Color(0xFF7C5CFC),
                            label: 'Skills I Want to Learn',
                            subtitle: 'Pick topics you want to improve in',
                            count: _learnSkills.length,
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          _SkillGrid(
                            skills: _primarySkills,
                            selected: _learnSkills,
                            onToggle: (s) => _toggleSkill(s, _learnSkills),
                          ),
                          const SizedBox(height: 10),
                          _AddMoreBar(
                            color: const Color(0xFF7C5CFC),
                            onTap: () => _openAddModal(_learnSkills, 'Learn'),
                          ),
                          if (_learnSkills.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SelectedChips(
                              skills: _learnSkills,
                              color: const Color(0xFF7C5CFC),
                              onRemove: (s) => setState(() => _learnSkills.remove(s)),
                            ),
                          ],
                          const SizedBox(height: 22),
                        ],

                        // ── TEACH SECTION (always shown) ──
                        ...[
                          _SectionHeader(
                            icon: Icons.lightbulb_rounded,
                            color: const Color(0xFFFF7B54),
                            label: 'Skills I Can Teach',
                            subtitle: 'Pick topics you can mentor others in',
                            count: _teachSkills.length,
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          _SkillGrid(
                            skills: _primarySkills,
                            selected: _teachSkills,
                            onToggle: (s) => _toggleSkill(s, _teachSkills),
                            accentColor: const Color(0xFFFF7B54),
                          ),
                          const SizedBox(height: 10),
                          _AddMoreBar(
                            color: const Color(0xFFFF7B54),
                            onTap: () => _openAddModal(_teachSkills, 'Teach'),
                          ),
                          if (_teachSkills.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SelectedChips(
                              skills: _teachSkills,
                              color: const Color(0xFFFF7B54),
                              onRemove: (s) => setState(() => _teachSkills.remove(s)),
                            ),
                          ],
                          const SizedBox(height: 22),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Continue button
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
                            : const LinearGradient(colors: [Color(0xFFCEC8E4), Color(0xFFCEC8E4)]),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: _canContinue
                            ? [BoxShadow(color: const Color(0xFF2D1B69).withAlpha(70), blurRadius: 18, offset: const Offset(0, 8))]
                            : [],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _canContinue ? _onContinue : null,
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Continue', style: AppTheme.buttonTextStyle),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(50)),
                                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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

// ── Section Header ──────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final int count;
  final bool required;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                    ),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(999)),
                        child: Text('Required', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11, color: color)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTheme.subtitleStyle.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: count > 0 ? color : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$count', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 13, color: count > 0 ? Colors.white : AppTheme.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill Grid ──────────────────────────────────────────────
class _SkillGrid extends StatelessWidget {
  final List<_PrimarySkill> skills;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final Color accentColor;

  const _SkillGrid({
    required this.skills,
    required this.selected,
    required this.onToggle,
    this.accentColor = const Color(0xFF7C5CFC),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: skills.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1 / 0.88,
      ),
      itemBuilder: (context, index) {
        final s = skills[index];
        final isSelected = selected.contains(s.name);
        final color = isSelected ? accentColor : s.color;
        return GestureDetector(
          onTap: () => onToggle(s.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: isSelected ? color.withAlpha(38) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(isSelected ? 10 : 6), blurRadius: isSelected ? 16 : 10, offset: const Offset(0, 5))],
            ),
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? color.withAlpha(28) : s.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                  ),
                  child: Icon(s.icon, color: isSelected ? color : AppTheme.deepPurple, size: 19),
                ),
                const Spacer(),
                Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark, height: 1.2)),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 13),
                    const SizedBox(width: 4),
                    Text('Selected', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: color)),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Add More Bar ────────────────────────────────────────────
class _AddMoreBar extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _AddMoreBar({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(180),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(55), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text("Don't see your skill? Add a custom one", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.textDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text('Add', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selected Chips ──────────────────────────────────────────
class _SelectedChips extends StatelessWidget {
  final List<String> skills;
  final Color color;
  final ValueChanged<String> onRemove;
  const _SelectedChips({required this.skills, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Chip(
          label: Text(skill, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: color)),
          backgroundColor: color.withAlpha(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withAlpha(90), width: 1),
          ),
          deleteIcon: Icon(Icons.close_rounded, size: 16, color: color),
          onDeleted: () {
            HapticFeedback.selectionClick();
            onRemove(skill);
          },
        );
      }).toList(),
    );
  }
}

// ── Add Skill Modal ─────────────────────────────────────────
class _AddSkillModal extends StatefulWidget {
  final List<String> options;
  final String sectionLabel;
  final ValueChanged<String> onAddSkill;

  const _AddSkillModal({required this.options, required this.sectionLabel, required this.onAddSkill});

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
    final normalized = _customController.text.trim();
    if (normalized.isEmpty) return;
    widget.onAddSkill(normalized);
    _customController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$normalized" added to ${widget.sectionLabel}'), backgroundColor: AppTheme.primaryPurple, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLearn = widget.sectionLabel == 'Learn';
    final accentColor = isLearn ? const Color(0xFF7C5CFC) : const Color(0xFFFF7B54);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: accentColor.withAlpha(30), blurRadius: 28, offset: const Offset(0, -10))],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56, height: 6,
                  decoration: BoxDecoration(color: accentColor.withAlpha(60), borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: accentColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: Icon(isLearn ? Icons.school_rounded : Icons.lightbulb_rounded, color: accentColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Skill to ${widget.sectionLabel}', style: AppTheme.headingSmall),
                      Text('Pick from list or type your own', style: AppTheme.subtitleStyle.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('Popular skills', style: AppTheme.labelStyle.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _dropdownValue,
                    hint: const Text('Select a skill'),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                    style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w700, fontFamily: 'Outfit'),
                    items: widget.options.map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      widget.onAddSkill(v);
                      setState(() => _dropdownValue = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$v" added to ${widget.sectionLabel}'), backgroundColor: accentColor, duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text('Custom skill', style: AppTheme.labelStyle.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
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
                        border: Border.all(color: accentColor.withAlpha(110), width: 1.1),
                      ),
                      child: TextField(
                        controller: _customController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Competitive Programming',
                          hintStyle: AppTheme.labelStyle,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _addCustom(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addCustom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Add', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800)),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Done', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: accentColor)),
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
  const _PrimarySkill(this.name, this.icon, {required this.color});
}
