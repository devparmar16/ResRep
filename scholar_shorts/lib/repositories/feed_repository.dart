import '../models/paper.dart';
import '../services/backend_api_service.dart';

/// Orchestrates feed data through the FastAPI backend.
/// The backend handles: OpenAlex fetch → Redis cache → ranking → snapshot.
class FeedRepository {
  final BackendApiService _apiService;

  FeedRepository({BackendApiService? apiService})
      : _apiService = apiService ?? BackendApiService();

  /// Fetch the user's feed snapshot from the backend.
  Future<List<RankedPaper>> fetchFeed({
    required String userId,
    required List<String> domainIds,
  }) async {
    final papers = await _apiService.fetchFeed(
      userId: userId,
      interests: domainIds,
    );

    print('FeedRepository: received ${papers.length} papers from backend');

    // Wrap in RankedPaper to stay compatible with existing UI
    return papers.asMap().entries.map((entry) {
      // Score = position-based (first = highest)
      final score = 1.0 - (entry.key / (papers.length.clamp(1, 999)));
      return RankedPaper(paper: entry.value, similarityScore: score);
    }).toList();
  }

  /// Force-refresh the feed via backend.
  Future<List<RankedPaper>> refreshFeed({
    required String userId,
    required List<String> domainIds,
  }) async {
    final papers = await _apiService.refreshFeed(
      userId: userId,
      interests: domainIds,
    );

    return papers.asMap().entries.map((entry) {
      final score = 1.0 - (entry.key / (papers.length.clamp(1, 999)));
      return RankedPaper(paper: entry.value, similarityScore: score);
    }).toList();
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

  const RankedPaper({
    required this.paper,
    required this.similarityScore,
  });
}
