import 'package:flutter/foundation.dart';
import '../repositories/feed_repository.dart';

/// Session-based personalized feed state management.
/// Backed by FastAPI + Redis cursor-based pagination.
class FeedProvider extends ChangeNotifier {
  final FeedRepository _feedRepo;

  FeedProvider({FeedRepository? feedRepo})
      : _feedRepo = feedRepo ?? FeedRepository();

  // ─── State ────────────────────────────────────────────
  List<RankedPaper> _papers = [];
  List<String> _domainIds = [];
  String? _userId;

  // Multi-domain filter: empty set = "For You" (all papers)
  // Special keys: 'trending', 'latest' are solo toggles
  final Set<String> _activeFilterDomainIds = {};

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _nextCursor;
  bool _hasMore = true;

  // ─── Getters ──────────────────────────────────────────
  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasContent => _papers.isNotEmpty;
  bool get hasMore => _hasMore;
  Set<String> get activeFilterDomainIds => _activeFilterDomainIds.toSet();

  /// For backward compat — used in UI to detect "For You" / "Trending" / "Latest"
  String? get activeFilterDomainId {
    if (_activeFilterDomainIds.isEmpty) return null;
    if (_activeFilterDomainIds.contains('trending')) return 'trending';
    if (_activeFilterDomainIds.contains('latest')) return 'latest';
    return _activeFilterDomainIds.first;
  }

  /// All loaded papers for the current cursor state.
  List<RankedPaper> get feedPapers => List.unmodifiable(_papers);

  // ─── Actions ──────────────────────────────────────────

  /// Toggle a filter on/off. Fetches a brand new cursor chain.
  void toggleFilterDomain(String domainId) {
    if (domainId == 'trending' || domainId == 'latest') {
      // Special sorts are exclusive toggles
      if (_activeFilterDomainIds.contains(domainId)) {
        _activeFilterDomainIds.clear();
      } else {
        _activeFilterDomainIds.clear();
        _activeFilterDomainIds.add(domainId);
      }
    } else {
      // Remove any special sort if user picks a domain
      _activeFilterDomainIds.remove('trending');
      _activeFilterDomainIds.remove('latest');

      if (_activeFilterDomainIds.contains(domainId)) {
        _activeFilterDomainIds.remove(domainId);
      } else {
        _activeFilterDomainIds.add(domainId);
      }
    }
    _reloadFeedForCurrentFilters();
  }

  /// Legacy single-select support
  void setActiveFilterDomain(String? domainId) {
    if (domainId == null && _activeFilterDomainIds.isEmpty) return; // Already on "For You"
    
    _activeFilterDomainIds.clear();
    if (domainId != null) {
      _activeFilterDomainIds.add(domainId);
    }
    _reloadFeedForCurrentFilters();
  }

  void _reloadFeedForCurrentFilters({bool ignoreCache = false}) {
    _papers.clear();
    _nextCursor = '*';
    _hasMore = true;
    _error = null;
    _isLoadingInitial = true;
    notifyListeners();
    
    _fetchPage(ignoreCache: ignoreCache);
  }

  /// Set the user's domains and load the initial feed.
  Future<void> initialize(List<String> domainIds, {String? userId}) async {
    if (_papers.isNotEmpty) return; // already loaded

    _domainIds = domainIds;
    print('FeedProvider: initializing with ${domainIds.length} domains for user $userId');
    _userId = userId ?? 'default-user';
    if (_domainIds.isEmpty) {
      print('FeedProvider: SKIPPING initialization because domainIds is empty');
      return;
    }

    _reloadFeedForCurrentFilters();
  }

  /// Load more papers when reaching the end of the list.
  Future<void> loadMore() async {
    if (_isLoadingInitial || _isLoadingMore || !_hasMore || _nextCursor == null) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    await _fetchPage();
  }

  /// Pull-to-refresh: force-rebuild the feed via backend.
  Future<void> refresh(List<String> domainIds) async {
    _domainIds = domainIds;
    _reloadFeedForCurrentFilters(ignoreCache: true);
  }

  /// Reset feed (on logout or domain change).
  void reset() {
    _papers.clear();
    _domainIds.clear();
    _userId = null;
    _activeFilterDomainIds.clear();
    _nextCursor = '*';
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
  
  // ─── Internal Fetch Logic ────────────────────────────────

  Future<void> _fetchPage({bool ignoreCache = false}) async {
    try {
      final queryData = _buildQueryParams();
      
      final result = await _feedRepo.fetchFeed(
        domainIds: queryData.domainIds,
        sort: queryData.sort,
        cursor: _nextCursor ?? '*',
        userId: _userId,
        ignoreCache: ignoreCache,
      );

      _papers.addAll(result.papers);
      _nextCursor = result.nextCursor;
      _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
      
      print('FeedProvider: Fetched ${result.papers.length} papers. New nextCursor: $_nextCursor. hasMore: $_hasMore');
    } catch (e) {
      _error = e.toString();
      print('FeedProvider API Error: $e');
    } finally {
      if (_isLoadingInitial) _isLoadingInitial = false;
      if (_isLoadingMore) _isLoadingMore = false;
      notifyListeners();
    }
  }

  _QueryParams _buildQueryParams() {
    String sort = 'recent';
    List<String> domainsToQuery = _domainIds;

    if (_activeFilterDomainIds.isNotEmpty) {
      if (_activeFilterDomainIds.contains('trending')) {
        sort = 'trending';
      } else if (_activeFilterDomainIds.contains('latest')) {
        sort = 'latest';
      } else {
        // Specific user domains selected
        sort = 'relevance';
        domainsToQuery = _activeFilterDomainIds.toList();
      }
    }
    
    if (domainsToQuery.isEmpty) domainsToQuery = ['all'];

    return _QueryParams(domainIds: domainsToQuery, sort: sort);
  }

  @override
  void dispose() {
    _feedRepo.dispose();
    super.dispose();
  }
}

class _QueryParams {
  final List<String> domainIds;
  final String sort;

  _QueryParams({required this.domainIds, required this.sort});
}
