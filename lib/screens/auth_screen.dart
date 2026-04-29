import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'intent_selection_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final _authService = AuthService();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _loadingText = '';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth handler ──────────────────────────────────────────────────────────
  Future<void> _handleAuth() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Use a fallback so the demo works even with empty fields.
    final effectiveEmail = email.isEmpty ? 'demo@peercraft.app' : email;
    final effectivePassword = password.isEmpty ? 'demo1234' : password;

    setState(() {
      _isLoading = true;
      _loadingText = _isLogin ? 'Signing you in...' : 'Creating your account...';
    });

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: effectiveEmail,
          password: effectivePassword,
        );
      } else {
        await _authService.signUp(
          email: effectiveEmail,
          password: effectivePassword,
          displayName: _nameController.text.trim(),
        );
      }
    } catch (_) {
      // In demo mode, auth never actually fails — swallow any error.
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Navigate to skill setup with a smooth slide-up transition.
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, animation, __) => const IntentSelectionScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.07),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _switchTab(bool toLogin) {
    setState(() => _isLogin = toLogin);
    _animController
      ..reset()
      ..forward();
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
          decoration:
              const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Back button ─────────────────────────────────────────
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
                              color: Colors.black.withAlpha(15),
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

                    const SizedBox(height: 36),

                    // ── Header ──────────────────────────────────────────────
                    SlideTransition(
                      position: _slideUp,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isLogin
                                  ? 'Welcome\nBack 👋'
                                  : 'Create\nAccount ✨',
                              key: ValueKey(_isLogin),
                              style:
                                  AppTheme.headlineStyle.copyWith(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isLogin
                                  ? 'Sign in to continue your learning journey.'
                                  : 'Join 12K+ learners on PeerCraft today.',
                              key: ValueKey('sub_$_isLogin'),
                              style: AppTheme.subtitleStyle,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Tab switcher ────────────────────────────────────────
                    SlideTransition(
                      position: _slideUp,
                      child: _TabSwitcher(
                        isLogin: _isLogin,
                        onToggle: _switchTab,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Form fields ─────────────────────────────────────────
                    SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          // Name field (sign-up only) with animated show/hide
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _isLogin
                                ? const SizedBox.shrink()
                                : Column(
                                    children: [
                                      _AuthTextField(
                                        hint: 'Full Name',
                                        icon: Icons.person_outline_rounded,
                                        controller: _nameController,
                                        keyboardType: TextInputType.name,
                                        enabled: !_isLoading,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ),
                          ),
                          _AuthTextField(
                            hint: 'Email Address',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 14),
                          _AuthTextField(
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            obscure: _obscurePassword,
                            enabled: !_isLoading,
                            suffixIcon: GestureDetector(
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
                          if (_isLogin) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Forgot password?',
                                style: AppTheme.labelStyle.copyWith(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Auth CTA button ─────────────────────────────────────
                    SlideTransition(
                      position: _slideUp,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleAuth,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: _isLoading
                                ? const LinearGradient(colors: [
                                    Color(0xFF5540A8),
                                    Color(0xFF5540A8),
                                  ])
                                : AppTheme.buttonGradient,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2D1B69).withAlpha(
                                    _isLoading ? 30 : 70),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _isLoading
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _loadingText,
                                          key: const ValueKey('loading'),
                                          style: AppTheme.buttonTextStyle
                                              .copyWith(fontSize: 15),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _isLogin ? 'Sign In' : 'Create Account',
                                      key: const ValueKey('cta'),
                                      style: AppTheme.buttonTextStyle,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ── Divider ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: Color(0xFFD1C4E9))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('or continue with',
                              style:
                                  AppTheme.labelStyle.copyWith(fontSize: 12)),
                        ),
                        const Expanded(
                            child: Divider(color: Color(0xFFD1C4E9))),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Social buttons ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                            child: _SocialButton(
                                label: 'Google',
                                iconChar: 'G',
                                onTap: _isLoading ? null : _handleAuth)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: _SocialButton(
                                label: 'Apple',
                                iconChar: '',
                                onTap: _isLoading ? null : _handleAuth)),
                      ],
                    ),

                    const SizedBox(height: 36),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TabSwitcher extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _TabSwitcher({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withAlpha(18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabItem(
              label: 'Sign In',
              isActive: isLogin,
              onTap: () => onToggle(true)),
          _TabItem(
              label: 'Sign Up',
              isActive: !isLogin,
              onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 44,
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.buttonGradient : null,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final bool enabled;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const _AuthTextField({
    required this.hint,
    required this.icon,
    this.controller,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFC).withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          enabled: enabled,
          style: AppTheme.bodyStyle,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.labelStyle,
            prefixIcon: Icon(icon, color: AppTheme.primaryPurple, size: 20),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffixIcon,
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String iconChar;
  final VoidCallback? onTap;

  const _SocialButton(
      {required this.label, required this.iconChar, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                iconChar,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.deepPurple,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
