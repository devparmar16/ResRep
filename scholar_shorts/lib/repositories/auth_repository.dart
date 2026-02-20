import '../models/user_profile.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_db_service.dart';

/// Repository that orchestrates auth + database operations.
/// Uses custom DB auth for email/password, Supabase Auth for Google OAuth.
class AuthRepository {
  final SupabaseAuthService _authService;
  final SupabaseDbService _dbService;

  AuthRepository({
    SupabaseAuthService? authService,
    SupabaseDbService? dbService,
  })  : _authService = authService ?? SupabaseAuthService(),
        _dbService = dbService ?? SupabaseDbService();

  /// Register a new user via custom DB auth.
  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String password,
    required String collegeName,
  }) async {
    return await _dbService.registerUser(
      fullName: fullName,
      email: email,
      password: password,
      collegeName: collegeName,
    );
  }

  /// Login with email and password via custom DB auth.
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    return await _dbService.loginUser(
      email: email,
      password: password,
    );
  }

  /// Create a profile for a Google OAuth user (persists to DB).
  Future<UserProfile> createGoogleUser({
    required String id,
    required String fullName,
    required String email,
  }) async {
    return await _dbService.createGoogleUser(
      id: id,
      fullName: fullName,
      email: email,
    );
  }

  /// Update user profile fields (for profile completion).
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? collegeName,
  }) async {
    return await _dbService.updateUserProfile(
      userId: userId,
      fullName: fullName,
      collegeName: collegeName,
    );
  }

  /// Login with Google OAuth.
  Future<bool> loginWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  /// Fetch a profile by user ID.
  Future<UserProfile?> getProfile(String userId) async {
    return await _dbService.getUserProfile(userId);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
