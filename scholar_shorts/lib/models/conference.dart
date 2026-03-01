class Conference {
  final String id;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? venueName;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String mode; // online, offline, hybrid
  final String? url;
  final List<String> labels;
  final String? publisher;
  final String? domain;

  Conference({
    required this.id,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.venueName,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    required this.mode,
    this.url,
    this.labels = const [],
    this.publisher,
    this.domain,
  });

  factory Conference.fromJson(Map<String, dynamic> json) {
    return Conference(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Conference',
      description: json['description'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      venueName: json['venue_name'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mode: json['mode'] as String? ?? 'offline',
      url: json['url'] as String?,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((l) => l.toString())
              .toList() ??
          [],
      publisher: json['publisher'] as String?,
      domain: json['domain'] as String?,
    );
  }

  /// Human-readable location string
  String get locationString {
    final parts = <String>[];
    if (venueName != null && venueName!.isNotEmpty) parts.add(venueName!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  /// Google Maps URL from coordinates
  String? get mapsUrl {
    if (latitude != null && longitude != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }
    return null;
  }
}
