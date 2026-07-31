class LocationPoint {
  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speed,
    this.altitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime? recordedAt;
  final double? speed;
  final double? altitude;
  final double? accuracy;

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();

    return LocationPoint(
      latitude: asDouble(json['latitude']) ?? 0,
      longitude: asDouble(json['longitude']) ?? 0,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
      speed: asDouble(json['speed']),
      altitude: asDouble(json['altitude']),
      accuracy: asDouble(json['accuracy']),
    );
  }
}
