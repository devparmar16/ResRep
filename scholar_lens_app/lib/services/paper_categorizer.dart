import '../models/domain.dart';
import '../models/paper.dart';

/// Categorizes a paper into a domain by keyword matching
/// against the paper's title and abstract.
class PaperCategorizer {
  /// Assign a domain to the given paper based on keyword matching.
  static PaperDomain categorize(Paper paper) {
    final text =
        '${paper.title} ${paper.abstract_ ?? ''}'.toLowerCase();

    PaperDomain bestDomain = PaperDomain.other;
    int bestScore = 0;

    for (final domainInfo in DomainInfo.allDomains) {
      if (domainInfo.domain == PaperDomain.other) continue;

      int score = 0;
      for (final keyword in domainInfo.keywords) {
        if (text.contains(keyword)) {
          score++;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestDomain = domainInfo.domain;
      }
    }

    return bestDomain;
  }

  /// Categorize a list of papers and return new copies with domains assigned.
  static List<Paper> categorizeAll(List<Paper> papers) {
    return papers.map((paper) {
      final domain = categorize(paper);
      return paper.copyWithDomain(domain);
    }).toList();
  }
}
