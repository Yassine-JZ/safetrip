import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_models.dart';
import 'profile_repository.dart';

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _vehicle(String uid) =>
      _db.collection('vehicles').doc(uid);

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _user(uid).snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return null;
        return UserProfile(
          uid: uid,
          firstName: data['firstName'] as String? ?? '',
          lastName: data['lastName'] as String? ?? '',
          photoUrl: data['photoUrl'] as String?,
          driverEnabled: data['driverEnabled'] as bool? ?? false,
          ratingAverage: (data['ratingAverage'] as num?)?.toDouble(),
          ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<void> ensureProfile(String uid, {required String displayName}) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return _guard(
      () => _user(uid).set({
        'firstName': parts.first,
        'lastName': parts.skip(1).join(' '),
        'photoUrl': null,
        'driverEnabled': false,
        'ratingAverage': null,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<PrivateInfo?> privateInfo(String uid) => _guard(() async {
    final data = (await _db.collection('users_private').doc(uid).get()).data();
    if (data == null) return null;
    return PrivateInfo(
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
    );
  });

  @override
  Stream<Vehicle?> watchVehicle(String uid) =>
      _vehicle(uid).snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return null;
        return Vehicle(
          brand: data['brand'] as String? ?? '',
          plate: data['plate'] as String? ?? '',
          seats: (data['seats'] as num?)?.toInt() ?? 1,
        );
      });

  @override
  Future<void> updateName(
    String uid, {
    required String firstName,
    required String lastName,
  }) => _guard(() async {
    await _user(uid).update({'firstName': firstName, 'lastName': lastName});
    await _auth.currentUser?.updateDisplayName('$firstName $lastName');
  });

  @override
  Future<void> updatePhoto(String uid, String? photoUrl) =>
      _guard(() => _user(uid).update({'photoUrl': photoUrl}));

  @override
  Future<void> saveVehicle(
    String uid,
    Vehicle vehicle, {
    bool enableDriver = false,
  }) => _guard(() {
    // One batch so the rules see the vehicle when driver mode is enabled.
    final batch = _db.batch()
      ..set(_vehicle(uid), {
        'brand': vehicle.brand,
        'plate': vehicle.plate,
        'seats': vehicle.seats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (enableDriver) batch.update(_user(uid), {'driverEnabled': true});
    return batch.commit();
  });

  // Trips are introduced with UC13; until then nobody can have one.
  @override
  Future<DriverCommitment> driverCommitments(String uid) async =>
      DriverCommitment.none;

  @override
  Future<void> setDriverEnabled(String uid, bool enabled) async {
    if (!enabled) {
      final commitment = await driverCommitments(uid);
      if (commitment != DriverCommitment.none) {
        throw ProfileFailure(commitmentMessage(commitment));
      }
    }
    await _guard(() => _user(uid).update({'driverEnabled': enabled}));
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw ProfileFailure(switch (e.code) {
        'permission-denied' =>
          'Action refusée. Vérifiez que votre e-mail est confirmé.',
        'unavailable' => 'Pas de connexion réseau. Réessayez.',
        _ => 'Une erreur est survenue. Réessayez.',
      });
    }
  }
}
