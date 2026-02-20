import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import '../config/huggingface_config.dart'; // No longer needed

/// Service for generating text embeddings using a local Ollama instance.
/// Renamed logically to reflect purpose, but keeping filename to avoid breakage.
/// Assumes Ollama is running on localhost:11434 with 'bge-m3'.
class HuggingFaceEmbeddingService {
  final http.Client _client;

  // Local Ollama endpoint
  // Local Ollama endpoint (default)
  static String customBaseUrl = 'http://localhost:11434';
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    customBaseUrl = prefs.getString('ollama_url') ?? 'http://localhost:11434';
  }

  static Future<void> updateUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ollama_url', url);
    customBaseUrl = url;
  }

  static const String _model = 'bge-m3';

  /// Cache: text hash → embedding vector.
  final Map<String, List<double>> _cache = {};

  HuggingFaceEmbeddingService({http.Client? client})
      : _client = client ?? http.Client();

  /// Helper to make API requests to local Ollama.
  Future<List<double>> _generateOllamaEmbedding(String text) async {
    try {
      final response = await _client.post(
        Uri.parse('$customBaseUrl/api/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _model,
          'prompt': text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Ollama API Error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      final embedding = (data['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();

      return embedding;
    } catch (e) {
      print('Ollama Embedding Error: $e');
      rethrow;
    }
  }

  /// Helper to make BATCH API requests to local Ollama (/api/embed).
  /// This is much faster as it processes multiple texts in one HTTP call.
  Future<List<List<double>>> _generateOllamaBatchEmbedding(List<String> texts) async {
    try {
      final response = await _client.post(
        Uri.parse('$customBaseUrl/api/embed'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _model,
          'input': texts,
        }),
      );

      if (response.statusCode == 404) {
        // Fallback to legacy endpoint if /api/embed is missing (older Ollama versions)
        throw Exception('Endpoint /api/embed not found');
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Ollama Batch API Error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      final embeddings = (data['embeddings'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();

      return embeddings;
    } catch (e) {
      print('Ollama Batch Embedding Error: $e');
      rethrow;
    }
  }

  /// Generate an embedding vector for a single text.
  /// Results are cached by text content.
  Future<List<double>> generateEmbedding(String text) async {
    final cacheKey = text.hashCode.toString();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final embedding = await _generateOllamaEmbedding(text);
    _cache[cacheKey] = embedding;
    return embedding;
  }

  /// Generate embeddings for multiple texts.
  /// Ollama API is single-request, so we run these in parallel.
  Future<List<List<double>>> generateBatchEmbeddings(
      List<String> texts) async {
    if (texts.isEmpty) return [];

    // Check cache first
    final results = List<List<double>?>.filled(texts.length, null);
    final uncachedIndices = <int>[];

    for (int i = 0; i < texts.length; i++) {
      final cacheKey = texts[i].hashCode.toString();
      if (_cache.containsKey(cacheKey)) {
        results[i] = _cache[cacheKey]!;
      } else {
        uncachedIndices.add(i);
      }
    }

    if (uncachedIndices.isEmpty) {
      return results.cast<List<double>>();
    }

    // Try batch endpoint first (Ollama 0.1.33+)
    try {
      final batchEmbeddings = await _generateOllamaBatchEmbedding(uncachedIndices.map((i) => texts[i]).toList());
      
      for (int i = 0; i < uncachedIndices.length; i++) {
        final index = uncachedIndices[i];
        final embedding = batchEmbeddings[i];
        results[index] = embedding;
        _cache[texts[index].hashCode.toString()] = embedding;
      }
      
      return results.cast<List<double>>();
    } catch (e) {
      print('Batch embedding failed ($e), falling back to individual processing...');
    }

    // Fallback: Process uncached items in parallel batches (e.g., 5 at a time)
    const batchSize = 5;
    for (var i = 0; i < uncachedIndices.length; i += batchSize) {
      final end = (i + batchSize < uncachedIndices.length)
          ? i + batchSize
          : uncachedIndices.length;
      final batchIndices = uncachedIndices.sublist(i, end);

      final futures = batchIndices.map((index) async {
        try {
          final text = texts[index];
          final embedding = await _generateOllamaEmbedding(text);
          results[index] = embedding;
          _cache[text.hashCode.toString()] = embedding;
        } catch (e) {
          print('Error processing batch item $index: $e');
          // Leave as null or fill with zeros?
          // If fetch fails, we can't rank it properly.
          // For now, let's assume it fails silently (null) which will cause crash later.
          // Better to fill with zeros.
           results[index] = List.filled(1024, 0.0); // bge-m3 is 1024 dim
        }
      });

      await Future.wait(futures);
    }

    return results.cast<List<double>>();
  }

  /// Compute cosine similarity between two embedding vectors.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

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

  /// Clear the embedding cache.
  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _client.close();
  }
}
