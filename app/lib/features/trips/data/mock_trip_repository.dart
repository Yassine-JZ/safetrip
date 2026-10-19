import 'dart:async';

import 'trip.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  final _trips = <String, Trip>{};
  final _feed = StreamController<List<Trip>>.broadcast();
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
    _emit();
  }

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
    _feed.add(_planned());
    for (final entry in _mine.entries) {
      entry.value.add(_owned(entry.key));
    }
  }
}
