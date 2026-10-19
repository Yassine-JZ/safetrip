import 'dart:async';

import 'activity.dart';
import 'reservation.dart';
import 'trip.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  final _trips = <String, Trip>{};
  final _reservations = <String, Reservation>{};
  final _notifications = <String, AppNotification>{};
  final _ratings = <String, Rating>{};
  final _messages = <String, TripMessage>{};
  final _reports = <String, Report>{};
  final _feed = StreamController<List<Trip>>.broadcast();
  final _changes = StreamController<void>.broadcast();
  final _mine = <String, StreamController<List<Trip>>>{};
  var _next = 1;
  var _messageNext = 1;
  var _reportNext = 1;

  void seed(Trip trip) {
    _trips[trip.id] = trip;
    _emit();
  }

  @override
  Stream<List<Trip>> watchFeed() {
    return Stream<List<Trip>>.multi((multi) {
      final sub = _feed.stream.listen(multi.add);
      multi.onCancel = sub.cancel;
      multi.add(_planned());
    });
  }

  @override
  Stream<List<Trip>> watchMine(String driverId) {
    return Stream<List<Trip>>.multi((multi) {
      final sub = _controller(driverId).stream.listen(multi.add);
      multi.onCancel = sub.cancel;
      multi.add(_owned(driverId));
    });
  }

  @override
  Future<Trip> publish(TripDraft draft) async {
    final trip = draft.toTrip('trip-${_next++}');
    _trips[trip.id] = trip;
    _emit();
    return trip;
  }

  @override
  Future<void> update(Trip trip) async {
    final current = _require(trip.id, trip.driverId);
    if (!current.editable) {
      throw const TripFailure('Ce trajet ne peut plus être modifié.');
    }
    _trips[trip.id] = trip;
    _emit();
  }

  @override
  Future<void> cancel(String tripId, String driverId) async {
    final current = _require(tripId, driverId);
    if (current.status != TripStatus.planned) {
      throw const TripFailure('Seul un trajet prévu peut être annulé.');
    }
    _trips[tripId] = current.copyWith(status: TripStatus.cancelled);
    for (final entry in _reservations.entries.toList()) {
      final reservation = entry.value;
      if (reservation.tripId == tripId &&
          (reservation.status == ReservationStatus.pending ||
              reservation.status == ReservationStatus.accepted)) {
        _reservations[entry.key] = Reservation(
          tripId: reservation.tripId,
          passengerId: reservation.passengerId,
          passengerName: reservation.passengerName,
          seats: reservation.seats,
          status: ReservationStatus.cancelled,
        );
        _note(
          id: 'trip_cancelled_${tripId}_${reservation.passengerId}',
          recipientId: reservation.passengerId,
          actorId: driverId,
          type: 'trip_cancelled',
          tripId: tripId,
          title: 'Trajet annulé',
          body: 'Le conducteur a annulé le trajet.',
        );
      }
    }
    _emit();
  }

  @override
  Stream<Trip?> watchOne(String tripId) {
    return Stream<Trip?>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_trips[tripId]));
      multi.onCancel = sub.cancel;
      multi.add(_trips[tripId]);
    });
  }

  @override
  Future<void> start(String tripId, String driverId) async {
    final trip = _require(tripId, driverId);
    if (trip.status != TripStatus.planned) {
      throw const TripFailure('Seul un trajet prévu peut démarrer.');
    }
    _trips[tripId] = trip.copyWith(status: TripStatus.ongoing);
    for (final reservation in _forTrip(tripId)) {
      if (reservation.status != ReservationStatus.accepted) continue;
      _note(
        id: 'trip_started_${tripId}_${reservation.passengerId}',
        recipientId: reservation.passengerId,
        actorId: driverId,
        type: 'trip_started',
        tripId: tripId,
        title: 'Trajet démarré',
        body: 'Le conducteur a démarré le trajet.',
      );
    }
    _emit();
  }

  @override
  Future<void> finish(String tripId, String driverId) async {
    final trip = _require(tripId, driverId);
    if (trip.status != TripStatus.ongoing) {
      throw const TripFailure('Seul un trajet en cours peut se terminer.');
    }
    _trips[tripId] = trip.copyWith(status: TripStatus.completed);
    _emit();
  }

  String _key(String tripId, String passengerId) => '$tripId/$passengerId';

  @override
  Stream<List<Reservation>> watchTripReservations(String tripId) {
    return Stream<List<Reservation>>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_forTrip(tripId)));
      multi.onCancel = sub.cancel;
      multi.add(_forTrip(tripId));
    });
  }

  @override
  Stream<List<Reservation>> watchMyReservations(String passengerId) {
    return Stream<List<Reservation>>.multi((multi) {
      final sub = _changes.stream.listen(
        (_) => multi.add(_forPassenger(passengerId)),
      );
      multi.onCancel = sub.cancel;
      multi.add(_forPassenger(passengerId));
    });
  }

  @override
  Future<void> requestSeat({
    required Trip trip,
    required String passengerId,
    required String passengerName,
    required int seats,
  }) async {
    final current = _trips[trip.id];
    if (current == null || current.status != TripStatus.planned) {
      throw const TripFailure('Ce trajet n\'accepte plus de réservation.');
    }
    if (current.driverId == passengerId) {
      throw const TripFailure(
        'Vous ne pouvez pas réserver votre propre trajet.',
      );
    }
    if (seats < 1 || seats > current.seatsAvailable) {
      throw const TripFailure('Plus assez de places libres.');
    }
    final key = _key(current.id, passengerId);
    final previous = _reservations[key];
    if (previous != null &&
        (previous.status == ReservationStatus.pending ||
            previous.status == ReservationStatus.accepted)) {
      throw const TripFailure('Vous avez déjà une demande pour ce trajet.');
    }
    _reservations[key] = Reservation(
      tripId: current.id,
      passengerId: passengerId,
      passengerName: passengerName,
      seats: seats,
      status: ReservationStatus.pending,
    );
    _note(
      id: 'booking_request_${current.id}_$passengerId',
      recipientId: current.driverId,
      actorId: passengerId,
      type: 'booking_request',
      tripId: current.id,
      title: 'Nouvelle demande',
      body: '$passengerName demande $seats place(s).',
    );
    _emit();
  }

  @override
  Future<void> acceptReservation(String tripId, String passengerId) async {
    final trip = _trips[tripId];
    final reservation = _reservations[_key(tripId, passengerId)];
    if (trip == null || reservation == null) {
      throw const TripFailure('Demande introuvable.');
    }
    if (trip.status != TripStatus.planned ||
        reservation.status != ReservationStatus.pending) {
      throw const TripFailure('Cette demande ne peut plus être acceptée.');
    }
    if (reservation.seats > trip.seatsAvailable) {
      throw const TripFailure('Plus assez de places libres.');
    }
    _trips[tripId] = trip.copyWith(
      seatsAvailable: trip.seatsAvailable - reservation.seats,
      acceptedCount: trip.acceptedCount + 1,
    );
    _reservations[_key(tripId, passengerId)] = Reservation(
      tripId: tripId,
      passengerId: passengerId,
      passengerName: reservation.passengerName,
      seats: reservation.seats,
      status: ReservationStatus.accepted,
    );
    _note(
      id: 'booking_accepted_${tripId}_$passengerId',
      recipientId: passengerId,
      actorId: trip.driverId,
      type: 'booking_accepted',
      tripId: tripId,
      title: 'Demande acceptée',
      body: 'Votre place est confirmée.',
    );
    _emit();
  }

  @override
  Future<void> refuseReservation(String tripId, String passengerId) async {
    final reservation = _reservations[_key(tripId, passengerId)];
    if (reservation == null ||
        reservation.status != ReservationStatus.pending) {
      throw const TripFailure('Cette demande ne peut plus être refusée.');
    }
    _reservations[_key(tripId, passengerId)] = Reservation(
      tripId: tripId,
      passengerId: passengerId,
      passengerName: reservation.passengerName,
      seats: reservation.seats,
      status: ReservationStatus.refused,
    );
    final driverId = _trips[tripId]?.driverId ?? '';
    _note(
      id: 'booking_refused_${tripId}_$passengerId',
      recipientId: passengerId,
      actorId: driverId,
      type: 'booking_refused',
      tripId: tripId,
      title: 'Demande refusée',
      body: 'Le conducteur a refusé votre demande.',
    );
    _emit();
  }

  @override
  Future<void> cancelReservation(String tripId, String passengerId) async {
    final trip = _trips[tripId];
    final reservation = _reservations[_key(tripId, passengerId)];
    if (trip == null || reservation == null) {
      throw const TripFailure('Demande introuvable.');
    }
    if (reservation.status == ReservationStatus.pending) {
      _reservations[_key(tripId, passengerId)] = Reservation(
        tripId: tripId,
        passengerId: passengerId,
        passengerName: reservation.passengerName,
        seats: reservation.seats,
        status: ReservationStatus.cancelled,
      );
      _note(
        id: 'booking_cancelled_${tripId}_$passengerId',
        recipientId: trip.driverId,
        actorId: passengerId,
        type: 'booking_cancelled',
        tripId: tripId,
        title: 'Demande annulée',
        body: '${reservation.passengerName} a annulé sa demande.',
      );
      _emit();
      return;
    }
    if (reservation.status == ReservationStatus.accepted &&
        trip.status == TripStatus.planned) {
      _trips[tripId] = trip.copyWith(
        seatsAvailable: trip.seatsAvailable + reservation.seats,
        acceptedCount: trip.acceptedCount - 1,
      );
      _reservations[_key(tripId, passengerId)] = Reservation(
        tripId: tripId,
        passengerId: passengerId,
        passengerName: reservation.passengerName,
        seats: reservation.seats,
        status: ReservationStatus.cancelled,
      );
      _note(
        id: 'booking_cancelled_${tripId}_$passengerId',
        recipientId: trip.driverId,
        actorId: passengerId,
        type: 'booking_cancelled',
        tripId: tripId,
        title: 'Réservation annulée',
        body: '${reservation.passengerName} a annulé sa place.',
      );
      _emit();
      return;
    }
    throw const TripFailure('Cette réservation ne peut plus être annulée.');
  }

  List<Reservation> _forTrip(String tripId) => _reservations.values
      .where((reservation) => reservation.tripId == tripId)
      .toList();

  List<Reservation> _forPassenger(String passengerId) => _reservations.values
      .where((reservation) => reservation.passengerId == passengerId)
      .toList();

  Trip _require(String id, String driverId) {
    final trip = _trips[id];
    if (trip == null || trip.driverId != driverId) {
      throw const TripFailure('Trajet introuvable.');
    }
    return trip;
  }

  List<Trip> _planned() {
    final list = _trips.values
        .where((trip) => trip.status == TripStatus.planned)
        .toList();
    list.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return list;
  }

  List<Trip> _owned(String driverId) {
    final list = _trips.values
        .where((trip) => trip.driverId == driverId)
        .toList();
    list.sort((a, b) => b.departureAt.compareTo(a.departureAt));
    return list;
  }

  StreamController<List<Trip>> _controller(String driverId) =>
      _mine.putIfAbsent(driverId, StreamController<List<Trip>>.broadcast);

  void _note({
    required String id,
    required String recipientId,
    required String actorId,
    required String type,
    required String tripId,
    required String title,
    required String body,
  }) {
    _notifications.putIfAbsent(
      id,
      () => AppNotification(
        id: id,
        recipientId: recipientId,
        actorId: actorId,
        type: type,
        tripId: tripId,
        title: title,
        body: body,
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String recipientId) {
    return Stream<List<AppNotification>>.multi((multi) {
      final sub = _changes.stream.listen(
        (_) => multi.add(_notesFor(recipientId)),
      );
      multi.onCancel = sub.cancel;
      multi.add(_notesFor(recipientId));
    });
  }

  List<AppNotification> _notesFor(String recipientId) {
    final list = _notifications.values
        .where((note) => note.recipientId == recipientId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> markNotificationRead(String id, String recipientId) async {
    final note = _notifications[id];
    if (note == null || note.recipientId != recipientId) return;
    _notifications[id] = AppNotification(
      id: note.id,
      recipientId: note.recipientId,
      actorId: note.actorId,
      type: note.type,
      tripId: note.tripId,
      title: note.title,
      body: note.body,
      read: true,
      createdAt: note.createdAt,
    );
    _emit();
  }

  @override
  Stream<List<Rating>> watchRatings(String targetId) {
    return Stream<List<Rating>>.multi((multi) {
      final sub = _changes.stream.listen(
        (_) => multi.add(_ratingsFor(targetId)),
      );
      multi.onCancel = sub.cancel;
      multi.add(_ratingsFor(targetId));
    });
  }

  List<Rating> _ratingsFor(String targetId) =>
      _ratings.values.where((rating) => rating.targetId == targetId).toList();

  @override
  Future<void> rate({
    required String tripId,
    required String authorId,
    required String targetId,
    required int stars,
    String? comment,
  }) async {
    final trip = _trips[tripId];
    if (trip == null || trip.status != TripStatus.completed) {
      throw const TripFailure('Vous pourrez noter après la fin du trajet.');
    }
    if (authorId == targetId) {
      throw const TripFailure('Vous ne pouvez pas vous noter vous-même.');
    }
    if (stars < 1 || stars > 5) {
      throw const TripFailure('La note va de 1 à 5.');
    }
    if (!_participant(trip, authorId) || !_participant(trip, targetId)) {
      throw const TripFailure(
        'Seuls les participants du trajet peuvent noter.',
      );
    }
    final id = '${tripId}_${authorId}_$targetId';
    if (_ratings.containsKey(id)) {
      throw const TripFailure('Vous avez déjà noté cette personne.');
    }
    _ratings[id] = Rating(
      tripId: tripId,
      authorId: authorId,
      targetId: targetId,
      stars: stars,
      comment: comment,
    );
    _emit();
  }

  bool _participant(Trip trip, String uid) {
    if (trip.driverId == uid) return true;
    final reservation = _reservations[_key(trip.id, uid)];
    return reservation?.status == ReservationStatus.accepted;
  }

  @override
  Stream<List<Trip>> watchConversations(String uid) {
    return Stream<List<Trip>>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_conversations(uid)));
      multi.onCancel = sub.cancel;
      multi.add(_conversations(uid));
    });
  }

  List<Trip> _conversations(String uid) {
    final map = <String, Trip>{};
    for (final trip in _trips.values) {
      if (trip.status == TripStatus.cancelled) continue;
      if (trip.driverId == uid) {
        map[trip.id] = trip;
        continue;
      }
      final reservation = _reservations[_key(trip.id, uid)];
      if (reservation?.status == ReservationStatus.accepted) {
        map[trip.id] = trip;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.departureAt.compareTo(a.departureAt));
    return list;
  }

  @override
  Stream<List<TripMessage>> watchMessages(String tripId) {
    return Stream<List<TripMessage>>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_messagesFor(tripId)));
      multi.onCancel = sub.cancel;
      multi.add(_messagesFor(tripId));
    });
  }

  List<TripMessage> _messagesFor(String tripId) {
    final list =
        _messages.values.where((item) => item.tripId == tripId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> sendMessage({
    required String tripId,
    required String authorId,
    required String authorName,
    required String text,
  }) async {
    final trip = _trips[tripId];
    final cleaned = text.trim();
    if (trip == null || trip.status == TripStatus.cancelled) {
      throw const TripFailure('Messagerie indisponible pour ce trajet.');
    }
    if (!_participant(trip, authorId)) {
      throw const TripFailure(
        'Réservation acceptée requise pour écrire ici.',
      );
    }
    if (cleaned.isEmpty || cleaned.length > 500) {
      throw const TripFailure('Le message doit faire entre 1 et 500 caractères.');
    }
    final id = 'msg-${_messageNext++}';
    _messages[id] = TripMessage(
      id: id,
      tripId: tripId,
      authorId: authorId,
      authorName: authorName,
      text: cleaned,
      createdAt: DateTime.now(),
    );
    final recipients = <String>{};
    if (trip.driverId != authorId) recipients.add(trip.driverId);
    for (final reservation in _reservations.values) {
      if (reservation.tripId == tripId &&
          reservation.status == ReservationStatus.accepted &&
          reservation.passengerId != authorId) {
        recipients.add(reservation.passengerId);
      }
    }
    for (final recipientId in recipients) {
      _note(
        id: 'trip_message_${id}_$recipientId',
        recipientId: recipientId,
        actorId: authorId,
        type: 'trip_message',
        tripId: tripId,
        title: 'Nouveau message',
        body: '$authorName : ${cleaned.length > 80 ? '${cleaned.substring(0, 80)}…' : cleaned}',
      );
    }
    _emit();
  }

  @override
  Stream<List<Report>> watchMyReports(String reporterId) {
    return Stream<List<Report>>.multi((multi) {
      final sub = _changes.stream.listen((_) => multi.add(_reportsFor(reporterId)));
      multi.onCancel = sub.cancel;
      multi.add(_reportsFor(reporterId));
    });
  }

  List<Report> _reportsFor(String reporterId) {
    final list = _reports.values
        .where((item) => item.reporterId == reporterId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
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
  }) async {
    final trip = _trips[tripId];
    if (trip == null) {
      throw const TripFailure('Trajet introuvable.');
    }
    if (!_participant(trip, reporterId) || !_participant(trip, targetUserId)) {
      throw const TripFailure(
        'Vous ne pouvez signaler qu\'un participant du trajet.',
      );
    }
    if (reporterId == targetUserId) {
      throw const TripFailure('Vous ne pouvez pas vous signaler vous-même.');
    }
    if (!reportReasons.contains(reason)) {
      throw const TripFailure('Motif de signalement invalide.');
    }
    final cleaned = details?.trim();
    if (cleaned != null && cleaned.length > 500) {
      throw const TripFailure('Détails trop longs (500 caractères max).');
    }
    final id = 'report-${_reportNext++}';
    _reports[id] = Report(
      id: id,
      reporterId: reporterId,
      reporterName: reporterName,
      tripId: tripId,
      targetUserId: targetUserId,
      targetName: targetName,
      reason: reason,
      details: cleaned == null || cleaned.isEmpty ? null : cleaned,
      createdAt: DateTime.now(),
    );
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
    _feed.add(_planned());
    for (final entry in _mine.entries) {
      entry.value.add(_owned(entry.key));
    }
  }
}
