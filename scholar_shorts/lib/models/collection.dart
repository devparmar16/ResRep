/// Model for a user-created paper collection (bookmark folder).
/// Maps to the `collections` table in Supabase.
class Collection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPrivate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int paperCount; // Populated from JOINs, not stored

  const Collection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isPrivate = true,
    this.createdAt,
    this.updatedAt,
    this.paperCount = 0,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isPrivate: json['is_private'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      paperCount: json['paper_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'description': description,
      'is_private': isPrivate,
    };
  }

  Collection copyWith({
    String? name,
    String? description,
    bool? isPrivate,
    int? paperCount,
  }) {
    return Collection(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      paperCount: paperCount ?? this.paperCount,
    );
  }
}
