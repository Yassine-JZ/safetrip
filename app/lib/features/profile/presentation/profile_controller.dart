import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// Profile and vehicle of the signed-in user (UC02, UC12).
class ProfileController extends ChangeNotifier {
  ProfileController(
    this._repository, {
    required this.uid,
    required String displayName,
  }) {
    _profileSub = _repository.watchProfile(uid).listen((profile) {
      _profile = profile;
      _profileLoaded = true;
      if (profile == null && !_creating) {
        _creating = true;
        _repository
            .ensureProfile(uid, displayName: displayName)
            .catchError((Object _) {});
      }
      notifyListeners();
    });
    _vehicleSub = _repository.watchVehicle(uid).listen((vehicle) {
      _vehicle = vehicle;
      notifyListeners();
    });
    _loadPrivateInfo();
  }

  final ProfileRepository _repository;
  final String uid;
  late final StreamSubscription<UserProfile?> _profileSub;
  late final StreamSubscription<Vehicle?> _vehicleSub;

  UserProfile? _profile;
  Vehicle? _vehicle;
  PrivateInfo? _privateInfo;
  bool _profileLoaded = false;
  bool _creating = false;
  bool _busy = false;

  UserProfile? get profile => _profile;
  Vehicle? get vehicle => _vehicle;
  PrivateInfo? get privateInfo => _privateInfo;
  bool get loading => !_profileLoaded || _profile == null;
  bool get busy => _busy;
  bool get driverEnabled => _profile?.driverEnabled ?? false;

  Future<void> _loadPrivateInfo() async {
    try {
      _privateInfo = await _repository.privateInfo(uid);
      notifyListeners();
    } on ProfileFailure {
      // The private card shows a placeholder.
    }
  }

  Future<void> updateName(String firstName, String lastName) => _run(
    () => _repository.updateName(
      uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    ),
  );

  Future<void> updatePhoto(String? photoUrl) =>
      _run(() => _repository.updatePhoto(uid, photoUrl));

  Future<void> saveVehicle(Vehicle vehicle, {bool enableDriver = false}) =>
      _run(
        () => _repository.saveVehicle(uid, vehicle, enableDriver: enableDriver),
      );

  Future<void> setDriverEnabled(bool enabled) =>
      _run(() => _repository.setDriverEnabled(uid, enabled));

  /// Throws [ProfileFailure] so the page can show the message.
  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw const ProfileFailure('Une erreur est survenue. Réessayez.');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _profileSub.cancel();
    _vehicleSub.cancel();
    super.dispose();
  }
}
