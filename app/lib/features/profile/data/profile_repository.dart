import 'profile_models.dart';

abstract class ProfileRepository {
  /// Emits `null` while the document does not exist.
  Stream<UserProfile?> watchProfile(String uid);

  /// Creates the public profile of accounts that do not have one yet.
  Future<void> ensureProfile(String uid, {required String displayName});

  Future<PrivateInfo?> privateInfo(String uid);

  Stream<Vehicle?> watchVehicle(String uid);

  Future<void> updateName(
    String uid, {
    required String firstName,
    required String lastName,
  });

  /// [photoUrl] is a `data:image/...;base64,` URL, or `null` to remove it.
  Future<void> updatePhoto(String uid, String? photoUrl);

  /// Saves the vehicle; with [enableDriver] the driver capability is turned
  /// on in the same write.
  Future<void> saveVehicle(
    String uid,
    Vehicle vehicle, {
    bool enableDriver = false,
  });

  Future<DriverCommitment> driverCommitments(String uid);

  /// Throws [ProfileFailure] when turning off is blocked by a commitment.
  Future<void> setDriverEnabled(String uid, bool enabled);
}
