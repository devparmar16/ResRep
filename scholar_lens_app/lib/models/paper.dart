import 'domain.dart';

/// Represents a research paper from Semantic Scholar.
class Paper {
  final String paperId;
  final String title;
  final String? abstract_;
  final int? year;
  final int citationCount;
  final String? url;
  final String? openAccessPdfUrl;
  final String? doi;
  final List<String> authors;
  final List<String> fieldsOfStudy;
  final PaperDomain domain;

  Paper({
    required this.paperId,
    required this.title,
    this.abstract_,
    this.year,
    this.citationCount = 0,
    this.url,
    this.openAccessPdfUrl,
    this.doi,
    this.authors = const [],
    this.fieldsOfStudy = const [],
    this.domain = PaperDomain.other,
  });

  /// Create a Paper from the Semantic Scholar API JSON response.
  factory Paper.fromJson(Map<String, dynamic> json) {
    final authorsList = (json['authors'] as List<dynamic>?)
            ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    final fields = (json['fieldsOfStudy'] as List<dynamic>?)
            ?.map((f) => f.toString())
            .toList() ??
        [];

    final externalIds = json['externalIds'] as Map<String, dynamic>?;
    final openAccessPdf = json['openAccessPdf'] as Map<String, dynamic>?;

    return Paper(
      paperId: json['paperId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      abstract_: json['abstract'] as String?,
      year: json['year'] as int?,
      citationCount: json['citationCount'] as int? ?? 0,
      url: json['url'] as String?,
      openAccessPdfUrl: openAccessPdf?['url'] as String?,
      doi: externalIds?['DOI'] as String?,
      authors: authorsList,
      fieldsOfStudy: fields,
    );
  }

  /// Returns a copy of this paper with the given domain assigned.
  Paper copyWithDomain(PaperDomain newDomain) {
    return Paper(
      paperId: paperId,
      title: title,
      abstract_: abstract_,
      year: year,
      citationCount: citationCount,
      url: url,
      openAccessPdfUrl: openAccessPdfUrl,
      doi: doi,
      authors: authors,
      fieldsOfStudy: fieldsOfStudy,
      domain: newDomain,
    );
  }
}
