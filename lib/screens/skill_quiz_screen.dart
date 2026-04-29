import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../data/skill_quiz_questions.dart';
import '../models/intent_mode.dart';
import '../services/firestore_service.dart';
import '../services/onboarding_preferences_service.dart';
import 'home_screen.dart';

// ── Result model ─────────────────────────────────────────────
class SkillQuizResult {
  final String skill;
  final int score; // 0-10
  final String? level; // null = removed (score < 2)

  const SkillQuizResult({required this.skill, required this.score, this.level});

  static String? levelForScore(int score) {
    if (score < 2) return null;
    if (score <= 5) return 'Beginner';
    if (score <= 8) return 'Medium';
    return 'Advanced';
  }
}

// ── Entry point ───────────────────────────────────────────────
class SkillQuizScreen extends StatefulWidget {
  final List<String> teachSkills;
  final List<String> learnSkills;
  final IntentMode intent;

  const SkillQuizScreen({
    super.key,
    required this.teachSkills,
    required this.learnSkills,
    required this.intent,
  });

  @override
  State<SkillQuizScreen> createState() => _SkillQuizScreenState();
}

class _SkillQuizScreenState extends State<SkillQuizScreen>
    with SingleTickerProviderStateMixin {
  int _skillIndex = 0;
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _saving = false;

  // 15 minutes per skill
  static const int _totalSeconds = 15 * 60;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  final List<SkillQuizResult> _results = [];
  late List<QuizQuestion> _questions;

  late AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _loadSkill();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressAnim.dispose();
    super.dispose();
  }

  void _loadSkill() {
    final skill = widget.teachSkills[_skillIndex];
    _questions = getQuestionsForSkill(skill);
    _questionIndex = 0;
    _score = 0;
    _selectedOption = null;
    _answered = false;
    _secondsLeft = _totalSeconds;
    _startTimer();
    _progressAnim.forward(from: 0);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) _finishSkill();
    });
  }

  void _selectOption(int idx) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    final correct = _questions[_questionIndex].correctIndex;
    setState(() {
      _selectedOption = idx;
      _answered = true;
      if (idx == correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 900), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_questionIndex < _questions.length - 1) {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
        _answered = false;
      });
      _progressAnim.forward(from: 0);
    } else {
      _finishSkill();
    }
  }

  void _finishSkill() {
    _timer?.cancel();
    final skill = widget.teachSkills[_skillIndex];
    final level = SkillQuizResult.levelForScore(_score);
    setState(() {
      _results.add(SkillQuizResult(skill: skill, score: _score, level: level));
    });
    _showSkillResultDialog(skill, _score, level);
  }

  void _showSkillResultDialog(String skill, int score, String? level) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        skill: skill,
        score: score,
        level: level,
        isLast: _skillIndex == widget.teachSkills.length - 1,
        onNext: () {
          Navigator.of(context).pop();
          if (_skillIndex < widget.teachSkills.length - 1) {
            setState(() => _skillIndex++);
            _loadSkill();
          } else {
            _finishAll();
          }
        },
      ),
    );
  }

  Future<void> _finishAll() async {
    setState(() => _saving = true);

    // Filter skills: only those with score >= 2
    final passedSkills = _results.where((r) => r.level != null).map((r) => r.skill).toList();
    final levelMap = {for (final r in _results) if (r.level != null) r.skill: r.level!};

    final allSkills = {...widget.learnSkills, ...passedSkills}.toList();

    try {
      await Future.wait([
        OnboardingPreferencesService().saveSkills(
          intent: widget.intent,
          skillsToLearn: widget.learnSkills,
          skillsToTeach: passedSkills,
        ),
        FirestoreService.saveUserProfile(
          intent: widget.intent,
          skillsToLearn: widget.learnSkills,
          skillsToTeach: passedSkills,
        ),
        FirestoreService.saveSkillLevels(levelMap),
      ]);
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (_, __, ___) => HomeScreen(
          selectedSkills: allSkills,
          skillsToLearn: widget.learnSkills,
          skillsToTeach: passedSkills,
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

  String get _timerStr {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_secondsLeft > 300) return AppTheme.primaryPurple;
    if (_secondsLeft > 120) return const Color(0xFFFF9800);
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.primaryPurple),
            const SizedBox(height: 20),
            Text('Saving your results...', style: AppTheme.headingSmall),
          ]),
        ),
      );
    }

    final skill = widget.teachSkills[_skillIndex];
    final question = _questions[_questionIndex];
    final qProgress = (_questionIndex + 1) / _questions.length;
    final skillProgress = (_skillIndex + 1) / widget.teachSkills.length;

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
                // ── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(skill,
                                style: AppTheme.headingSmall.copyWith(fontSize: 20)),
                            Text(
                              'Skill ${_skillIndex + 1} of ${widget.teachSkills.length}',
                              style: AppTheme.subtitleStyle.copyWith(fontSize: 13),
                            ),
                          ]),
                          // Timer
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _timerColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _timerColor.withAlpha(80)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.timer_rounded, color: _timerColor, size: 16),
                              const SizedBox(width: 6),
                              Text(_timerStr,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w800,
                                    color: _timerColor,
                                    fontSize: 15,
                                  )),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Skill-level progress
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: skillProgress,
                          backgroundColor: Colors.white.withAlpha(100),
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryPurple),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Question progress
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: qProgress,
                          backgroundColor: Colors.white.withAlpha(60),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7B54)),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Question ${_questionIndex + 1} / ${_questions.length}',
                          style: AppTheme.labelStyle.copyWith(fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Question card ────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, child) => Opacity(
                        opacity: _progressAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _progressAnim.value)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Question
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPurple.withAlpha(18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              question.question,
                              style: AppTheme.headingSmall.copyWith(fontSize: 17, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Options
                          ...List.generate(question.options.length, (i) {
                            Color bg = Colors.white;
                            Color border = Colors.transparent;
                            Widget? trailingIcon;

                            if (_answered) {
                              if (i == question.correctIndex) {
                                bg = const Color(0xFFE8F5E9);
                                border = Colors.green;
                                trailingIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
                              } else if (i == _selectedOption) {
                                bg = const Color(0xFFFFEBEE);
                                border = Colors.redAccent;
                                trailingIcon = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
                              }
                            } else if (_selectedOption == i) {
                              border = AppTheme.primaryPurple;
                            }

                            return GestureDetector(
                              onTap: () => _selectOption(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(8),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withAlpha(15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        ['A', 'B', 'C', 'D'][i],
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryPurple,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      question.options[i],
                                      style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (trailingIcon != null) trailingIcon,
                                ]),
                              ),
                            );
                          }),

                          const SizedBox(height: 10),
                          // Score tally
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withAlpha(12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.star_rounded, color: AppTheme.primaryPurple, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Score: $_score / ${_questionIndex + (_answered ? 1 : 0)}',
                                style: AppTheme.labelStyle.copyWith(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ]),
                          ),
                        ],
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

// ── Result Dialog ─────────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final String skill;
  final int score;
  final String? level;
  final bool isLast;
  final VoidCallback onNext;

  const _ResultDialog({
    required this.skill,
    required this.score,
    required this.level,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final passed = level != null;
    final emoji = passed ? (level == 'Advanced' ? '🏆' : level == 'Medium' ? '🌟' : '✅') : '❌';
    final color = passed
        ? (level == 'Advanced'
            ? const Color(0xFF4CAF50)
            : level == 'Medium'
                ? const Color(0xFF2196F3)
                : const Color(0xFFFF9800))
        : Colors.redAccent;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 50)),
          const SizedBox(height: 12),
          Text(
            skill,
            style: AppTheme.headingSmall.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Score: $score / 10',
            style: AppTheme.subtitleStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Text(
              passed ? level! : 'Removed from teach list',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'Great job! This skill is added to your profile.'
                : 'Score below 2 — skill removed. Keep practicing!',
            textAlign: TextAlign.center,
            style: AppTheme.subtitleStyle.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isLast ? 'View My Profile 🎉' : 'Next Skill →',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
