import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collection.dart';
import '../models/saved_paper.dart';
import '../services/bookmark_service.dart';

/// State management for bookmarks and collections.
class BookmarkProvider extends ChangeNotifier {
  final BookmarkService _service;

  BookmarkProvider({BookmarkService? service})
      : _service = service ?? BookmarkService();

  // ─── State ─────────────────────────────────────────────
  List<Collection> _collections = [];
  List<SavedPaper> _collectionPapers = [];
  Set<String> _bookmarkedIds = {};
  bool _isLoading = false;
  String? _error;
  String? _activeCollectionId;

  // ─── Getters ───────────────────────────────────────────
  List<Collection> get collections => _collections;
  List<SavedPaper> get collectionPapers => _collectionPapers;
  Set<String> get bookmarkedIds => _bookmarkedIds;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeCollectionId => _activeCollectionId;

  /// Check if a paper is bookmarked (in any collection).
  bool isBookmarked(String openalexId) => _bookmarkedIds.contains(openalexId);

  // ─── Init ──────────────────────────────────────────────

  /// Load collections + bookmark IDs for the current user.
  Future<void> loadUserData(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getUserCollections(userId),
        _service.getUserBookmarkedIds(userId),
      ]);
      _collections = results[0] as List<Collection>;
      _bookmarkedIds = results[1] as Set<String>;
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Collection CRUD ──────────────────────────────────

  /// Create a new collection.
  Future<bool> createCollection({
    required String userId,
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    try {
      final collection = await _service.createCollection(
        userId: userId,
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      _collections.insert(0, collection);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  /// Update a collection.
  Future<bool> updateCollection({
    required String userId,
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final updated = await _service.updateCollection(
        userId: userId,
        collectionId: collectionId,
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx >= 0) {
        // Preserve the paper_count from the old entry
        _collections[idx] = Collection.fromJson({
          ...{
            'id': updated.id,
            'user_id': updated.userId,
            'name': updated.name,
            'description': updated.description,
            'is_private': updated.isPrivate,
            'created_at': updated.createdAt?.toIso8601String(),
            'updated_at': updated.updatedAt?.toIso8601String(),
            'paper_count': _collections[idx].paperCount,
          }
        });
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  /// Delete a collection.
  Future<bool> deleteCollection({
    required String userId,
    required String collectionId,
  }) async {
    try {
      await _service.deleteCollection(
        userId: userId,
        collectionId: collectionId,
      );
      _collections.removeWhere((c) => c.id == collectionId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Save / Unsave Papers ──────────────────────────────

  /// Save a paper to a collection.
  Future<bool> savePaper({
    required String userId,
    required String collectionId,
    required String openalexId,
    String? title,
    String? journalName,
    String? publicationDate,
    bool? isOpenAccess,
  }) async {
    try {
      await _service.savePaper(
        userId: userId,
        collectionId: collectionId,
        openalexId: openalexId,
        title: title,
        journalName: journalName,
        publicationDate: publicationDate,
        isOpenAccess: isOpenAccess,
      );
      _bookmarkedIds.add(openalexId);
      // Update paper count for this collection
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx >= 0) {
        _collections[idx] = _collections[idx].copyWith(
          paperCount: _collections[idx].paperCount + 1,
        );
      }
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _error = 'Paper already saved in this collection';
      } else {
        _error = _parseError(e);
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  /// Remove a paper from a collection.
  Future<bool> removePaper({
    required String userId,
    required String collectionId,
    required String openalexId,
  }) async {
    try {
      await _service.removePaper(
        userId: userId,
        collectionId: collectionId,
        openalexId: openalexId,
      );
      // Check if paper is still saved in any other collection
      final remaining = await _service.getSavedCollectionIds(
        userId: userId,
        openalexId: openalexId,
      );
      if (remaining.isEmpty) {
        _bookmarkedIds.remove(openalexId);
      }
      // Update paper count
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx >= 0 && _collections[idx].paperCount > 0) {
        _collections[idx] = _collections[idx].copyWith(
          paperCount: _collections[idx].paperCount - 1,
        );
      }
      // Refresh active collection papers if viewing this one
      if (_activeCollectionId == collectionId) {
        _collectionPapers.removeWhere((p) => p.openalexId == openalexId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Collection Papers ─────────────────────────────────

  /// Load papers for a specific collection.
  Future<void> loadCollectionPapers({
    required String userId,
    required String collectionId,
  }) async {
    _activeCollectionId = collectionId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _collectionPapers = await _service.getCollectionPapers(
        userId: userId,
        collectionId: collectionId,
      );
    } catch (e) {
      _error = _parseError(e);
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

  // ─── Helpers ───────────────────────────────────────────

  String _parseError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('23505')) return 'Paper already saved in this collection';
    if (msg.contains('23503')) return 'Invalid collection';
    return msg.replaceFirst('Exception: ', '').replaceFirst('PostgrestException: ', '');
  }
}
