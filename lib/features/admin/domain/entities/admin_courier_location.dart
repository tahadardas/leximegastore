import '../../../../core/utils/safe_parsers.dart';

class AdminCourierLocation {
  final int courierId;
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? heading;
  final double? speedMps;
  final String updatedAt;
  final String updatedAtLocal;
  final int? ageMinutes;
  final bool isOutdated;
  final int staleAfterMinutes;
  final String mapsNavigateUrl;
  final String mapsOpenUrl;

  const AdminCourierLocation({
    required this.courierId,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.heading,
    required this.speedMps,
    required this.updatedAt,
    required this.updatedAtLocal,
    required this.ageMinutes,
    required this.isOutdated,
    required this.staleAfterMinutes,
    required this.mapsNavigateUrl,
    required this.mapsOpenUrl,
  });

  factory AdminCourierLocation.fromJson(Map<String, dynamic> json) {
    return AdminCourierLocation(
      courierId: parseInt(json['courier_id']),
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
      accuracyM: parseDoubleNullable(json['accuracy_m']),
      heading: parseDoubleNullable(json['heading']),
      speedMps: parseDoubleNullable(json['speed_mps']),
      updatedAt: (json['updated_at'] ?? '').toString(),
      updatedAtLocal: (json['updated_at_local'] ?? '').toString(),
      ageMinutes: parseInt(json['age_minutes']) > 0
          ? parseInt(json['age_minutes'])
          : parseInt(json['age_minutes']) == 0
          ? 0
          : null,
      isOutdated: parseBool(json['is_outdated']),
      staleAfterMinutes: parseInt(json['stale_after_minutes']) > 0
          ? parseInt(json['stale_after_minutes'])
          : 10,
      mapsNavigateUrl: (json['maps_navigate_url'] ?? '').toString(),
      mapsOpenUrl: (json['maps_open_url'] ?? '').toString(),
    );
  }
}
