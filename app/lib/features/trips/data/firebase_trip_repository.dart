import 'package:cloud_firestore/cloud_firestore.dart';

import 'reservation.dart';
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
    final open = await _reservations(tripId).get();
    final batch = _db.batch()
      ..update(_trips.doc(tripId), {'status': 'cancelled'});
    for (final doc in open.docs) {
      final status = doc.data()['status'];
      if (status == 'pending' || status == 'accepted') {
        batch.update(doc.reference, {'status': 'cancelled'});
      }
    }
    await batch.commit();
  });

  @override
  Stream<Trip?> watchOne(String tripId) {
    return _trips.doc(tripId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return _trip(doc.id, data);
    });
  }

  @override
  Future<void> start(String tripId, String driverId) =>
      _guard(() => _trips.doc(tripId).update({'status': 'ongoing'}));

  @override
  Future<void> finish(String tripId, String driverId) =>
      _guard(() => _trips.doc(tripId).update({'status': 'completed'}));

  CollectionReference<Map<String, dynamic>> _reservations(String tripId) =>
      _trips.doc(tripId).collection('reservations');

  @override
  Stream<List<Reservation>> watchTripReservations(String tripId) {
    return _reservations(tripId)
        .snapshots()
        .map((snap) => snap.docs.map(_reservation).toList());
  }

  @override
  Stream<List<Reservation>> watchMyReservations(String passengerId) {
    return _db
        .collectionGroup('reservations')
        .where('passengerId', isEqualTo: passengerId)
        .snapshots()
        .map((snap) => snap.docs.map(_reservation).toList());
  }

  @override
  Future<void> requestSeat({
    required Trip trip,
    required String passengerId,
    required String passengerName,
    required int seats,
  }) => _guard(
    () => _reservations(trip.id).doc(passengerId).set({
      'tripId': trip.id,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'seats': seats,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> acceptReservation(String tripId, String passengerId) => _guard(
    () => _db.runTransaction((tx) async {
      final resRef = _reservations(tripId).doc(passengerId);
      final tripRef = _trips.doc(tripId);
      final res = await tx.get(resRef);
      final trip = await tx.get(tripRef);
      final seats = (res.data()?['seats'] as num?)?.toInt() ?? 0;
      final available = (trip.data()?['seatsAvailable'] as num?)?.toInt() ?? 0;
      final accepted = (trip.data()?['acceptedCount'] as num?)?.toInt() ?? 0;
      if (res.data()?['status'] != 'pending' ||
          trip.data()?['status'] != 'planned') {
        throw const TripFailure('Cette demande ne peut plus être acceptée.');
      }
      if (seats > available) {
        throw const TripFailure('Plus assez de places libres.');
      }
      tx.update(tripRef, {
        'seatsAvailable': available - seats,
        'acceptedCount': accepted + 1,
      });
      tx.update(resRef, {'status': 'accepted'});
    }),
  );

  @override
  Future<void> refuseReservation(String tripId, String passengerId) => _guard(
    () => _reservations(tripId).doc(passengerId).update({'status': 'refused'}),
  );

  @override
  Future<void> cancelReservation(String tripId, String passengerId) => _guard(
    () => _db.runTransaction((tx) async {
      final resRef = _reservations(tripId).doc(passengerId);
      final tripRef = _trips.doc(tripId);
      final res = await tx.get(resRef);
      final trip = await tx.get(tripRef);
      final status = res.data()?['status'];
      final seats = (res.data()?['seats'] as num?)?.toInt() ?? 0;
      if (status == 'pending') {
        tx.update(resRef, {'status': 'cancelled'});
        return;
      }
      if (status == 'accepted' && trip.data()?['status'] == 'planned') {
        final available =
            (trip.data()?['seatsAvailable'] as num?)?.toInt() ?? 0;
        final accepted = (trip.data()?['acceptedCount'] as num?)?.toInt() ?? 0;
        tx.update(tripRef, {
          'seatsAvailable': available + seats,
          'acceptedCount': accepted - 1,
        });
        tx.update(resRef, {'status': 'cancelled'});
        return;
      }
      throw const TripFailure('Cette réservation ne peut plus être annulée.');
    }),
  );

  Reservation _reservation(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Reservation(
      tripId: data['tripId'] as String? ?? '',
      passengerId: doc.id,
      passengerName: data['passengerName'] as String? ?? '',
      seats: (data['seats'] as num?)?.toInt() ?? 1,
      status: ReservationStatus.values.byName(
        data['status'] as String? ?? 'pending',
      ),
    );
  }

  Map<String, Object?> _data(Trip trip) => {
    'driverId': trip.driverId,
    'driverName': trip.driverName,
    'vehicleBrand': trip.vehicleBrand,
    'departureId': trip.departureId,
    'destinationId': trip.destinationId,
    'departureAt': Timestamp.fromDate(trip.departureAt),
    'seatsTotal': trip.seatsTotal,
    'seatsAvailable': trip.seatsAvailable,
    'acceptedCount': trip.acceptedCount,
    'pricePerSeat': trip.pricePerSeat,
    'description': trip.description,
    'luggage': trip.luggage,
    'roundTrip': trip.roundTrip,
    'status': trip.status.name,
  };

  Trip _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _trip(doc.id, doc.data());

  Trip _trip(String id, Map<String, dynamic> data) {
    return Trip(
      id: id,
      driverId: data['driverId'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      vehicleBrand: data['vehicleBrand'] as String? ?? '',
      departureId: data['departureId'] as String? ?? '',
      destinationId: data['destinationId'] as String? ?? '',
      departureAt:
          (data['departureAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seatsTotal: (data['seatsTotal'] as num?)?.toInt() ?? 1,
      seatsAvailable: (data['seatsAvailable'] as num?)?.toInt() ?? 1,
      acceptedCount: (data['acceptedCount'] as num?)?.toInt() ?? 0,
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
