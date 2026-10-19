import 'dart:async';

import '../../profile/data/mock_profile_repository.dart';
import '../../profile/data/profile_models.dart';
import '../../sos/data/sos_models.dart';
import '../../trips/data/activity.dart';
import '../../trips/data/mock_trip_repository.dart';
import 'admin_repository.dart';

class MockAdminRepository implements AdminRepository {
  MockAdminRepository({
    required this.profiles,
    required this.trips,
  }) {
    _admins.add('demo-uid');
  }

  final MockProfileRepository profiles;
  final MockTripRepository trips;
  final _admins = <String>{};
  final _sos = <String, SosAlert>{};
  var _sosNext = 1;
  final _changes = StreamController<void>.broadcast();

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<bool> watchIsAdmin(String uid) {
    return Stream<bool>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_admins.contains(uid)));
      multi.onCancel = sub.cancel;
      multi.add(_admins.contains(uid));
    });
  }

  @override
  Stream<List<UserProfile>> watchUsers() {
    return Stream<List<UserProfile>>.multi((multi) {
      void push() => multi.add(profiles.allProfiles);
      final sub = _changes.stream.listen((_) => push());
      final profileSub = profiles.watchAll().listen((_) => push());
      multi.onCancel = () async {
        await sub.cancel();
        await profileSub.cancel();
      };
      push();
    });
  }

  @override
  Stream<List<Report>> watchReports() => trips.watchAllReports();

  @override
  Future<void> setSuspended({
    required String targetUid,
    required bool suspended,
  }) async {
    await profiles.setSuspended(targetUid, suspended);
    _emit();
  }

  @override
  Future<void> setReportStatus({
    required String reportId,
    required String status,
  }) async {
    await trips.setReportStatus(reportId, status);
    _emit();
  }

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
  }) async {
    final id = 'sos-${_sosNext++}';
    final alert = SosAlert(
      id: id,
      userId: userId,
      userName: userName,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: location.accuracyMeters,
      tripId: tripId,
      note: note,
      createdAt: DateTime.now(),
    );
    _sos[id] = alert;
    _emit();
    return alert;
  }

  @override
  Stream<List<SosAlert>> watchSosAlerts() {
    return Stream<List<SosAlert>>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_sosList()));
      multi.onCancel = sub.cancel;
      multi.add(_sosList());
    });
  }

  List<SosAlert> _sosList() {
    final list = _sos.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> setSosStatus({
    required String alertId,
    required String status,
  }) async {
    final current = _sos[alertId];
    if (current == null) {
      throw const AdminFailure('Alerte SOS introuvable.');
    }
    _sos[alertId] = SosAlert(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      latitude: current.latitude,
      longitude: current.longitude,
      accuracyMeters: current.accuracyMeters,
      tripId: current.tripId,
      status: status,
      note: current.note,
      createdAt: current.createdAt,
    );
    _emit();
  }
}
