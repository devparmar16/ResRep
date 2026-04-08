import 'package:flutter/foundation.dart';
import '../models/paper.dart';
import '../services/paper_categorizer.dart';
import '../services/backend_api_service.dart';

/// Result class for search operations.
class SearchResult {
  final List<Paper> papers;
  final int totalResults;

  SearchResult({required this.papers, required this.totalResults});
}

/// A paper paired with its semantic similarity score.
class SemanticSearchResult {
  final Paper paper;
  final double similarityScore;

  const SemanticSearchResult({
    required this.paper,
    required this.similarityScore,
  });
}

/// Repository that coordinates fetching + categorizing papers via our fast backend.
class PaperRepository {
  final BackendApiService _apiService;

  // Cache last query results to allow client-side pagination over the top 50
  String _lastQuery = '';
  List<SemanticSearchResult> _cachedResults = [];

  PaperRepository({
    BackendApiService? apiService,
  }) : _apiService = apiService ?? BackendApiService();

  /// Semantic search: proxy to OpenAlex via backend backend search
  /// Much faster than doing local HuggingFace embeddings.
  Future<List<SemanticSearchResult>> semanticSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    int? startYear,
    int? endYear,
    String? sort,
  }) async {
    final cacheKey = '${query}_${startYear}_${endYear}_$sort';
    debugPrint('PaperRepository: fetching offset=$offset, limit=$limit for CacheKey="$cacheKey"');

    // Return from memory cache if appending pagination
    if (cacheKey == _lastQuery && _cachedResults.isNotEmpty && offset > 0) {
      if (offset >= _cachedResults.length) return [];
      final end = (offset + limit < _cachedResults.length) ? offset + limit : _cachedResults.length;
      return _cachedResults.sublist(offset, end);
    }

    _lastQuery = cacheKey;
    _cachedResults = [];

    // 1. Fetch from fast proxy (returns top 50)
    final rawPapers = await _apiService.searchPapers(
      query: query,
      startYear: startYear,
      endYear: endYear,
      sort: sort,
    );

    if (rawPapers.isEmpty) return [];

    // 2. Categorize papers
    final papers = PaperCategorizer.categorizeAll(rawPapers);

    // 3. Map to dummy semantic results (OpenAlex is pre-sorted by relevance)
    for (int i = 0; i < papers.length; i++) {
      _cachedResults.add(SemanticSearchResult(
        paper: papers[i],
        similarityScore: 1.0 - (i * 0.001), // dummy decreasing score to keep ordering
      ));
    }

    if (offset >= _cachedResults.length) return [];

    final end = (offset + limit < _cachedResults.length) ? offset + limit : _cachedResults.length;
    return _cachedResults.sublist(offset, end);
  }

  void dispose() {
    _apiService.dispose();
  }
}
