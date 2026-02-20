/// User profile model — maps to the `login` table in Supabase.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String collegeName;
  final List<String> selectedDomains;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.collegeName,
    this.selectedDomains = const [],
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      collegeName: json['college_name'] as String? ?? '',
      selectedDomains: (json['selected_domains'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'college_name': collegeName,
      'selected_domains': selectedDomains,
    };
  }

  bool get hasSelectedDomains => selectedDomains.isNotEmpty;

  /// Returns a map of field labels that are empty/missing.
  /// Keys = DB column display name, Values = DB column key.
  Map<String, String> get missingFields {
    final missing = <String, String>{};
    if (fullName.isEmpty) missing['Full Name'] = 'full_name';
    if (collegeName.isEmpty) missing['College Name'] = 'college_name';
    // email is always provided (by Google or signup form)
    // password_hash is intentionally empty for Google users
    // selected_domains is handled by onboarding screen
    return missing;
  }

  /// Whether profile has missing required fields (excluding domains).
  bool get needsProfileCompletion => missingFields.isNotEmpty;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? collegeName,
    List<String>? selectedDomains,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      collegeName: collegeName ?? this.collegeName,
      selectedDomains: selectedDomains ?? this.selectedDomains,
      createdAt: createdAt,
    );
  }
}
