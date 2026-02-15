import '../models/paper.dart';
import '../services/paper_categorizer.dart';
import '../services/semantic_scholar_service.dart';
import '../services/huggingface_embedding_service.dart';

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

/// Repository that coordinates fetching + categorizing papers.
class PaperRepository {
  final SemanticScholarService _service;
  final HuggingFaceEmbeddingService _embeddingService;

  PaperRepository({
    SemanticScholarService? service,
    HuggingFaceEmbeddingService? embeddingService,
  })  : _service = service ?? SemanticScholarService(),
        _embeddingService =
            embeddingService ?? HuggingFaceEmbeddingService();

  /// Search for papers, categorize them, and return results.
  Future<SearchResult> searchPapers(String query, {int offset = 0}) async {
    final data = await _service.fetchPapers(query, offset: offset);

    final total = data['total'] as int? ?? 0;
    final rawPapers = (data['data'] as List<dynamic>?)
            ?.map((item) => Paper.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    // Categorize each paper into a domain
    final categorizedPapers = PaperCategorizer.categorizeAll(rawPapers);

    return SearchResult(papers: categorizedPapers, totalResults: total);
  }

  /// Semantic search: fetch papers, embed query + papers, rank by cosine similarity.
  /// Uses BAAI/bge-m3 via HuggingFace Inference API.
  Future<List<SemanticSearchResult>> semanticSearch(
    String query, {
    int offset = 0,
    int limit = 30,
  }) async {
    // 1. Fetch papers from Semantic Scholar API
    final data = await _service.fetchPapers(
      query,
      offset: offset,
      limit: limit,
    );

    final rawPapers = (data['data'] as List<dynamic>?)
            ?.map((item) => Paper.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    if (rawPapers.isEmpty) return [];

    // 2. Categorize papers
    final papers = PaperCategorizer.categorizeAll(rawPapers);

    // 3. Prepare texts: query + each paper's title+abstract
    final paperTexts = papers
        .map((p) => '${p.title} ${p.abstract_ ?? ""}')
        .toList();

    // 4. Generate embeddings in batch (query + all papers together)
    final allTexts = [query, ...paperTexts];
    final allEmbeddings =
        await _embeddingService.generateBatchEmbeddings(allTexts);

    final queryEmbedding = allEmbeddings[0];
    final paperEmbeddings = allEmbeddings.sublist(1);

    // 5. Compute cosine similarity and rank
    final results = <SemanticSearchResult>[];
    for (int i = 0; i < papers.length; i++) {
      final score = _embeddingService.cosineSimilarity(
        queryEmbedding,
        paperEmbeddings[i],
      );
      results.add(SemanticSearchResult(
        paper: papers[i],
        similarityScore: score,
      ));
    }

    // 6. Sort by similarity (highest first)
    results.sort(
        (a, b) => b.similarityScore.compareTo(a.similarityScore));

    return results;
  }

  void dispose() {
    _service.dispose();
    _embeddingService.dispose();
  }
}

