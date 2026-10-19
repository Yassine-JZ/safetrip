import '../../profile/data/profile_models.dart';
import '../../sos/data/sos_models.dart';
import '../../trips/data/activity.dart';

class AdminFailure implements Exception {
  const AdminFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AdminRepository {
  /// True when [uid] is listed under `admins/{uid}` (or demo seed).
  Stream<bool> watchIsAdmin(String uid);

  Stream<List<UserProfile>> watchUsers();

  Stream<List<Report>> watchReports();

  Future<void> setSuspended({
    required String targetUid,
    required bool suspended,
  });

  Future<void> setReportStatus({
    required String reportId,
    required String status,
  });

  Future<void> saveFcmToken({
    required String uid,
    required String token,
    required String platform,
  });

  /// GPS snapshot SOS. Notifies every admin via in-app alertes.
  Future<SosAlert> sendSos({
    required String userId,
    required String userName,
    required GeoSnapshot location,
    String? tripId,
    String? note,
  });

  Stream<List<SosAlert>> watchSosAlerts();

  Future<void> setSosStatus({
    required String alertId,
    required String status,
  });
}
