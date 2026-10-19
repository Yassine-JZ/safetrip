import 'dart:async';

import 'reservation.dart';
import 'trip.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  final _trips = <String, Trip>{};
  final _reservations = <String, Reservation>{};
  final _feed = StreamController<List<Trip>>.broadcast();
  final _changes = StreamController<void>.broadcast();
  final _mine = <String, StreamController<List<Trip>>>{};
  var _next = 1;

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

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
    _feed.add(_planned());
    for (final entry in _mine.entries) {
      entry.value.add(_owned(entry.key));
    }
  }
}
