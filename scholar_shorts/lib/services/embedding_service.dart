import 'dart:math';

/// Local TF-IDF embedding engine for semantic ranking.
/// Runs entirely on-device — no external API needed.
class EmbeddingService {
  // ─── Vocabulary ───────────────────────────────────────
  final Map<String, int> _vocab = {};
  final Map<String, double> _idf = {};
  bool _isBuilt = false;

  // ─── Caches ───────────────────────────────────────────
  final Map<String, List<double>> _domainEmbeddings = {};
  final Map<String, List<double>> _paperEmbeddings = {};

  /// Build vocabulary from a corpus of texts.
  /// Call once per session with domain descriptions + initial paper texts.
  void buildVocabulary(List<String> corpus) {
    if (_isBuilt) return;

    final docFreq = <String, int>{};
    int idx = 0;

    for (final doc in corpus) {
      final tokens = _tokenize(doc);
      final uniqueTokens = tokens.toSet();

      for (final token in uniqueTokens) {
        if (!_vocab.containsKey(token)) {
          _vocab[token] = idx++;
        }
        docFreq[token] = (docFreq[token] ?? 0) + 1;
      }
    }

    // Compute IDF: log(N / df)
    final n = corpus.length;
    for (final entry in docFreq.entries) {
      _idf[entry.key] = log((n + 1) / (entry.value + 1)) + 1.0;
    }

    _isBuilt = true;
  }

  /// Expand vocabulary with new texts (additive, won't reset existing).
  void expandVocabulary(List<String> newTexts) {
    final oldSize = _vocab.length;
    int idx = oldSize;

    for (final text in newTexts) {
      final tokens = _tokenize(text);
      for (final token in tokens) {
        if (!_vocab.containsKey(token)) {
          _vocab[token] = idx++;
          _idf[token] = 1.0; // default IDF for new terms
        }
      }
    }
  }

  /// Generate a TF-IDF embedding vector for a given text.
  List<double> generateEmbedding(String text) {
    if (!_isBuilt && _vocab.isEmpty) {
      // Fallback: build from this single text
      buildVocabulary([text]);
    }

    final tokens = _tokenize(text);
    final vec = List<double>.filled(_vocab.length, 0.0);

    // Term frequency
    final tf = <String, int>{};
    for (final token in tokens) {
      tf[token] = (tf[token] ?? 0) + 1;
    }

    // TF-IDF
    final maxTf = tf.values.isEmpty ? 1 : tf.values.reduce(max);
    for (final entry in tf.entries) {
      final vocabIdx = _vocab[entry.key];
      if (vocabIdx != null && vocabIdx < vec.length) {
        final normalizedTf = 0.5 + 0.5 * (entry.value / maxTf);
        vec[vocabIdx] = normalizedTf * (_idf[entry.key] ?? 1.0);
      }
    }

    // L2 normalize
    return _normalize(vec);
  }

  /// Get or compute a cached domain embedding.
  List<double> getDomainEmbedding(String domainId, String description) {
    return _domainEmbeddings.putIfAbsent(
      domainId,
      () => generateEmbedding(description),
    );
  }

  /// Get or compute a cached paper embedding.
  List<double> getPaperEmbedding(String paperId, String text) {
    return _paperEmbeddings.putIfAbsent(
      paperId,
      () => generateEmbedding(text),
    );
  }

  /// Compute cosine similarity between two vectors.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0.0;
    return dotProduct / denom;
  }

  /// Compute the maximum similarity of a paper against multiple domain embeddings.
  double maxSimilarity(
    List<double> paperVec,
    List<List<double>> domainVecs,
  ) {
    if (domainVecs.isEmpty) return 0.0;
    double best = 0.0;
    for (final dv in domainVecs) {
      final sim = cosineSimilarity(paperVec, dv);
      if (sim > best) best = sim;
    }
    return best;
  }

  /// Clear all caches (call on logout or session reset).
  void clearCaches() {
    _domainEmbeddings.clear();
    _paperEmbeddings.clear();
    _vocab.clear();
    _idf.clear();
    _isBuilt = false;
  }

  // ─── Private Helpers ──────────────────────────────────

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
  }

  List<double> _normalize(List<double> vec) {
    double norm = 0.0;
    for (final v in vec) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm == 0) return vec;
    return vec.map((v) => v / norm).toList();
  }
}
