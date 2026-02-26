import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/paper.dart';

/// HTTP client wrapping all FastAPI backend endpoints.
class BackendApiService {
  final http.Client _client;

  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Feed ─────────────────────────────────────────────

  /// Fetch the user's feed snapshot from the backend.
  Future<List<Paper>> fetchFeed({
    required String userId,
    required List<String> interests,
  }) async {
    final queryParams = {
      'user_id': userId,
      'interests': interests.join(','),
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/feed')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Feed API Error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    return papersList.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
  }

  /// Force-refresh the user's feed.
  Future<List<Paper>> refreshFeed({
    required String userId,
    required List<String> interests,
  }) async {
    final queryParams = {
      'user_id': userId,
      'interests': interests.join(','),
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/feed/refresh')
        .replace(queryParameters: queryParams);

    print('BackendApiService: POST $uri');
    final response = await _client
        .post(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Feed Refresh API Error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    return papersList.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
  }

  // ─── Journals ─────────────────────────────────────────

  /// Fetch journals for a domain with optional search and pagination.
  Future<List<Map<String, dynamic>>> fetchJournals({
    required String domain,
    String? query,
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = {
      if (query != null && query.isNotEmpty) 'query': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/journals/$domain')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Journals API Error ${response.statusCode}: ${response.body}');
    }

    final list = json.decode(response.body) as List<dynamic>;
    return list.map((j) => j as Map<String, dynamic>).toList();
  }

  /// Fetch papers for a specific journal.
  Future<List<Paper>> fetchJournalPapers({
    required String journalId,
    String sort = 'top',
    String? query,
  }) async {
    final queryParams = {'sort': sort};
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }
    
    final uri = Uri.parse('${ApiConfig.baseUrl}/journals/$journalId/papers')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Journal Papers API Error ${response.statusCode}: ${response.body}');
    }

    final list = json.decode(response.body) as List<dynamic>;
    return list.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
  }

  // ─── Engagement ───────────────────────────────────────

  /// Track a user interaction with a paper (click, read, save).
  Future<void> trackEngagement({
    required String paperId,
    required String action, // 'click', 'read', or 'save'
    String? domain,
    String? subdomain,
  }) async {
    final queryParams = {
      'paper_id': paperId,
      'action': action,
      if (domain != null && domain.isNotEmpty) 'domain': domain,
      if (subdomain != null && subdomain.isNotEmpty) 'subdomain': subdomain,
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/engagement/track')
        .replace(queryParameters: queryParams);

    print('BackendApiService: POST $uri');
    try {
      final response = await _client.post(uri).timeout(ApiConfig.receiveTimeout);
      if (response.statusCode != 200) {
        print('Warning: Engagement tracking failed ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Warning: Engagement tracking error: $e');
    }
  }

  // ─── Social Trending ─────────────────────────────────

  /// Fetch socially trending papers, optionally filtered by domain.
  Future<List<TrendingPaper>> fetchSocialTrending({
    String? domain,
    int limit = 30,
  }) async {
    final path = domain != null && domain.isNotEmpty
        ? '/social-trending/$domain'
        : '/social-trending';

    final queryParams = {'limit': limit.toString()};
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Social Trending API Error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    return papersList.map((p) {
      final map = p as Map<String, dynamic>;
      final paper = _paperFromBackend(map);
      final sources = (map['trending_sources'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [];
      final socialScore = (map['social_score'] as num?)?.toDouble() ?? 0.0;
      return TrendingPaper(paper: paper, trendingSources: sources, socialScore: socialScore);
    }).toList();
  }

  // ─── Helpers ──────────────────────────────────────────

  /// Convert backend JSON response to Paper model.
  /// Maps backend field names to existing Paper model fields.
  Paper _paperFromBackend(Map<String, dynamic> json) {
    // Map backend fields -> existing Paper.fromJson-compatible format
    final mapped = <String, dynamic>{
      'paperId': json['paper_id'] ?? '',
      'title': json['title'] ?? 'Untitled',
      'abstract': json['abstract'],
      'year': json['year'],
      'citationCount': json['citation_count'] ?? 0,
      'url': json['source_url'],
      'openAccessPdf': json['open_access_pdf_url'] != null
          ? {'url': json['open_access_pdf_url']}
          : null,
      'externalIds': json['doi'] != null ? {'DOI': json['doi']} : null,
      'authors': (json['authors'] as List<dynamic>?)
              ?.map((a) => {'name': a})
              .toList() ??
          [],
      'fieldsOfStudy': json['fields_of_study'] ?? [],
      'domain': json['domain'],
      'subdomain': json['subdomain'],
      'tldr': json['summary'] != null ? {'text': json['summary']} : null,
    };
    return Paper.fromJson(mapped);
  }

  void dispose() {
    _client.close();
  }
}


/// A paper with social trending metadata.
class TrendingPaper {
  final Paper paper;
  final List<String> trendingSources;
  final double socialScore;

  const TrendingPaper({
    required this.paper,
    this.trendingSources = const [],
    this.socialScore = 0.0,
  });
}
