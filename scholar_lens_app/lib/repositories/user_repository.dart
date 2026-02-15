import '../models/user_profile.dart';
import '../services/supabase_db_service.dart';

/// Repository for user profile and domain operations.
class UserRepository {
  final SupabaseDbService _dbService;

  UserRepository({SupabaseDbService? dbService})
      : _dbService = dbService ?? SupabaseDbService();

  /// Get user profile by ID.
  Future<UserProfile?> getProfile(String userId) async {
    return await _dbService.getUserProfile(userId);
  }

  /// Check if the user has selected domains.
  Future<bool> hasSelectedDomains(String userId) async {
    return await _dbService.hasSelectedDomains(userId);
  }

  /// Save selected domain IDs for the user.
  Future<void> saveSelectedDomains(
    String userId,
    List<String> domainIds,
  ) async {
    await _dbService.updateSelectedDomains(userId, domainIds);
  }

  /// Get the user's selected domain IDs.
  Future<List<String>> getSelectedDomainIds(String userId) async {
    final profile = await _dbService.getUserProfile(userId);
    return profile?.selectedDomains ?? [];
  }
}
