import 'package:flutter/foundation.dart';
import '../models/domain.dart';
import '../models/paper.dart';
import '../repositories/paper_repository.dart';
import '../services/semantic_scholar_service.dart';
import '../utils/constants.dart';

/// Possible sort modes.
enum SortMode { relevance, citations, year }

/// State management for the paper search flow with infinite scroll.
class SearchProvider extends ChangeNotifier {
  final PaperRepository _repository;

  SearchProvider({PaperRepository? repository})
      : _repository = repository ?? PaperRepository();

  // ─── State ───────────────────────────────────────────
  List<SemanticSearchResult> _semanticResults = [];
  int _totalResults = 0;
  String _currentQuery = '';
  int _currentOffset = 0;
  PaperDomain? _activeDomain; // null means "all"
  SortMode _currentSort = SortMode.relevance;
  
  // Loading states
  bool _isLoading = false;      // Initial search loading
  bool _isLoadingMore = false;  // Infinite scroll loading
  String? _error;

  // ─── Getters ─────────────────────────────────────────
  List<SemanticSearchResult> get semanticResults => _semanticResults;
  int get totalResults => _totalResults;
  String get currentQuery => _currentQuery;
  int get currentOffset => _currentOffset;
  PaperDomain? get activeDomain => _activeDomain;
  SortMode get currentSort => _currentSort;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasSearched => _currentQuery.isNotEmpty;

  /// Whether there are more results to load.
  bool get hasMore => _semanticResults.length < _totalResults;

  /// Get papers (convenience accessor).
  List<Paper> get papers =>
      _semanticResults.map((r) => r.paper).toList();

  /// Get results filtered by active domain and sorted.
  List<SemanticSearchResult> get filteredResults {
    List<SemanticSearchResult> result;
    if (_activeDomain == null) {
      result = List.of(_semanticResults);
    } else {
      result = _semanticResults
          .where((r) => r.paper.domain == _activeDomain)
          .toList();
    }

    switch (_currentSort) {
      case SortMode.citations:
        result.sort((a, b) =>
            b.paper.citationCount.compareTo(a.paper.citationCount));
        break;
      case SortMode.year:
        result.sort((a, b) =>
            (b.paper.year ?? 0).compareTo(a.paper.year ?? 0));
        break;
      case SortMode.relevance:
        // Keep similarity ranking (already sorted by cosine similarity)
        break;
    }

    return result;
  }

  /// Get count of papers per domain.
  Map<PaperDomain?, int> get domainCounts {
    final allPapers = _semanticResults.map((r) => r.paper).toList();
    final counts = <PaperDomain?, int>{null: allPapers.length};
    for (final d in PaperDomain.values) {
      counts[d] = 0;
    }
    for (final paper in allPapers) {
      counts[paper.domain] = (counts[paper.domain] ?? 0) + 1;
    }
    return counts;
  }

  // ─── Actions ─────────────────────────────────────────

  /// Semantic search for papers with the given query (Initial Load).
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _currentQuery = trimmed;
    _currentOffset = 0;
    _semanticResults = []; // Reset results
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _repository.semanticSearch(
        _currentQuery,
        offset: _currentOffset,
        limit: AppConstants.papersPerPage,
      );
      _semanticResults = results;
      
      // Estimate total results if API doesn't provide it clearly
      // If we got a full page, assume there's at least one more page
      _totalResults = results.length >= AppConstants.papersPerPage
          ? (_currentOffset + AppConstants.papersPerPage * 20) // Arbitrary high number to allow scrolling
          : (_currentOffset + results.length);
          
      _error = null;
    } catch (e) {
      _error = e.toString();
      _semanticResults = [];
      _totalResults = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more results (Infinite Scroll).
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore || _currentQuery.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextOffset = _currentOffset + AppConstants.papersPerPage;
      
      final results = await _repository.semanticSearch(
        _currentQuery,
        offset: nextOffset,
        limit: AppConstants.papersPerPage,
      );

      if (results.isNotEmpty) {
        _semanticResults.addAll(results);
        _currentOffset = nextOffset;
        
        // Update total results estimate
        if (results.length >= AppConstants.papersPerPage) {
           _totalResults = _currentOffset + AppConstants.papersPerPage * 20;
        } else {
           _totalResults = _currentOffset + results.length;
        }
      } else {
        // No more results found
        _totalResults = _semanticResults.length;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Set the active domain filter.
  void setDomain(PaperDomain? domain) {
    _activeDomain = domain;
    notifyListeners();
  }

  /// Set the sort mode.
  void setSort(SortMode sort) {
    _currentSort = sort;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
