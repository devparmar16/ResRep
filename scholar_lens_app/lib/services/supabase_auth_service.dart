import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for Google OAuth only (via Supabase Auth).
/// Email/password auth is handled by custom DB-based auth.
class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Sign in with Google OAuth.
  /// On web, dynamically detects the current URL so the redirect
  /// comes back to the correct Flutter dev server port.
  Future<bool> signInWithGoogle() async {
    // Get the current browser URL origin (e.g., http://localhost:56789)
    String? redirectUrl;
    if (kIsWeb) {
      final base = Uri.base;
      redirectUrl = '${base.scheme}://${base.host}:${base.port}';
    }

    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
  }

  /// Sign out from Google OAuth session (if any).
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore — user may not have a Supabase auth session
    }
  }

  /// Get the Google OAuth user (if signed in via Google).
  User? get currentUser => _client.auth.currentUser;

  /// Listen to auth state changes (for Google OAuth).
  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;
}
