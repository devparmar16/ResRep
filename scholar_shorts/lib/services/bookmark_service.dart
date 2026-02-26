import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/collection.dart';
import '../models/saved_paper.dart';

/// Service for all bookmark/collection operations against Supabase.
/// Ownership is enforced at query level (user_id filtering)
/// since RLS is not yet enabled.
class BookmarkService {
  final SupabaseClient _client;

  BookmarkService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ─── Collections ─────────────────────────────────────────

  /// Create a new collection for the user.
  Future<Collection> createCollection({
    required String userId,
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final response = await _client
        .from(SupabaseConfig.collectionsTable)
        .insert({
          'user_id': userId,
          'name': name,
          'description': description,
          'is_private': isPrivate,
        })
        .select()
        .single();
    return Collection.fromJson({...response, 'paper_count': 0});
  }

  /// Update a collection's name/description/privacy.
  Future<Collection> updateCollection({
    required String userId,
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPrivate != null) updates['is_private'] = isPrivate;

    final response = await _client
        .from(SupabaseConfig.collectionsTable)
        .update(updates)
        .eq('id', collectionId)
        .eq('user_id', userId) // Ownership check
        .select()
        .single();
    return Collection.fromJson(response);
  }

  /// Delete a collection (cascade deletes saved_papers).
  Future<void> deleteCollection({
    required String userId,
    required String collectionId,
  }) async {
    await _client
        .from(SupabaseConfig.collectionsTable)
        .delete()
        .eq('id', collectionId)
        .eq('user_id', userId);
  }

  /// Get all collections for a user, with paper counts.
  Future<List<Collection>> getUserCollections(String userId) async {
    final response = await _client
        .from(SupabaseConfig.collectionsTable)
        .select('*, saved_papers(count)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List).map((json) {
      // Supabase returns count as: saved_papers: [{count: N}]
      int count = 0;
      if (json['saved_papers'] != null && json['saved_papers'] is List) {
        final countList = json['saved_papers'] as List;
        if (countList.isNotEmpty && countList[0] is Map) {
          count = countList[0]['count'] as int? ?? 0;
        }
      }
      return Collection.fromJson({...json, 'paper_count': count});
    }).toList();
  }

  // ─── Saved Papers ────────────────────────────────────────

  /// Save a paper to a collection.
  /// Throws PostgrestException with code '23505' on duplicate.
  Future<SavedPaper> savePaper({
    required String userId,
    required String collectionId,
    required String openalexId,
    String? title,
    String? journalName,
    String? publicationDate,
    bool? isOpenAccess,
  }) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .insert({
          'user_id': userId,
          'collection_id': collectionId,
          'openalex_id': openalexId,
          'title': title,
          'journal_name': journalName,
          'publication_date': publicationDate,
          'is_open_access': isOpenAccess,
        })
        .select()
        .single();
    return SavedPaper.fromJson(response);
  }

  /// Remove a saved paper from a collection.
  Future<void> removePaper({
    required String userId,
    required String collectionId,
    required String openalexId,
  }) async {
    await _client
        .from(SupabaseConfig.savedPapersTable)
        .delete()
        .eq('collection_id', collectionId)
        .eq('openalex_id', openalexId)
        .eq('user_id', userId);
  }

  /// Move a paper from one collection to another.
  Future<void> movePaper({
    required String userId,
    required String openalexId,
    required String fromCollectionId,
    required String toCollectionId,
  }) async {
    await _client
        .from(SupabaseConfig.savedPapersTable)
        .update({'collection_id': toCollectionId})
        .eq('collection_id', fromCollectionId)
        .eq('openalex_id', openalexId)
        .eq('user_id', userId);
  }

  /// Check if a paper is saved in ANY of the user's collections.
  /// Returns the list of collection IDs it's saved in.
  Future<List<String>> getSavedCollectionIds({
    required String userId,
    required String openalexId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .select('collection_id')
        .eq('user_id', userId)
        .eq('openalex_id', openalexId);

    return (response as List)
        .map((r) => r['collection_id'] as String)
        .toList();
  }

  /// Check if a paper is saved in a specific collection.
  Future<bool> isPaperInCollection({
    required String collectionId,
    required String openalexId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .select('id')
        .eq('collection_id', collectionId)
        .eq('openalex_id', openalexId)
        .maybeSingle();
    return response != null;
  }

  /// Get all papers in a specific collection.
  Future<List<SavedPaper>> getCollectionPapers({
    required String userId,
    required String collectionId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .select()
        .eq('collection_id', collectionId)
        .eq('user_id', userId)
        .order('saved_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => SavedPaper.fromJson(json))
        .toList();
  }

  /// Get ALL saved papers for a user (across all collections).
  Future<List<SavedPaper>> getAllUserSavedPapers({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .select('*, collections(name)')
        .eq('user_id', userId)
        .order('saved_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => SavedPaper.fromJson(json))
        .toList();
  }

  /// Get a set of all openalexIds the user has saved (for bookmark icon state).
  Future<Set<String>> getUserBookmarkedIds(String userId) async {
    final response = await _client
        .from(SupabaseConfig.savedPapersTable)
        .select('openalex_id')
        .eq('user_id', userId);

    return (response as List)
        .map((r) => r['openalex_id'] as String)
        .toSet();
  }
}
