import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'sos_models.dart';

abstract class LocationService {
  Future<GeoSnapshot> currentSnapshot();
}

/// Real device / browser GPS. Falls back with a clear error if denied.
class DeviceLocationService implements LocationService {
  @override
  Future<GeoSnapshot> currentSnapshot() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const SosFailure(
        'Activez la localisation (GPS) sur cet appareil.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const SosFailure(
        'Permission de localisation refusée. Autorisez-la dans les réglages.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
        // Web needs a longer timeout sometimes.
        distanceFilter: kIsWeb ? 0 : 0,
      ),
    );
    return GeoSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }
}

/// Fixed coordinates for widget tests / demo without GPS hardware.
class MockLocationService implements LocationService {
  const MockLocationService({
    this.latitude = 36.8065,
    this.longitude = 10.1815,
  });

  final double latitude;
  final double longitude;

  @override
  Future<GeoSnapshot> currentSnapshot() async => GeoSnapshot(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 12,
  );
}
