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
    
    // On Web, use a CORS proxy to bypass browser restrictions
    final uri = kIsWeb 
        ? Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(baseUri.toString())}') 
        : baseUri;

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'API Error ${response.statusCode}: ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data;
  }

  void dispose() {
    _client.close();
  }
}
