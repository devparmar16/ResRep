// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result model for AI paper analysis.
class PaperInsight {
  final String eli5Summary;
  final List<String> keyTakeaways;
  final String difficultyLevel; // "Beginner", "Intermediate", "Expert"
  final List<String> jargonWords; // Detected jargon words

  PaperInsight({
    required this.eli5Summary,
    required this.keyTakeaways,
    required this.difficultyLevel,
    required this.jargonWords,
  });
}

/// Service for AI-powered paper analysis.
/// Uses a free OpenAI-compatible LLM API (llm7.io) for:
/// - ELI5 (plain language) summaries
/// - Key takeaways
/// - Jargon detection and explanation
/// - Difficulty level classification
class AIPaperService {
  final http.Client _client;

  /// Free LLM API endpoint (OpenAI-compatible, no API key needed).
  static const String _apiUrl = 'https://api.llm7.io/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';

  // In-memory cache: paperId -> PaperInsight
  final Map<String, PaperInsight> _insightCache = {};
  // Jargon explanation cache: word -> definition
  final Map<String, String> _jargonCache = {};

  AIPaperService({http.Client? client}) : _client = client ?? http.Client();

  /// Get complete AI insights for a paper (cached).
  Future<PaperInsight> getInsights(String paperId, String? abstract_) async {
    if (_insightCache.containsKey(paperId)) {
      return _insightCache[paperId]!;
    }

    if (abstract_ == null || abstract_.isEmpty) {
      final fallback = PaperInsight(
        eli5Summary: 'No abstract available to analyze.',
        keyTakeaways: ['Abstract not available for this paper.'],
        difficultyLevel: 'Unknown',
        jargonWords: [],
      );
      _insightCache[paperId] = fallback;
      return fallback;
    }

    final systemPrompt =
        'You are a research paper explainer. You make complex academic papers accessible to non-experts while preserving important technical details.';

    final userPrompt = '''Given this paper abstract, provide ALL of the following in the EXACT format shown:

ABSTRACT:
$abstract_

---

Respond in EXACTLY this format (no extra text):

SUMMARY: [Provide a detailed but to-the-point explanation of the abstract. Explain the core problem, methodology, and results clearly without omitting important technical context. 3-5 sentences.]

TAKEAWAY1: [What did they find or do? One sentence.]
TAKEAWAY2: [Why does it matter? One sentence.]
TAKEAWAY3: [What can someone do with this? One sentence.]

DIFFICULTY: [Exactly one of: Beginner, Intermediate, Expert]

JARGON: [Comma-separated list of 3-6 technical/jargon words from the abstract that a non-expert might not know]''';

    try {
      final responseText = await _chatCompletion(systemPrompt, userPrompt);
      final insight = _parseInsightResponse(responseText);
      _insightCache[paperId] = insight;
      return insight;
    } catch (e) {
      print('AIPaperService: Error getting insights: $e');
      rethrow;
    }
  }

  /// Explain a specific jargon word in context (cached).
  Future<String> explainJargon(String word, String? context) async {
    final key = word.toLowerCase().trim();
    if (_jargonCache.containsKey(key)) {
      return _jargonCache[key]!;
    }

    final contextStr = context != null ? ' in the context of: "$context"' : '';
    final userPrompt =
        'Define the technical term "$word"$contextStr in one simple sentence that a non-expert can understand. Just give the definition, nothing else.';

    try {
      final definition = await _chatCompletion(
        'You are a helpful dictionary that explains technical terms simply.',
        userPrompt,
      );
      _jargonCache[key] = definition.trim();
      return definition.trim();
    } catch (e) {
      print('AIPaperService: Error explaining jargon "$word": $e');
      return 'Could not load definition.';
    }
  }

  /// Call the free LLM API (OpenAI chat completions format).
  Future<String> _chatCompletion(String systemPrompt, String userPrompt) async {
    final response = await _client.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 600,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final choices = decoded['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? '';
      }
      throw Exception('No choices in API response');
    } else if (response.statusCode == 429) {
      // Rate limited — wait and retry once
      print('AIPaperService: Rate limited, waiting 5s...');
      await Future.delayed(const Duration(seconds: 5));
      final retry = await _client.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': 600,
          'temperature': 0.3,
        }),
      );
      if (retry.statusCode == 200) {
        final decoded = json.decode(retry.body);
        final choices = decoded['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
      }
      throw Exception('API Error ${retry.statusCode}: ${retry.body}');
    } else {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }
  }

  /// Parse the structured insight response.
  PaperInsight _parseInsightResponse(String text) {
    // Parse Summary (or ELI5 for backwards compatibility)
    String eli5 = 'Summary not available.';
    final summaryMatch = RegExp(r'(?:SUMMARY|ELI5):\s*(.+?)(?=\nTAKEAWAY1:|\n\n|$)', dotAll: true).firstMatch(text);
    if (summaryMatch != null) {
      eli5 = summaryMatch.group(1)!.trim();
    }

    // Parse takeaways
    final takeaways = <String>[];
    for (var i = 1; i <= 3; i++) {
      final match = RegExp('TAKEAWAY$i:\\\\s*(.+?)(?=\\\\nTAKEAWAY|\\\\nDIFFICULTY|\\\\n\\\\n|\$)', dotAll: true)
          .firstMatch(text);
      if (match != null) {
        takeaways.add(match.group(1)!.trim());
      }
    }
    if (takeaways.isEmpty) {
      takeaways.add('Key takeaways not available.');
    }

    // Parse difficulty
    String difficulty = 'Intermediate';
    final diffMatch = RegExp(r'DIFFICULTY:\s*(Beginner|Intermediate|Expert)', caseSensitive: false)
        .firstMatch(text);
    if (diffMatch != null) {
      difficulty = diffMatch.group(1)!;
      // Normalize capitalization
      difficulty = difficulty[0].toUpperCase() + difficulty.substring(1).toLowerCase();
    }

    // Parse jargon
    List<String> jargon = [];
    final jargonMatch = RegExp(r'JARGON:\s*(.+?)(?=\n\n|$)', dotAll: true).firstMatch(text);
    if (jargonMatch != null) {
      jargon = jargonMatch
          .group(1)!
          .split(',')
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty && w.length > 2)
          .toList();
    }

    return PaperInsight(
      eli5Summary: eli5,
      keyTakeaways: takeaways,
      difficultyLevel: difficulty,
      jargonWords: jargon,
    );
  }

  void dispose() {
    _client.close();
  }
}
