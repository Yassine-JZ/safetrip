import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/data/profile_models.dart';
import '../../sos/data/sos_models.dart';
import '../../trips/data/activity.dart';
import 'admin_repository.dart';

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<bool> watchIsAdmin(String uid) {
    return _db.collection('admins').doc(uid).snapshots().map((snap) {
      return snap.exists;
    });
  }

  @override
  Stream<List<UserProfile>> watchUsers() {
    return _db.collection('users').snapshots().map((snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        return UserProfile(
          uid: doc.id,
          firstName: data['firstName'] as String? ?? '',
          lastName: data['lastName'] as String? ?? '',
          photoUrl: data['photoUrl'] as String?,
          driverEnabled: data['driverEnabled'] as bool? ?? false,
          suspended: data['suspended'] as bool? ?? false,
          ratingAverage: (data['ratingAverage'] as num?)?.toDouble(),
          ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  @override
  Stream<List<Report>> watchReports() {
    return _db.collection('reports').snapshots().map((snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        return Report(
          id: doc.id,
          reporterId: data['reporterId'] as String? ?? '',
          reporterName: data['reporterName'] as String? ?? '',
          tripId: data['tripId'] as String? ?? '',
          targetUserId: data['targetUserId'] as String? ?? '',
          targetName: data['targetName'] as String? ?? '',
          reason: data['reason'] as String? ?? '',
          details: data['details'] as String?,
          status: data['status'] as String? ?? 'open',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> setSuspended({
    required String targetUid,
    required bool suspended,
  }) => _guard(
    () => _db.collection('users').doc(targetUid).update({
      'suspended': suspended,
    }),
  );

  @override
  Future<void> setReportStatus({
    required String reportId,
    required String status,
  }) => _guard(
    () => _db.collection('reports').doc(reportId).update({'status': status}),
  );

  @override
  Future<void> saveFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) => _guard(
    () => _db.collection('fcm_tokens').doc(uid).set({
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<SosAlert> sendSos({
    required String userId,
    required String userName,
    required GeoSnapshot location,
    String? tripId,
    String? note,
  }) => _guard(() async {
    final cleaned = note?.trim();
    final ref = _db.collection('sos_alerts').doc();
    final data = {
      'userId': userId,
      'userName': userName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracyMeters': location.accuracyMeters,
      'tripId': tripId,
      'note': cleaned == null || cleaned.isEmpty ? null : cleaned,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.set(ref, data);
    final admins = await _db.collection('admins').get();
    for (final admin in admins.docs) {
      if (admin.id == userId) continue;
      final noteRef = _db.collection('notifications').doc(
        'sos_${ref.id}_${admin.id}',
      );
      batch.set(noteRef, {
        'recipientId': admin.id,
        'actorId': userId,
        'type': 'sos_alert',
        'tripId': ref.id, // points to sos_alerts/{id} for rule checks
        'title': 'SOS',
        'body': '$userName a déclenché un SOS.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return SosAlert(
      id: ref.id,
      userId: userId,
      userName: userName,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: location.accuracyMeters,
      tripId: tripId,
      note: cleaned == null || cleaned.isEmpty ? null : cleaned,
      createdAt: DateTime.now(),
    );
  });

  @override
  Stream<List<SosAlert>> watchSosAlerts() {
    return _db.collection('sos_alerts').snapshots().map((snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        return SosAlert(
          id: doc.id,
          userId: data['userId'] as String? ?? '',
          userName: data['userName'] as String? ?? '',
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
          accuracyMeters: (data['accuracyMeters'] as num?)?.toDouble(),
          tripId: data['tripId'] as String?,
          status: data['status'] as String? ?? 'open',
          note: data['note'] as String?,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> setSosStatus({
    required String alertId,
    required String status,
  }) => _guard(
    () => _db.collection('sos_alerts').doc(alertId).update({'status': status}),
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(error.message ?? 'Action administrateur refusée.');
    } catch (_) {
      throw const AdminFailure('Une erreur est survenue. Réessayez.');
    }
  }
}
