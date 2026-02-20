import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // for kIsWeb

/// Service class for communicating with the Semantic Scholar API.
class SemanticScholarService {
  static const String _baseUrl = 'https://api.semanticscholar.org/graph/v1';
  static const String _fields =
      'title,abstract,year,fieldsOfStudy,citationCount,url,authors,openAccessPdf,externalIds';
  static const int perPage = 30;

  final http.Client _client;

  SemanticScholarService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch papers from the Semantic Scholar API.
  /// Returns a Map with 'total' (int) and 'data' (List of dynamic).
  /// Optional [sort] param: 'publicationDate:desc', 'citationCount:desc', etc.
  /// Optional [year] param: e.g. '2024-2025' to filter by year range.
  Future<Map<String, dynamic>> fetchPapers(
    String query, {
    int offset = 0,
    int limit = perPage,
    String? sort,
    String? year,
  }) async {
    final params = <String, String>{
      'query': query,
      'offset': offset.toString(),
      'limit': limit.toString(),
      'fields': _fields,
    };
    if (sort != null) params['sort'] = sort;
    if (year != null) params['year'] = year;

    final baseUri = Uri.parse('$_baseUrl/paper/search')
        .replace(queryParameters: params);
    
    // On Web, use a proxy rotation to handle rate limits
    if (kIsWeb) {
      return _fetchWithProxyFallback(baseUri);
    }

    // Mobile/Desktop: Direct call
    print('SemanticScholarService: Requesting $baseUri');
    final response = await _client.get(baseUri);

    print('SemanticScholarService: Response Code ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('SemanticScholarService: Error Body: ${response.body}');
      throw Exception(
        'API Error ${response.statusCode}: ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final papers = data['data'] as List?;
    print('SemanticScholarService: Success. Found ${data['total']} total, returned ${papers?.length} papers.');
    
    return data;
  }

  /// Tries multiple CORS proxies in sequence if one fails (429 or other error).
  Future<Map<String, dynamic>> _fetchWithProxyFallback(Uri baseUri) async {
    final proxies = [
      (String url) => 'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      (String url) => 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      (String url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
    ];

    Object? lastError;
    
    print('SemanticScholarService (Web): Target URI: $baseUri');

    for (var i = 0; i < proxies.length; i++) {
      try {
        final proxyUrl = proxies[i](baseUri.toString());
        print('SemanticScholarService (Web): Trying proxy ${i + 1}/${proxies.length}: $proxyUrl');
        
        final response = await _client.get(Uri.parse(proxyUrl));
        
        if (response.statusCode == 200) {
          print('SemanticScholarService (Web): Proxy ${i + 1} returned 200. Body length: ${response.body.length}');
          print('SemanticScholarService (Web): Body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          final data = json.decode(response.body) as Map<String, dynamic>;
          final papers = data['data'] as List?;
          print('SemanticScholarService (Web): Proxy ${i + 1} Success. total=${data['total']}, returned=${papers?.length} papers.');
          return data;
        } else if (response.statusCode == 429) {
          print('Proxy ${i + 1} hit rate limit (429). Trying next...');
          lastError = 'API Error 429: ${response.body}';
          continue; // Try next proxy
        } else {
           // Other error, probably API related, but might be proxy related too
           lastError = 'API Error ${response.statusCode}: ${response.body}';
           // If 5xx, maybe proxy is down, try next
           if (response.statusCode >= 500) continue;
           throw Exception(lastError);
        }
      } catch (e) {
        print('Proxy ${i + 1} failed: $e');
        lastError = e;
        // Try next
      }
    }

    throw Exception('All proxies failed. Last error: $lastError');
  }

  void dispose() {
    _client.close();
  }
}
