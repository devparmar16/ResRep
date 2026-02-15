import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

/// Auth state management.
/// Uses local storage for custom email/password sessions.
/// Listens to Supabase auth changes for Google OAuth only.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  StreamSubscription? _authSub;

  static const _sessionKey = 'scholar_lens_user_id';

  AuthProvider({
    AuthRepository? authRepo,
    UserRepository? userRepo,
  })  : _authRepo = authRepo ?? AuthRepository(),
        _userRepo = userRepo ?? UserRepository() {
    _listenToGoogleAuth();
  }

  // ─── State ────────────────────────────────────────────
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // ─── Getters ──────────────────────────────────────────
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _profile != null;
  String? get userId => _profile?.id;

  bool get needsOnboarding =>
      _profile != null && !_profile!.hasSelectedDomains;

  /// Whether the user needs to fill in missing profile fields.
  bool get needsProfileCompletion =>
      _profile != null && _profile!.needsProfileCompletion;

  /// Map of missing field labels to DB column keys.
  Map<String, String> get missingFields =>
      _profile?.missingFields ?? {};

  // ─── Google OAuth Listener ─────────────────────────────
  void _listenToGoogleAuth() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        if (data.event == AuthChangeEvent.signedIn) {
          final user = data.session?.user;
          if (user != null && _profile == null) {
            // Google OAuth signed in — load or create profile in login table
            try {
              var profile = await _authRepo.getProfile(user.id);
              if (profile == null) {
                // First-time Google user — persist to login table
                profile = await _authRepo.createGoogleUser(
                  id: user.id,
                  fullName: user.userMetadata?['full_name'] as String? ??
                      user.userMetadata?['name'] as String? ??
                      user.email ??
                      'User',
                  email: user.email ?? '',
                );
              }
              _profile = profile;
              _saveSession(user.id);
              notifyListeners();
            } catch (e) {
              _error = _parseError(e);
              notifyListeners();
            }
          }
        }
      },
    );
  }

  /// Initialize — check for existing session in local storage.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check local storage session (custom auth)
      final savedUserId = _getSession();
      if (savedUserId != null) {
        _profile = await _authRepo.getProfile(savedUserId);
        if (_profile == null) {
          _clearSession();
        }
      }

      // 2. If no local session, check Supabase Auth (returning Google user)
      if (_profile == null) {
        final supSession = Supabase.instance.client.auth.currentSession;
        if (supSession != null) {
          final user = supSession.user;
          var profile = await _authRepo.getProfile(user.id);
          if (profile == null) {
            profile = await _authRepo.createGoogleUser(
              id: user.id,
              fullName: user.userMetadata?['full_name'] as String? ??
                  user.userMetadata?['name'] as String? ??
                  user.email ??
                  'User',
              email: user.email ?? '',
            );
          }
          _profile = profile;
          _saveSession(user.id);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ─── Actions ──────────────────────────────────────────

  /// Register a new user (custom DB auth).
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String collegeName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _authRepo.register(
        fullName: fullName,
        email: email,
        password: password,
        collegeName: collegeName,
      );
      _profile = profile;
      _saveSession(profile.id);
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password (custom DB auth).
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _authRepo.login(
        email: email,
        password: password,
      );
      _saveSession(_profile!.id);
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with Google OAuth.
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authRepo.loginWithGoogle();
      return success;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update selected domains in profile.
  Future<void> updateDomains(List<String> domainIds) async {
    final uid = userId;
    if (uid == null) return;

    await _userRepo.saveSelectedDomains(uid, domainIds);
    _profile = _profile?.copyWith(selectedDomains: domainIds);
    notifyListeners();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authRepo.signOut();
    _profile = null;
    _error = null;
    _clearSession();
    notifyListeners();
  }

  /// Complete profile — update missing fields in DB.
  Future<bool> completeProfile(Map<String, String> fieldValues) async {
    final uid = userId;
    if (uid == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? fullName;
      String? collegeName;

      for (final entry in fieldValues.entries) {
        switch (entry.key) {
          case 'full_name':
            fullName = entry.value;
            break;
          case 'college_name':
            collegeName = entry.value;
            break;
        }
      }

      await _authRepo.updateUserProfile(
        userId: uid,
        fullName: fullName,
        collegeName: collegeName,
      );

      // Reload profile from DB to ensure consistency
      _profile = await _authRepo.getProfile(uid);
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Local Session ────────────────────────────────────

  void _saveSession(String userId) {
    html.window.localStorage[_sessionKey] = userId;
  }

  String? _getSession() {
    return html.window.localStorage[_sessionKey];
  }

  void _clearSession() {
    html.window.localStorage.remove(_sessionKey);
  }

  // ─── Helpers ──────────────────────────────────────────

  String _parseError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('Invalid email or password')) {
      return 'Invalid email or password';
    }
    if (msg.contains('already exists')) {
      return 'An account with this email already exists';
    }
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
