import 'package:flutter/foundation.dart';
import '../repositories/feed_repository.dart';
import '../models/domain.dart';

/// Session-based personalized feed state management.
/// Now backed by FastAPI + Redis snapshots.
class FeedProvider extends ChangeNotifier {
  final FeedRepository _feedRepo;

  FeedProvider({FeedRepository? feedRepo})
      : _feedRepo = feedRepo ?? FeedRepository();

  // ─── State ────────────────────────────────────────────
  List<RankedPaper> _papers = [];
  List<String> _domainIds = [];
  String? _userId;
  String? _activeFilterDomainId;
  
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;

  // ─── Getters ──────────────────────────────────────────
  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasContent => _papers.isNotEmpty;
  bool get hasMore => false; // Feed is snapshot-based, no pagination
  int get totalPagesLoaded => hasContent ? 1 : 0;
  
  String? get activeFilterDomainId => _activeFilterDomainId;

  /// All loaded papers (snapshot) filtered by the active domain.
  List<RankedPaper> get feedPapers {
    if (_activeFilterDomainId == null) {
      return List.unmodifiable(_papers); // For You (default ranking)
    }
    
    if (_activeFilterDomainId == 'trending') {
      final sorted = List.of(_papers);
      sorted.sort((a, b) => b.paper.citationCount.compareTo(a.paper.citationCount));
      return sorted;
    }
    
    if (_activeFilterDomainId == 'latest') {
      final sorted = List.of(_papers);
      sorted.sort((a, b) {
        final dateA = a.paper.publicationDate ?? '${a.paper.year ?? '0000'}';
        final dateB = b.paper.publicationDate ?? '${b.paper.year ?? '0000'}';
        return dateB.compareTo(dateA);
      });
      return sorted;
    }

    final targetDomain = DomainInfo.getById(_activeFilterDomainId!).domain;
    return _papers.where((p) => p.paper.domain == targetDomain).toList();
  }

  // ─── Actions ──────────────────────────────────────────

  /// Set the user's domains and load the feed snapshot.
  Future<void> initialize(List<String> domainIds, {String? userId}) async {
    if (_papers.isNotEmpty) return; // already loaded

    _domainIds = domainIds;
    _userId = userId ?? 'default-user';
    if (_domainIds.isEmpty) return;

    _isLoadingInitial = true;
    _error = null;
    notifyListeners();

    try {
      _papers = await _feedRepo.fetchFeed(
        userId: _userId!,
        domainIds: _domainIds,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  /// Load more — no-op for snapshot-based feeds.
  Future<void> loadMore() async {
    // Snapshot-based: all papers are loaded at once
  }

  /// Pull-to-refresh: force-rebuild the feed via backend.
  Future<void> refresh(List<String> domainIds) async {
    _isLoadingInitial = true;
    _error = null;
    _domainIds = domainIds;
    notifyListeners();

    try {
      _papers = await _feedRepo.refreshFeed(
        userId: _userId ?? 'default-user',
        domainIds: _domainIds,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  void setActiveFilterDomain(String? domainId) {
    _activeFilterDomainId = domainId;
    notifyListeners();
  }

  /// Reset feed (on logout or domain change).
  void reset() {
    _papers = [];
    _domainIds = [];
    _userId = null;
    _activeFilterDomainId = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _feedRepo.dispose();
    super.dispose();
  }
}
