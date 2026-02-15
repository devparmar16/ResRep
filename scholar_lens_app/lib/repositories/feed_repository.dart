import '../models/domain.dart';
import '../models/paper.dart';
import '../services/embedding_service.dart';
import '../services/paper_categorizer.dart';
import '../services/semantic_scholar_service.dart';
import '../utils/constants.dart';

/// Orchestrates: API fetch → embed → rank → paginate.
class FeedRepository {
  final SemanticScholarService _apiService;
  final EmbeddingService _embeddingService;

  FeedRepository({
    SemanticScholarService? apiService,
    EmbeddingService? embeddingService,
  })  : _apiService = apiService ?? SemanticScholarService(),
        _embeddingService = embeddingService ?? EmbeddingService();

  bool _vocabInitialized = false;

  /// Initialize the vocabulary from domain descriptions.
  void _ensureVocab(List<DomainInfo> domains) {
    if (_vocabInitialized) return;

    final corpus = <String>[];
    for (final d in domains) {
      corpus.add('${d.label} ${d.description} ${d.keywords.join(" ")}');
    }
    _embeddingService.buildVocabulary(corpus);
    _vocabInitialized = true;
  }

  /// Fetch a page of papers, ranked by similarity to user's domains.
  ///
  /// [domains] — user's selected domains (with descriptions for embedding).
  /// [pageIndex] — 0-based page index.
  /// [perPage] — papers per page (default 12).
  Future<List<RankedPaper>> fetchRankedPage({
    required List<DomainInfo> domains,
    required int pageIndex,
    int perPage = AppConstants.papersPerPage,
  }) async {
    _ensureVocab(domains);

    // 1. Compute domain embeddings (cached after first call)
    final domainVecs = <List<double>>[];
    for (final d in domains) {
      final vec = _embeddingService.getDomainEmbedding(
        d.id,
        '${d.label} ${d.description} ${d.keywords.join(" ")}',
      );
      domainVecs.add(vec);
    }

    // 2. Build search query using domain labels with OR operator
    // Take distinct labels to avoid redundancy
    final distinctLabels = domains.map((d) => d.label).toSet().toList();
    
    // Limit to 4-5 domains to keep query length reasonable
    // Format: "Label 1" | "Label 2"
    final searchQuery = distinctLabels
        .take(5)
        .map((label) => '"$label"')
        .join(' | ');

    // 3. Fetch papers from API
    // We fetch more than needed to rank and select the best
    final offset = pageIndex * perPage;
    final data = await _apiService.fetchPapers(
      searchQuery,
      offset: offset,
      limit: perPage + 10, // fetch slightly more for better ranking
    );

    final rawList = (data['data'] as List<dynamic>?) ?? [];
    final papers = rawList
        .map((item) => Paper.fromJson(item as Map<String, dynamic>))
        .toList();

    // 4. Categorize papers into domains
    final categorized = PaperCategorizer.categorizeAll(papers);

    // 5. Expand vocabulary with new paper texts
    final newTexts = categorized
        .map((p) => '${p.title} ${p.abstract_ ?? ""}')
        .toList();
    _embeddingService.expandVocabulary(newTexts);

    // 6. Embed each paper, compute similarity, rank
    final ranked = <RankedPaper>[];
    for (final paper in categorized) {
      final paperText = '${paper.title} ${paper.abstract_ ?? ""}';
      final paperVec = _embeddingService.getPaperEmbedding(
        paper.paperId,
        paperText,
      );
      final score = _embeddingService.maxSimilarity(paperVec, domainVecs);
      ranked.add(RankedPaper(paper: paper, similarityScore: score));
    }

    // 7. Sort by similarity score (highest first)
    ranked.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    // 8. Return the top N for this page
    return ranked.take(perPage).toList();
  }

  /// Clear caches (on logout or session reset).
  void clearCaches() {
    _embeddingService.clearCaches();
    _vocabInitialized = false;
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
