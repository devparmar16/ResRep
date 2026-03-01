import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/paper.dart';
import '../models/conference.dart';

/// Result object containing papers and the next pagination cursor
class FeedResult {
  final List<Paper> papers;
  final String? nextCursor;

  FeedResult({required this.papers, this.nextCursor});
}

/// HTTP client wrapping all FastAPI backend endpoints.
class BackendApiService {
  final http.Client _client;

  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Feed ─────────────────────────────────────────────

  /// Fetch the user's feed from the backend using cursor-based pagination.
  Future<FeedResult> fetchFeed({
    required List<String> interests,
    String? publisher,
    String sort = 'recent',
    String cursor = '*',
    String? userId,
    bool ignoreCache = false,
  }) async {
    final queryParams = {
      'interests': interests.join(','),
      'sort': sort,
      'cursor': cursor,
    };
    if (publisher != null) queryParams['publisher'] = publisher;
    if (userId != null) queryParams['user_id'] = userId;
    if (ignoreCache) queryParams['ignore_cache'] = 'true';

    final uri = Uri.parse('${ApiConfig.baseUrl}/feed')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Feed API Error ${response.statusCode}: ${response.body}');
    }

    print('BackendApiService: Received ${response.statusCode} for Feed.');
    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    final nextCursor = data['next_cursor'] as String?;
    print('BackendApiService: Parsed ${papersList.length} papers. Next cursor: $nextCursor');
    
    final papers = papersList.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
    return FeedResult(papers: papers, nextCursor: nextCursor);
  }

  /// Force-refresh the user's feed (re-seeds with cursor=*).
  Future<FeedResult> refreshFeed({
    required List<String> interests,
    String? userId,
    bool ignoreCache = false,
  }) async {
    final queryParams = {
      'interests': interests.join(','),
    };
    if (userId != null) queryParams['user_id'] = userId;
    if (ignoreCache) queryParams['ignore_cache'] = 'true';

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
    final nextCursor = data['next_cursor'] as String?;
    
    final papers = papersList.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
    return FeedResult(papers: papers, nextCursor: nextCursor);
  }

  // ─── Journals ─────────────────────────────────────────

  /// Fetch journals for a domain with optional search and pagination.
  Future<List<Map<String, dynamic>>> fetchJournals({
    required String domain,
    String? query,
    int skip = 0,
    int limit = 20,
    bool ignoreCache = false,
  }) async {
    final queryParams = {
      if (query != null && query.isNotEmpty) 'query': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (ignoreCache) 'ignore_cache': 'true',
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

  /// Fetch journals across multiple domains (or 'all').
  Future<List<Map<String, dynamic>>> fetchJournalsMultiDomain({
    required List<String> domains,
    String? query,
    int skip = 0,
    int limit = 20,
    bool ignoreCache = false,
  }) async {
    final queryParams = {
      'domains': domains.join(','),
      if (query != null && query.isNotEmpty) 'query': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (ignoreCache) 'ignore_cache': 'true',
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/journals')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Journals Multi API Error ${response.statusCode}: ${response.body}');
    }

    final list = json.decode(response.body) as List<dynamic>;
    return list.map((j) => j as Map<String, dynamic>).toList();
  }

  /// Fetch papers for a specific journal.
  Future<FeedResult> fetchJournalPapers({
    required String journalId,
    String sort = 'top',
    String cursor = '*',
    String? query,
    bool ignoreCache = false,
  }) async {
    final queryParams = {
      'sort': sort,
      'cursor': cursor,
    };
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }
    if (ignoreCache) {
      queryParams['ignore_cache'] = 'true';
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

    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    final nextCursor = data['next_cursor'] as String?;
    
    final papers = papersList.map((p) => _paperFromBackend(p as Map<String, dynamic>)).toList();
    return FeedResult(papers: papers, nextCursor: nextCursor);
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
    int skip = 0,
    bool ignoreCache = false,
  }) async {
    final path = domain != null && domain.isNotEmpty
        ? '/social-trending/$domain'
        : '/social-trending';

    final queryParams = {
      'limit': limit.toString(),
      'skip': skip.toString(),
      if (ignoreCache) 'ignore_cache': 'true',
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Social Trending API Error ${response.statusCode}: ${response.body}');
    }

    print('BackendApiService: Received ${response.statusCode} for Social Trending. Body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
    final data = json.decode(response.body) as Map<String, dynamic>;
    final papersList = data['papers'] as List<dynamic>? ?? [];
    print('BackendApiService: Parsed ${papersList.length} papers for Social Trending');
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

  // ─── Conferences ─────────────────────────────────────

  /// Fetch live conferences from PredictHQ.
  Future<List<Conference>> fetchConferences({
    String? mode,
    String? country,
    String? domain,
    String? publisher,
    int limit = 50,
    int skip = 0,
  }) async {
    final queryParams = {
      'limit': limit.toString(),
      'skip': skip.toString(),
    };
    if (mode != null && mode.isNotEmpty) queryParams['mode'] = mode;
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (domain != null && domain.isNotEmpty) queryParams['domain'] = domain;
    if (publisher != null && publisher.isNotEmpty) queryParams['publisher'] = publisher;

    final uri = Uri.parse('${ApiConfig.baseUrl}/conferences')
        .replace(queryParameters: queryParams);

    print('BackendApiService: GET $uri');
    final response = await _client
        .get(uri)
        .timeout(ApiConfig.receiveTimeout);

    if (response.statusCode != 200) {
      throw Exception('Conferences API Error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final confList = data['conferences'] as List<dynamic>? ?? [];
    return confList.map((c) => Conference.fromJson(c as Map<String, dynamic>)).toList();
  }

  // ─── Helpers ──────────────────────────────────────────

  /// Convert backend JSON response to Paper model.
  /// Maps backend field names to existing Paper model fields.
  Paper _paperFromBackend(Map<String, dynamic> json) {
    try {
      final mapped = <String, dynamic>{
        'paperId': json['paper_id'] ?? '',
        'title': json['title'] ?? 'Untitled',
        'abstract': json['abstract'],
        'year': json['year'],
        'citationCount': json['citation_count'] ?? 0,
        'url': json['source_url'] ?? json['landing_page_url'],
        'openAccessPdf': json['pdf_url'] != null
            ? {'url': json['pdf_url']}
            : null,
        'externalIds': json['doi'] != null ? {'DOI': json['doi']} : null,
        'authors': (json['authors'] as List<dynamic>?)
                ?.map((a) => {'name': a})
                .toList() ??
            [],
        'fieldsOfStudy': json['fields_of_study'] ?? [],
        'domain': json['domain'],
        'subdomain': json['subdomain'],
        'tldr': (json['summary'] != null && json['summary'] is String) ? {'text': json['summary']} : null,
        'publisher': json['publisher'],
        'journal': json['journal'],
        'journal_id': json['journal_id'],
        'landing_page_url': json['landing_page_url'],
        'pdf_url': json['pdf_url'],
        'is_open_access': json['is_open_access'],
      };
      return Paper.fromJson(mapped);
    } catch (e) {
      print('ERROR IN _paperFromBackend: $e');
      print('JSON: $json');
      rethrow;
    }
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
