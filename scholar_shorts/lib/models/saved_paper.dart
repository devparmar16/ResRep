/// Model for a paper saved into a collection.
/// Maps to the `saved_papers` table in Supabase.
class SavedPaper {
  final String id;
  final String userId;
  final String collectionId;
  final String openalexId;
  final String? title;
  final String? journalName;
  final DateTime? publicationDate;
  final bool? isOpenAccess;
  final DateTime? savedAt;
  final String? collectionName; // Populated via JOIN

  const SavedPaper({
    required this.id,
    required this.userId,
    required this.collectionId,
    required this.openalexId,
    this.title,
    this.journalName,
    this.publicationDate,
    this.isOpenAccess,
    this.savedAt,
    this.collectionName,
  });

  factory SavedPaper.fromJson(Map<String, dynamic> json) {
    // Handle nested collection name from joins
    String? colName;
    if (json['collections'] != null && json['collections'] is Map) {
      colName = (json['collections'] as Map)['name'] as String?;
    }
    colName ??= json['collection_name'] as String?;

    return SavedPaper(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      collectionId: json['collection_id'] as String,
      openalexId: json['openalex_id'] as String,
      title: json['title'] as String?,
      journalName: json['journal_name'] as String?,
      publicationDate: json['publication_date'] != null
          ? DateTime.tryParse(json['publication_date'] as String)
          : null,
      isOpenAccess: json['is_open_access'] as bool?,
      savedAt: json['saved_at'] != null
          ? DateTime.tryParse(json['saved_at'] as String)
          : null,
      collectionName: colName,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'collection_id': collectionId,
      'openalex_id': openalexId,
      'title': title,
      'journal_name': journalName,
      'publication_date': publicationDate?.toIso8601String().split('T').first,
      'is_open_access': isOpenAccess,
    };
  }
}
