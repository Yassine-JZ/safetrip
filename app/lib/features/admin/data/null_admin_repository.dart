import '../../profile/data/profile_models.dart';
import '../../sos/data/sos_models.dart';
import '../../trips/data/activity.dart';
import 'admin_repository.dart';

/// Used by widget tests that do not exercise the admin space.
class NullAdminRepository implements AdminRepository {
  const NullAdminRepository();

  @override
  Stream<bool> watchIsAdmin(String uid) => Stream<bool>.value(false);

  @override
  Stream<List<UserProfile>> watchUsers() =>
      Stream<List<UserProfile>>.value(const []);

  @override
  Stream<List<Report>> watchReports() => Stream<List<Report>>.value(const []);

  @override
  Future<void> setSuspended({
    required String targetUid,
    required bool suspended,
  }) async {}

  @override
  Future<void> setReportStatus({
    required String reportId,
    required String status,
  }) async {}

  @override
  Future<void> saveFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {}

  @override
  Future<SosAlert> sendSos({
    required String userId,
    required String userName,
    required GeoSnapshot location,
    String? tripId,
    String? note,
  }) => throw const AdminFailure('SOS indisponible.');

  @override
  Stream<List<SosAlert>> watchSosAlerts() =>
      Stream<List<SosAlert>>.value(const []);

  @override
  Future<void> setSosStatus({
    required String alertId,
    required String status,
  }) async {}
}