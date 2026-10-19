/// One SOS alert with a GPS snapshot (no continuous tracking).
class SosAlert {
  const SosAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.accuracyMeters,
    this.tripId,
    this.status = 'open',
    this.note,
  });

  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? tripId;
  final String status;
  final String? note;
  final DateTime createdAt;

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class SosFailure implements Exception {
  const SosFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// GPS reading used for the SOS snapshot.
class GeoSnapshot {
  const GeoSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}
