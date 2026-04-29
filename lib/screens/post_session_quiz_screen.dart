import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../data/skill_quiz_questions.dart';
import '../services/firestore_service.dart';

class PostSessionQuizScreen extends StatefulWidget {
  final String skill;
  final String teacherUid;
  final String teacherName;

  const PostSessionQuizScreen({
    super.key,
    required this.skill,
    required this.teacherUid,
    required this.teacherName,
  });

  @override
  State<PostSessionQuizScreen> createState() => _PostSessionQuizScreenState();
}

class _PostSessionQuizScreenState extends State<PostSessionQuizScreen>
    with SingleTickerProviderStateMixin {
  late final List<QuizQuestion> _questions;
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _finished = false;
  bool _processing = false;

  static const int _totalSeconds = 15 * 60;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  late AnimationController _slideAnim;

  @override
  void initState() {
    super.initState();
    _questions = getQuestionsForSkill(widget.skill);
    _slideAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _startTimer();
    _slideAnim.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideAnim.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) _finishQuiz();
    });
  }

  void _selectOption(int idx) {
    if (_answered || _finished) return;
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
      _slideAnim.forward(from: 0);
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();
    if (_finished) return;
    setState(() => _finished = true);
    _showResultAndProcess();
  }

  Future<void> _showResultAndProcess() async {
    final passed = _score > 5;
    setState(() => _processing = true);

    try {
      if (passed) {
        // Transfer 10 credits: learner → teacher
        await FirestoreService.processSessionCredits(
          teacherUid: widget.teacherUid,
          creditsToTransfer: 10,
        );
        // Notify teacher: passed
        await FirestoreService.sendNotification(
          toUid: widget.teacherUid,
          title: '🎉 Learner Passed!',
          body:
              'Your learner passed the post-session test on "${widget.skill}" and you received 10 credits!',
        );
      } else {
        // No credit change, but notify teacher: failed
        await FirestoreService.sendNotification(
          toUid: widget.teacherUid,
          title: '⚠️ Learner Below Minimum',
          body:
              'Your learner scored below the minimum on "${widget.skill}". No credits were transferred this time.',
        );
      }
    } catch (e) {
      debugPrint('[PostSessionQuiz] Error processing credits: $e');
    }

    setState(() => _processing = false);

    if (!mounted) return;
    _showResultDialog(passed);
  }

  void _showResultDialog(bool passed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuizResultDialog(
        skill: widget.skill,
        score: _score,
        passed: passed,
        onDone: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pop(); // back to home
        },
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
    if (_processing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.primaryPurple),
            const SizedBox(height: 20),
            Text('Processing your results...', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text('Please wait a moment.', style: AppTheme.subtitleStyle),
          ]),
        ),
      );
    }

    if (_finished) return const SizedBox.shrink();

    final question = _questions[_questionIndex];
    final qProgress = (_questionIndex + 1) / _questions.length;

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
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Post-Session Test',
                                    style: AppTheme.headingSmall
                                        .copyWith(fontSize: 20)),
                                const SizedBox(height: 2),
                                Text(
                                  widget.skill,
                                  style: AppTheme.subtitleStyle.copyWith(
                                    fontSize: 13,
                                    color: AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Timer badge
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _timerColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(50),
                              border:
                                  Border.all(color: _timerColor.withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_rounded,
                                    color: _timerColor, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _timerStr,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w800,
                                    color: _timerColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Info banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF9800).withAlpha(100)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFFF9800), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Score > 5 → 10 credits transferred to your teacher',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      // Question progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: qProgress,
                          backgroundColor: Colors.white.withAlpha(100),
                          valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primaryPurple),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Question ${_questionIndex + 1} / ${_questions.length}',
                        style: AppTheme.labelStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Question + Options ───────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (_, child) => Opacity(
                        opacity: _slideAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - _slideAnim.value)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Question card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primaryPurple.withAlpha(18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              question.question,
                              style: AppTheme.headingSmall
                                  .copyWith(fontSize: 17, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Option buttons
                          ...List.generate(question.options.length, (i) {
                            Color bg = Colors.white;
                            Color borderColor = Colors.transparent;
                            Widget? trailing;

                            if (_answered) {
                              if (i == question.correctIndex) {
                                bg = const Color(0xFFE8F5E9);
                                borderColor = Colors.green;
                                trailing = const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 20);
                              } else if (i == _selectedOption) {
                                bg = const Color(0xFFFFEBEE);
                                borderColor = Colors.redAccent;
                                trailing = const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.redAccent,
                                    size: 20);
                              }
                            }

                            return GestureDetector(
                              onTap: () => _selectOption(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: borderColor, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(7),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple
                                          .withAlpha(15),
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
                                      style: AppTheme.bodyStyle.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (trailing != null) trailing,
                                ]),
                              ),
                            );
                          }),

                          const SizedBox(height: 10),
                          // Live score tally
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryPurple.withAlpha(12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppTheme.primaryPurple, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Score: $_score / ${_questionIndex + (_answered ? 1 : 0)}',
                                  style: AppTheme.labelStyle.copyWith(
                                    color: AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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

// ── Result Dialog ─────────────────────────────────────────────────────────────
class _QuizResultDialog extends StatelessWidget {
  final String skill;
  final int score;
  final bool passed;
  final VoidCallback onDone;

  const _QuizResultDialog({
    required this.skill,
    required this.score,
    required this.passed,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF4CAF50) : Colors.redAccent;
    final emoji = passed ? '🎉' : '😔';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              passed ? 'Test Passed! ✅' : 'Test Not Passed',
              style: AppTheme.headingSmall.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Skill: $skill',
              style: AppTheme.subtitleStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Score: $score / 10',
              style: AppTheme.subtitleStyle.copyWith(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Text(
                passed
                    ? '10 credits deducted from you\nand sent to your teacher 🏅'
                    : 'No credits transferred.\nKeep learning and try again! 💪',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: color,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
