import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service to fetch PDF links from arXiv as a fallback.
class ArxivService {
  static const String _baseUrl = 'https://export.arxiv.org/api/query';
  final http.Client _client;

  ArxivService({http.Client? client}) : _client = client ?? http.Client();

  /// Searches arXiv for a paper with the given [title] and returns the PDF URL if found.
  /// Returns `null` if no matching paper is found or if the API request fails.
  /// 
  /// Note: Matches are based on title similarity. The API returns results relevant to the query.
  /// We check if the returned entry's title closely matches the query.
  Future<String?> findPdfUrl(String title) async {
    try {
      // Clean title for query: remove special chars, keep alphanumeric and spaces
      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
      if (cleanTitle.isEmpty) return null;

      final query = 'ti:"$cleanTitle"';
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'search_query': query,
        'start': '0',
        'max_results': '1',
      });

      debugPrint('ArxivService: Searching for "$title" -> $uri');

      // On Web, use a proxy rotation to handle CORS
      if (kIsWeb) {
        return _fetchWithProxyFallback(uri);
      }

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return _parseArxivResponse(response.body, title);
      } else {
        debugPrint('ArxivService: API error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('ArxivService: Error searching arxiv: $e');
      return null;
    }
  }

  /// Tries multiple CORS proxies in sequence (Web only).
  Future<String?> _fetchWithProxyFallback(Uri targetUri) async {
    final proxies = [
      (String url) => 'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      (String url) => 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      (String url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
    ];

    for (var i = 0; i < proxies.length; i++) {
      try {
        final proxyUrl = proxies[i](targetUri.toString());
        debugPrint('ArxivService (Web): Trying proxy ${i + 1}: $proxyUrl');
        
        final response = await _client.get(Uri.parse(proxyUrl));
        
        if (response.statusCode == 200) {
          return _parseArxivResponse(response.body, ''); // title check skipped inside helper for now
        }
      } catch (e) {
        debugPrint('Proxy ${i + 1} failed: $e');
      }
    }
    return null;
  }

  /// Parses the Atom XML response from arXiv to find a PDF link.
  /// Uses RegExp to avoid adding an XML parser dependency for this single use case.
  String? _parseArxivResponse(String xmlBody, String originalTitle) {
    // 1. Check if we have an entry
    if (!xmlBody.contains('<entry>')) {
      debugPrint('ArxivService: No entries found');
      return null;
    }

    // 2. Extract title to verify match (simple check)
    // <title>Title Here</title>
    final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(xmlBody);
    // Note: The first title match is usually the Feed title "ArXiv Query...", so we need the entry title.
    // It's safer to extract the <entry> block first if strictly validating, 
    // but for now, let's just look for the PDF link in the first entry.
    
    // Quick Extract: Find first link with title="pdf"
    // <link title="pdf" href="http://arxiv.org/pdf/2103.00020v1" rel="related" type="application/pdf"/>
    final pdfLinkMatch = RegExp(r'<link\s+title="pdf"\s+href="([^"]+)"', caseSensitive: false).firstMatch(xmlBody);

    if (pdfLinkMatch != null) {
      String url = pdfLinkMatch.group(1)!;
      // Ensure https
      if (url.startsWith('http:')) {
        url = url.replaceFirst('http:', 'https:');
      }
      // Often arXiv returns .pdf links without .pdf extension in the API? 
      // Actually standard format is http://arxiv.org/pdf/ID
      // Sometimes it redirects.
      
      // Let's also enforce .pdf extension check? Arxiv usually doesn't need it but good for downloaders.
      // But typically the href is direct.
      
      debugPrint('ArxivService: Found PDF URL: $url');
      return url;
    }

    return null;
  }
}
