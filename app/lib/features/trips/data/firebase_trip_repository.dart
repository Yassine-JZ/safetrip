import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity.dart';
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
        _setNote(
          batch,
          id: 'trip_cancelled_${tripId}_${doc.id}',
          recipientId: doc.id,
          actorId: driverId,
          type: 'trip_cancelled',
          tripId: tripId,
          title: 'Trajet annulé',
          body: 'Le conducteur a annulé le trajet.',
        );
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
  Future<void> start(String tripId, String driverId) => _guard(() async {
    final accepted = await _reservations(tripId)
        .where('status', isEqualTo: 'accepted')
        .get();
    final batch = _db.batch()
      ..update(_trips.doc(tripId), {'status': 'ongoing'});
    for (final doc in accepted.docs) {
      _setNote(
        batch,
        id: 'trip_started_${tripId}_${doc.id}',
        recipientId: doc.id,
        actorId: driverId,
        type: 'trip_started',
        tripId: tripId,
        title: 'Trajet démarré',
        body: 'Le conducteur a démarré le trajet.',
      );
    }
    await batch.commit();
  });

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
  }) => _guard(() async {
    final batch = _db.batch()
      ..set(_reservations(trip.id).doc(passengerId), {
        'tripId': trip.id,
        'passengerId': passengerId,
        'passengerName': passengerName,
        'seats': seats,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    _setNote(
      batch,
      id: 'booking_request_${trip.id}_$passengerId',
      recipientId: trip.driverId,
      actorId: passengerId,
      type: 'booking_request',
      tripId: trip.id,
      title: 'Nouvelle demande',
      body: '$passengerName demande $seats place(s).',
    );
    await batch.commit();
  });

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
      _setNote(
        tx,
        id: 'booking_accepted_${tripId}_$passengerId',
        recipientId: passengerId,
        actorId: trip.data()?['driverId'] as String? ?? '',
        type: 'booking_accepted',
        tripId: tripId,
        title: 'Demande acceptée',
        body: 'Votre place est confirmée.',
      );
    }),
  );

  @override
  Future<void> refuseReservation(String tripId, String passengerId) => _guard(
    () async {
      final trip = await _trips.doc(tripId).get();
      final batch = _db.batch()
        ..update(_reservations(tripId).doc(passengerId), {'status': 'refused'});
      _setNote(
        batch,
        id: 'booking_refused_${tripId}_$passengerId',
        recipientId: passengerId,
        actorId: trip.data()?['driverId'] as String? ?? '',
        type: 'booking_refused',
        tripId: tripId,
        title: 'Demande refusée',
        body: 'Le conducteur a refusé votre demande.',
      );
      await batch.commit();
    },
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
        _setNote(
          tx,
          id: 'booking_cancelled_${tripId}_$passengerId',
          recipientId: trip.data()?['driverId'] as String? ?? '',
          actorId: passengerId,
          type: 'booking_cancelled',
          tripId: tripId,
          title: 'Demande annulée',
          body: 'Un passager a annulé sa demande.',
        );
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
        _setNote(
          tx,
          id: 'booking_cancelled_${tripId}_$passengerId',
          recipientId: trip.data()?['driverId'] as String? ?? '',
          actorId: passengerId,
          type: 'booking_cancelled',
          tripId: tripId,
          title: 'Réservation annulée',
          body: 'Un passager a annulé sa place.',
        );
        return;
      }
      throw const TripFailure('Cette réservation ne peut plus être annulée.');
    }),
  );

  void _setNote(
    Object writer, {
    required String id,
    required String recipientId,
    required String actorId,
    required String type,
    required String tripId,
    required String title,
    required String body,
  }) {
    final ref = _db.collection('notifications').doc(id);
    final data = {
      'recipientId': recipientId,
      'actorId': actorId,
      'type': type,
      'tripId': tripId,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (writer is WriteBatch) {
      writer.set(ref, data);
    } else if (writer is Transaction) {
      writer.set(ref, data);
    }
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String recipientId) {
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) {
            final data = doc.data();
            return AppNotification(
              id: doc.id,
              recipientId: data['recipientId'] as String? ?? '',
              actorId: data['actorId'] as String? ?? '',
              type: data['type'] as String? ?? '',
              tripId: data['tripId'] as String? ?? '',
              title: data['title'] as String? ?? '',
              body: data['body'] as String? ?? '',
              read: data['read'] as bool? ?? false,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Future<void> markNotificationRead(String id, String recipientId) => _guard(
    () => _db.collection('notifications').doc(id).update({'read': true}),
  );

  @override
  Stream<List<Rating>> watchRatings(String targetId) {
    return _db
        .collection('ratings')
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return Rating(
              tripId: data['tripId'] as String? ?? '',
              authorId: data['authorId'] as String? ?? '',
              targetId: data['targetId'] as String? ?? '',
              stars: (data['stars'] as num?)?.toInt() ?? 1,
              comment: data['comment'] as String?,
            );
          }).toList(),
        );
  }

  @override
  Future<void> rate({
    required String tripId,
    required String authorId,
    required String targetId,
    required int stars,
    String? comment,
  }) => _guard(
    () => _db.collection('ratings').doc('${tripId}_${authorId}_$targetId').set({
      'tripId': tripId,
      'authorId': authorId,
      'targetId': targetId,
      'stars': stars,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  CollectionReference<Map<String, dynamic>> _messages(String tripId) =>
      _trips.doc(tripId).collection('messages');

  @override
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return _messages(tripId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return TripMessage(
              id: doc.id,
              tripId: tripId,
              authorId: data['authorId'] as String? ?? '',
              authorName: data['authorName'] as String? ?? '',
              text: data['text'] as String? ?? '',
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<void> sendMessage({
    required String tripId,
    required String authorId,
    required String authorName,
    required String text,
  }) => _guard(() async {
    final cleaned = text.trim();
    if (cleaned.isEmpty || cleaned.length > 500) {
      throw const TripFailure('Le message doit faire entre 1 et 500 caractères.');
    }
    final tripSnap = await _trips.doc(tripId).get();
    final tripData = tripSnap.data();
    if (!tripSnap.exists || tripData == null) {
      throw const TripFailure('Trajet introuvable.');
    }
    if ((tripData['status'] as String?) == 'cancelled') {
      throw const TripFailure('Messagerie indisponible pour ce trajet.');
    }
    final driverId = tripData['driverId'] as String? ?? '';
    final isDriver = driverId == authorId;
    if (!isDriver) {
      final reservation = await _reservations(tripId).doc(authorId).get();
      if ((reservation.data()?['status'] as String?) != 'accepted') {
        throw const TripFailure(
          'Réservation acceptée requise pour écrire ici.',
        );
      }
    }
    final messageRef = _messages(tripId).doc();
    final batch = _db.batch();
    batch.set(messageRef, {
      'authorId': authorId,
      'authorName': authorName,
      'text': cleaned,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final recipients = <String>{};
    if (!isDriver) recipients.add(driverId);
    final accepted = await _reservations(tripId)
        .where('status', isEqualTo: 'accepted')
        .get();
    for (final doc in accepted.docs) {
      if (doc.id != authorId) recipients.add(doc.id);
    }
    final preview =
        cleaned.length > 80 ? '${cleaned.substring(0, 80)}…' : cleaned;
    for (final recipientId in recipients) {
      _setNote(
        batch,
        id: 'trip_message_${messageRef.id}_$recipientId',
        recipientId: recipientId,
        actorId: authorId,
        type: 'trip_message',
        tripId: tripId,
        title: 'Nouveau message',
        body: '$authorName : $preview',
      );
    }
    await batch.commit();
  });

  @override
  Stream<List<Report>> watchMyReports(String reporterId) {
    return _db
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .snapshots()
        .map((snap) {
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
  Future<void> report({
    required String tripId,
    required String reporterId,
    required String reporterName,
    required String targetUserId,
    required String targetName,
    required String reason,
    String? details,
  }) => _guard(() async {
    if (!reportReasons.contains(reason)) {
      throw const TripFailure('Motif de signalement invalide.');
    }
    final cleaned = details?.trim();
    await _db.collection('reports').add({
      'reporterId': reporterId,
      'reporterName': reporterName,
      'tripId': tripId,
      'targetUserId': targetUserId,
      'targetName': targetName,
      'reason': reason,
      'details': cleaned == null || cleaned.isEmpty ? null : cleaned,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

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
