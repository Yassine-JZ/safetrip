import 'dart:async';

import '../../auth/data/mock_auth_repository.dart';
import '../../trips/data/trip.dart';
import '../../trips/data/trip_repository.dart';
import 'profile_models.dart';
import 'profile_repository.dart';

/// In-memory profiles for demo mode, fed by the demo accounts.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._auth);

  final MockAuthRepository _auth;
  static const _latency = Duration(milliseconds: 500);

  final _profiles = <String, UserProfile>{};
  final _vehicles = <String, Vehicle>{};
  final _profileStreams = <String, StreamController<UserProfile?>>{};
  final _vehicleStreams = <String, StreamController<Vehicle?>>{};

  /// Lets tests simulate a commitment without creating a trip.
  DriverCommitment commitment = DriverCommitment.none;

  /// When set, a real ongoing trip or an accepted booking blocks deactivation.
  TripRepository? trips;

  StreamController<T?> _controller<T>(
    Map<String, StreamController<T?>> streams,
    String uid,
  ) => streams.putIfAbsent(uid, StreamController<T?>.broadcast);

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _watch(_profileStreams, uid, () => _profiles[uid]);

  @override
  Future<void> ensureProfile(String uid, {required String displayName}) async {
    if (_profiles.containsKey(uid)) return;
    final parts = displayName.trim().split(RegExp(r'\s+'));
    _setProfile(
      UserProfile(
        uid: uid,
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
      ),
    );
  }

  @override
  Future<PrivateInfo?> privateInfo(String uid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) return null;
    return PrivateInfo(
      email: user.email,
      phone: await _auth.registeredPhone() ?? '',
    );
  }

  @override
  Stream<Vehicle?> watchVehicle(String uid) =>
      _watch(_vehicleStreams, uid, () => _vehicles[uid]);

  /// Replays the current value, then later changes. The inner stream is
  /// listened to before the first event, so a listener that writes during
  /// that event is not missed.
  Stream<T?> _watch<T>(
    Map<String, StreamController<T?>> streams,
    String uid,
    T? Function() current,
  ) {
    return Stream<T?>.multi((multi) {
      final sub = _controller(streams, uid).stream.listen(multi.add);
      multi.onCancel = sub.cancel;
      multi.add(current());
    });
  }

  @override
  Future<void> updateName(
    String uid, {
    required String firstName,
    required String lastName,
  }) async {
    await Future<void>.delayed(_latency);
    _setProfile(
      _require(uid).copyWith(firstName: firstName, lastName: lastName),
    );
    _auth.updateDisplayName('$firstName $lastName');
  }

  @override
  Future<void> updatePhoto(String uid, String? photoUrl) async {
    await Future<void>.delayed(_latency);
    _setProfile(_require(uid).copyWith(photoUrl: () => photoUrl));
  }

  @override
  Future<void> saveVehicle(
    String uid,
    Vehicle vehicle, {
    bool enableDriver = false,
  }) async {
    await Future<void>.delayed(_latency);
    _vehicles[uid] = vehicle;
    _controller(_vehicleStreams, uid).add(vehicle);
    if (enableDriver) {
      _setProfile(_require(uid).copyWith(driverEnabled: true));
    }
  }

  @override
  Future<DriverCommitment> driverCommitments(String uid) async {
    if (commitment != DriverCommitment.none) return commitment;
    final source = trips;
    if (source == null) return DriverCommitment.none;
    final mine = await source.watchMine(uid).first;
    if (mine.any((trip) => trip.status == TripStatus.ongoing)) {
      return DriverCommitment.tripInProgress;
    }
    if (mine.any(
      (trip) => trip.status == TripStatus.planned && trip.acceptedCount > 0,
    )) {
      return DriverCommitment.upcomingTripWithBookings;
    }
    return DriverCommitment.none;
  }

  @override
  Future<void> setDriverEnabled(String uid, bool enabled) async {
    await Future<void>.delayed(_latency);
    if (enabled && !_vehicles.containsKey(uid)) {
      throw const ProfileFailure('Enregistrez d\'abord votre véhicule.');
    }
    if (!enabled && commitment != DriverCommitment.none) {
      throw ProfileFailure(commitmentMessage(commitment));
    }
    _setProfile(_require(uid).copyWith(driverEnabled: enabled));
  }

  UserProfile _require(String uid) {
    final profile = _profiles[uid];
    if (profile == null) throw const ProfileFailure('Profil introuvable.');
    return profile;
  }

  void _setProfile(UserProfile profile) {
    _profiles[profile.uid] = profile;
    _controller(_profileStreams, profile.uid).add(profile);
    if (!_all.isClosed) _all.add(null);
  }

  final _all = StreamController<void>.broadcast();

  List<UserProfile> get allProfiles {
    final list = _profiles.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  Stream<void> watchAll() => _all.stream;

  Future<void> setSuspended(String uid, bool suspended) async {
    _setProfile(_require(uid).copyWith(suspended: suspended));
  }
}
