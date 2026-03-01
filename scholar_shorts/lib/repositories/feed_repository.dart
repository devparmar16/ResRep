import '../models/paper.dart';
import '../services/backend_api_service.dart';

/// Orchestrates feed data through the FastAPI backend.
/// The backend handles: OpenAlex fetch → Redis cache → ranking → snapshot.
class FeedRepository {
  final BackendApiService _apiService;

  FeedRepository({BackendApiService? apiService})
      : _apiService = apiService ?? BackendApiService();

  /// Fetch the user's feed snapshot from the backend.
  Future<RankedFeedResult> fetchFeed({
    required List<String> domainIds,
    String? publisher,
    String sort = 'recent',
    String cursor = '*',
    String? userId,
    bool ignoreCache = false,
  }) async {
    final result = await _apiService.fetchFeed(
      interests: domainIds,
      publisher: publisher,
      sort: sort,
      cursor: cursor,
      userId: userId,
      ignoreCache: ignoreCache,
    );

    print('FeedRepository: received ${result.papers.length} papers. Cursor: ${result.nextCursor}');

    // Wrap in RankedPaper to stay compatible with existing UI
    final rankedPapers = result.papers.asMap().entries.map((entry) {
      // Score = position-based (first = highest)
      final score = 1.0 - (entry.key / (result.papers.length.clamp(1, 999)));
      return RankedPaper(paper: entry.value, similarityScore: score);
    }).toList();

    return RankedFeedResult(papers: rankedPapers, nextCursor: result.nextCursor);
  }

  /// Force-refresh the feed via backend.
  Future<RankedFeedResult> refreshFeed({
    required List<String> domainIds,
    String? userId,
    bool ignoreCache = false,
  }) async {
    final result = await _apiService.refreshFeed(
      interests: domainIds,
      userId: userId,
      ignoreCache: ignoreCache,
    );

    final rankedPapers = result.papers.asMap().entries.map((entry) {
      final score = 1.0 - (entry.key / (result.papers.length.clamp(1, 999)));
      return RankedPaper(paper: entry.value, similarityScore: score);
    }).toList();

    return RankedFeedResult(papers: rankedPapers, nextCursor: result.nextCursor);
  }

  void clearCaches() {
    // Nothing to clear locally — caches live in Redis
  }

  void dispose() {
    _apiService.dispose();
  }
}

/// A paper paired with its similarity score.
class RankedPaper {
  final Paper paper;
  final double similarityScore;

  const RankedPaper({required this.paper, required this.similarityScore});
}

/// Result object combining papers and a pagination cursor
class RankedFeedResult {
  final List<RankedPaper> papers;
  final String? nextCursor;

  RankedFeedResult({required this.papers, this.nextCursor});
}
