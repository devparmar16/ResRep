import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';

/// Service for Supabase database operations on the `login` table.
/// Handles custom email/password auth via the DB directly.
class SupabaseDbService {
  final SupabaseClient _client;

  SupabaseDbService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ─── Password Hashing ────────────────────────────────

  /// Hash a password using SHA-256.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ─── Custom Auth ─────────────────────────────────────

  /// Register a new user — insert into login table with hashed password.
  /// Returns the created profile, or throws if email already exists.
  Future<UserProfile> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String collegeName,
  }) async {
    // Check if email already exists
    final existing = await _client
        .from(SupabaseConfig.loginTable)
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (existing != null) {
      throw Exception('An account with this email already exists');
    }

    // Let Supabase generate the ID (default UUID or Serial)
    final passwordHash = hashPassword(password);

    final response = await _client
        .from(SupabaseConfig.loginTable)
        .insert({
          'full_name': fullName,
          'email': email,
          'college_name': collegeName,
          'password_hash': passwordHash,
          'selected_domains': <String>[],
        })
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Login with email and password — verify against DB.
  Future<UserProfile> loginUser({
    required String email,
    required String password,
  }) async {
    final passwordHash = hashPassword(password);

    final response = await _client
        .from(SupabaseConfig.loginTable)
        .select()
        .eq('email', email)
        .eq('password_hash', passwordHash)
        .maybeSingle();

    if (response == null) {
      throw Exception('Invalid email or password');
    }

    return UserProfile.fromJson(response);
  }

  // ─── Profile Operations ──────────────────────────────

  /// Fetch user profile from the `login` table.
  Future<UserProfile?> getUserProfile(String userId) async {
    final response = await _client
        .from(SupabaseConfig.loginTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  /// Update the selected domains for a user.
  Future<void> updateSelectedDomains(
    String userId,
    List<String> domainIds,
  ) async {
    await _client.from(SupabaseConfig.loginTable).update({
      'selected_domains': domainIds,
    }).eq('id', userId);
  }

  /// Check if user has selected domains.
  Future<bool> hasSelectedDomains(String userId) async {
    final profile = await getUserProfile(userId);
    return profile != null && profile.hasSelectedDomains;
  }

  // ─── Google OAuth ────────────────────────────────────

  /// Create a profile for a Google OAuth user.
  /// Uses the explicit ID from Supabase Auth so lookups match.
  Future<UserProfile> createGoogleUser({
    required String id,
    required String email,
    required String fullName,
  }) async {
    // Idempotent — return existing profile if already created
    final existing = await getUserProfile(id);
    if (existing != null) return existing;

    final response = await _client
        .from(SupabaseConfig.loginTable)
        .insert({
          'id': id, // Explicit ID from Supabase Auth
          'full_name': fullName,
          'email': email,
          'college_name': '', // Empty — will be collected later
          'password_hash': '', // No password for OAuth users
          'selected_domains': <String>[],
        })
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  // ─── Profile Updates ─────────────────────────────────

  /// Update specific profile fields (for profile completion).
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? collegeName,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (collegeName != null) updates['college_name'] = collegeName;

    if (updates.isEmpty) return;

    await _client
        .from(SupabaseConfig.loginTable)
        .update(updates)
        .eq('id', userId);
  }
}
