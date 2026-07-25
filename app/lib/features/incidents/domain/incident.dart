class Incident {
  const Incident({
    required this.incidentId,
    required this.category,
    required this.emoji,
    required this.title,
    required this.description,
    required this.locationType,
    required this.areaName,
    required this.occurredAt,
    required this.latitude,
    required this.longitude,
  });

  final String incidentId;
  final String category;
  final String emoji;
  final String title;
  final String description;
  final String locationType;
  final String areaName;
  final DateTime occurredAt;
  final double latitude;
  final double longitude;

  static Incident? tryFromJson(Map<String, dynamic> json) {
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (json['incidentId'] is! String ||
        json['category'] is! String ||
        json['emoji'] is! String ||
        json['title'] is! String ||
        json['description'] is! String ||
        json['locationType'] is! String ||
        json['areaName'] is! String ||
        occurredAt == null ||
        latitude is! num ||
        longitude is! num) {
      return null;
    }

    return Incident(
      incidentId: json['incidentId'] as String,
      category: json['category'] as String,
      emoji: json['emoji'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      locationType: json['locationType'] as String,
      areaName: json['areaName'] as String,
      occurredAt: occurredAt,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}
