/// Represents a scholarly journal (source) from the backend.
class Journal {
  final String journalId;
  final String name;
  final String domain;
  final int paperCount;

  const Journal({
    required this.journalId,
    required this.name,
    required this.domain,
    this.paperCount = 0,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      journalId: json['journal_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      domain: json['domain'] as String? ?? 'other',
      paperCount: json['paper_count'] as int? ?? 0,
    );
  }
}
