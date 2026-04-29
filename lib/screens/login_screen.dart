import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';
import 'skill_selection_screen.dart';
import '../models/intent_mode.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Signup
  String? _emailError;
  String? _passwordError;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeIn = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool valid = true;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your Gmail');
      valid = false;
    } else if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      valid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      valid = false;
    }

    return valid;
  }

  Future<void> _onAuthAction() async {
    FocusScope.of(context).unfocus();
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Map common errors for better UX
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          _emailError = 'Incorrect email or password.';
        } else if (e.code == 'email-already-in-use') {
          _emailError = 'An account already exists for that email.';
        } else {
          _emailError = e.message ?? 'Authentication failed';
        }
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailError = 'An unexpected error occurred';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, __, ___) => const SkillSelectionScreen(intent: IntentMode.learn),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
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
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 36),

                      // ── Logo ──────────────────────────────────────────────
                      SlideTransition(
                        position: _slideUp,
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C5CFC), Color(0xFF4A2FA3)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C5CFC).withAlpha(80),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.hub_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'PeerCraft',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.deepPurple,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Sign In / Sign Up TAB TOGGLE ──────────────────────
                      SlideTransition(
                        position: _slideUp,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.lightLavender,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            children: [
                              // Sign In tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isLogin) {
                                      setState(() {
                                        _isLogin = true;
                                        _emailError = null;
                                        _passwordError = null;
                                      });
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: _isLogin ? AppTheme.buttonGradient : null,
                                      borderRadius: BorderRadius.circular(46),
                                      boxShadow: _isLogin
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF2D1B69).withAlpha(60),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Login',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: _isLogin
                                              ? Colors.white
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Sign Up tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_isLogin) {
                                      setState(() {
                                        _isLogin = false;
                                        _emailError = null;
                                        _passwordError = null;
                                      });
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: !_isLogin ? AppTheme.buttonGradient : null,
                                      borderRadius: BorderRadius.circular(46),
                                      boxShadow: !_isLogin
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF2D1B69).withAlpha(60),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: !_isLogin
                                              ? Colors.white
                                              : AppTheme.textMuted,
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

                      const SizedBox(height: 32),

                      // ── Subtitle ──────────────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Align(
                          key: ValueKey(_isLogin),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isLogin
                                ? 'Sign in to continue learning and teaching.'
                                : 'Join PeerCraft and start your journey.',
                            style: AppTheme.subtitleStyle,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Gmail field ───────────────────────────────────────
                      SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(label: 'Email Address'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _emailController,
                              hint: 'you@gmail.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailError,
                              onChanged: (_) {
                                if (_emailError != null) {
                                  setState(() => _emailError = null);
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Password field ────────────────────────────────────
                      SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(label: 'Password'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _passwordController,
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              errorText: _passwordError,
                              onChanged: (_) {
                                if (_passwordError != null) {
                                  setState(() => _passwordError = null);
                                }
                              },
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppTheme.textMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Forgot password (only in Sign In mode) ────────────
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {},
                            child: Text(
                              'Forgot password?',
                              style: AppTheme.labelStyle.copyWith(
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 36),

                      // ── Action button ──────────────────────────────────────
                      SlideTransition(
                        position: _slideUp,
                        child: _isLoading
                            ? _LoadingButton()
                            : _AuthButton(
                                title: _isLogin ? 'Login' : 'Sign In',
                                onTap: _onAuthAction,
                              ),
                      ),

                      const SizedBox(height: 24),

                      // ── Divider ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppTheme.textMuted.withAlpha(60),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or',
                              style: AppTheme.labelStyle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppTheme.textMuted.withAlpha(60),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Google Sign-In button ─────────────────────────────
                      _GoogleSignInButton(onTap: () {}),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError
                  ? Colors.redAccent.withAlpha(180)
                  : AppTheme.primaryPurple.withAlpha(hasError ? 180 : 40),
              width: hasError ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? Colors.redAccent.withAlpha(15)
                    : AppTheme.primaryPurple.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(icon,
                  color: hasError
                      ? Colors.redAccent
                      : AppTheme.primaryPurple.withAlpha(180),
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTheme.labelStyle.copyWith(fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 8),
                suffix!,
              ],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                errorText!,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _AuthButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppTheme.buttonGradient,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D1B69).withAlpha(70),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: AppTheme.buttonTextStyle,
          ),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1B69).withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: AppTheme.primaryPurple.withAlpha(50),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Icon(Icons.g_mobiledata_rounded,
                  color: Color(0xFFDB4437), size: 26),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: AppTheme.labelStyle.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
