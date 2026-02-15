import 'package:flutter/foundation.dart';
import '../models/domain.dart';
import '../models/paper.dart';
import '../repositories/paper_repository.dart';
import '../services/semantic_scholar_service.dart';

/// Possible sort modes.
enum SortMode { relevance, citations, year }

/// State management for the paper search flow.
/// Supports both keyword search and semantic search (via BAAI/bge-m3 embeddings).
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
  bool _isLoading = false;
  String? _error;

  // ─── Getters ─────────────────────────────────────────
  List<SemanticSearchResult> get semanticResults => _semanticResults;
  int get totalResults => _totalResults;
  String get currentQuery => _currentQuery;
  int get currentOffset => _currentOffset;
  PaperDomain? get activeDomain => _activeDomain;
  SortMode get currentSort => _currentSort;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSearched => _currentQuery.isNotEmpty;

  int get perPage => SemanticScholarService.perPage;
  int get currentPage => (_currentOffset ~/ perPage) + 1;
  int get maxPage =>
      _totalResults > 0 ? (_totalResults / perPage).ceil() : 1;
  bool get hasPrevPage => currentPage > 1;
  bool get hasNextPage => currentPage < maxPage;

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

  /// Semantic search for papers with the given query.
  /// Fetches papers, generates embeddings, and ranks by cosine similarity.
  Future<void> search(String query, {int offset = 0}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _currentQuery = trimmed;
    _currentOffset = offset;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _repository.semanticSearch(
        _currentQuery,
        offset: _currentOffset,
        limit: perPage,
      );
      _semanticResults = results;
      // Semantic Scholar doesn't always give us total for semantic search,
      // so estimate based on whether we got a full page
      _totalResults = results.length >= perPage
          ? (_currentOffset + perPage * 2)
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

  /// Navigate to the next page.
  Future<void> nextPage() async {
    if (hasNextPage) {
      await search(_currentQuery, offset: _currentOffset + perPage);
    }
  }

  /// Navigate to the previous page.
  Future<void> prevPage() async {
    if (hasPrevPage) {
      await search(_currentQuery,
          offset: (_currentOffset - perPage).clamp(0, _totalResults));
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
