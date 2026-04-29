/// AuthService — frontend-only mock implementation.
///
/// All methods are designed to mirror a real auth surface so that
/// swapping this class for a real implementation later requires only changes
/// inside this file, not in any screen.
library;

import 'package:flutter/foundation.dart';

class AuthUser {
  final String email;
  final String? displayName;

  const AuthUser({required this.email, this.displayName});
}

class AuthService {
  /// Singleton so screens can share the same session state.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ── Session state ─────────────────────────────────────────────────────────
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // ── Mock sign-in ──────────────────────────────────────────────────────────
  /// Accepts any non-empty email and password.
  /// Simulates a 1-second network round-trip.
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1100));

    // TODO: Replace body with your real auth provider implementation:
    //   final credential = await AuthProvider.instance
    //       .signInWithEmailAndPassword(email: email, password: password);
    //   _currentUser = AuthUser(email: credential.user!.email!);

    _currentUser = AuthUser(email: email.trim());
    debugPrint('[AuthService] signed in as ${_currentUser!.email}');
    return _currentUser!;
  }

  // ── Mock sign-up ──────────────────────────────────────────────────────────
  /// Creates a demo account with any non-empty email and password.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1300));

    // TODO: Replace body with your real auth provider implementation:
    //   final credential = await AuthProvider.instance
    //       .createUserWithEmailAndPassword(email: email, password: password);
    //   await credential.user!.updateDisplayName(displayName);
    //   _currentUser = AuthUser(email: credential.user!.email!, displayName: displayName);

    _currentUser = AuthUser(email: email.trim(), displayName: displayName);
    debugPrint('[AuthService] created account for ${_currentUser!.email}');
    return _currentUser!;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _currentUser = null;
    // TODO: await AuthProvider.instance.signOut();
  }
}
