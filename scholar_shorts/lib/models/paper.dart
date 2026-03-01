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
  final String? journal;
  final String? journalId;
  final String? publicationDate;
  final String? landingPageUrl;
  final String? pdfUrl;
  final bool isOpenAccess;

  final String? tldr; // "Too Long; Didn't Read" summary
  final String? subdomain; // Specific domain tag
  final String? publisher; // Publisher name (IEEE, Springer, etc.)

  Paper({
    required this.paperId,
    required this.title,
    this.abstract_,
    this.tldr,
    this.year,
    this.citationCount = 0,
    this.url,
    this.openAccessPdfUrl,
    this.doi,
    this.authors = const [],
    this.fieldsOfStudy = const [],
    this.domain = PaperDomain.other,
    this.subdomain,
    this.journal,
    this.journalId,
    this.publicationDate,
    this.landingPageUrl,
    this.pdfUrl,
    this.isOpenAccess = false,
    this.publisher,
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
    final openAccessPdfUrl = (openAccessPdf != null && openAccessPdf.containsKey('url')) 
        ? openAccessPdf['url'] as String? 
        : null;
    final tldrMap = json['tldr'] as Map<String, dynamic>?;

    return Paper(
      paperId: json['paperId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      abstract_: json['abstract'] as String?,
      tldr: tldrMap?['text'] as String?,
      year: json['year'] as int?,
      citationCount: json['citationCount'] as int? ?? 0,
      url: json['url'] as String?,
      openAccessPdfUrl: openAccessPdfUrl,
      doi: json['doi'] as String? ?? externalIds?['DOI'] as String?,
      authors: authorsList,
      fieldsOfStudy: fields,
      domain: DomainInfo.getById(json['domain'] as String? ?? 'other').domain,
      subdomain: json['subdomain'] as String?,
      journal: json['journal'] as String?,
      journalId: json['journal_id'] as String?,
      publicationDate: json['publication_date'] as String?,
      landingPageUrl: json['landing_page_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      isOpenAccess: json['is_open_access'] as bool? ?? false,
      publisher: json['publisher'] as String?,
    );
  }

  /// Returns a copy of this paper with the given domain assigned.
  Paper copyWithDomain(PaperDomain newDomain) {
    return Paper(
      paperId: paperId,
      title: title,
      abstract_: abstract_,
      tldr: tldr,
      year: year,
      citationCount: citationCount,
      url: url,
      openAccessPdfUrl: openAccessPdfUrl,
      doi: doi,
      authors: authors,
      fieldsOfStudy: fieldsOfStudy,
      domain: newDomain,
      subdomain: subdomain,
      journal: journal,
      journalId: journalId,
      publicationDate: publicationDate,
      landingPageUrl: landingPageUrl,
      pdfUrl: pdfUrl,
      isOpenAccess: isOpenAccess,
      publisher: publisher,
    );
  }
}
