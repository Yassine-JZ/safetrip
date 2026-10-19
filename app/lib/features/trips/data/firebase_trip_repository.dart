import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip.dart';
import 'trip_repository.dart';

class FirebaseTripRepository implements TripRepository {
  FirebaseTripRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _trips =>
      _db.collection('trips');

  @override
  Stream<List<Trip>> watchFeed() {
    return _trips.where('status', isEqualTo: 'planned').snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.departureAt.compareTo(b.departureAt));
      return list;
    });
  }

  @override
  Stream<List<Trip>> watchMine(String driverId) {
    return _trips.where('driverId', isEqualTo: driverId).snapshots().map((
      snap,
    ) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.departureAt.compareTo(a.departureAt));
      return list;
    });
  }

  @override
  Future<Trip> publish(TripDraft draft) => _guard(() async {
    final ref = _trips.doc();
    await ref.set({
      ..._data(draft.toTrip(ref.id)),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return draft.toTrip(ref.id);
  });

  @override
  Future<void> update(Trip trip) => _guard(() async {
    await _trips.doc(trip.id).update({
      'departureId': trip.departureId,
      'destinationId': trip.destinationId,
      'departureAt': Timestamp.fromDate(trip.departureAt),
      'seatsTotal': trip.seatsTotal,
      'seatsAvailable': trip.seatsTotal,
      'pricePerSeat': trip.pricePerSeat,
      'description': trip.description,
      'luggage': trip.luggage,
      'roundTrip': trip.roundTrip,
    });
  });

  @override
  Future<void> cancel(String tripId, String driverId) => _guard(() async {
    await _trips.doc(tripId).update({'status': 'cancelled'});
  });

  Map<String, Object?> _data(Trip trip) => {
    'driverId': trip.driverId,
    'driverName': trip.driverName,
    'vehicleBrand': trip.vehicleBrand,
    'departureId': trip.departureId,
    'destinationId': trip.destinationId,
    'departureAt': Timestamp.fromDate(trip.departureAt),
    'seatsTotal': trip.seatsTotal,
    'seatsAvailable': trip.seatsAvailable,
    'pricePerSeat': trip.pricePerSeat,
    'description': trip.description,
    'luggage': trip.luggage,
    'roundTrip': trip.roundTrip,
    'status': trip.status.name,
  };

  Trip _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Trip(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      vehicleBrand: data['vehicleBrand'] as String? ?? '',
      departureId: data['departureId'] as String? ?? '',
      destinationId: data['destinationId'] as String? ?? '',
      departureAt:
          (data['departureAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seatsTotal: (data['seatsTotal'] as num?)?.toInt() ?? 1,
      seatsAvailable: (data['seatsAvailable'] as num?)?.toInt() ?? 1,
      pricePerSeat: (data['pricePerSeat'] as num?)?.toDouble(),
      description: data['description'] as String?,
      luggage: data['luggage'] as bool? ?? false,
      roundTrip: data['roundTrip'] as bool? ?? false,
      status: TripStatus.values.byName(data['status'] as String? ?? 'planned'),
    );
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw TripFailure(switch (e.code) {
        'permission-denied' =>
          'Action refusée. Le mode conducteur doit être actif.',
        'unavailable' => 'Pas de connexion réseau. Réessayez.',
        _ => 'Une erreur est survenue. Réessayez.',
      });
    }
  }
}
