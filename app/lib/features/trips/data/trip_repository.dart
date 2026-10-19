import 'reservation.dart';
import 'trip.dart';

abstract class TripRepository {
  /// Planned trips, soonest first. Cancelled trips stay out of the feed.
  Stream<List<Trip>> watchFeed();

  Stream<List<Trip>> watchMine(String driverId);

  Future<Trip> publish(TripDraft draft);

  /// Only while the trip is still [Trip.editable].
  Future<void> update(Trip trip);

  /// Planned trips become cancelled. They are never deleted.
  /// Open reservations are cancelled with the trip.
  Future<void> cancel(String tripId, String driverId);

  Stream<Trip?> watchOne(String tripId);

  /// Prévu → En cours. Only the owner, with driver mode still on.
  Future<void> start(String tripId, String driverId);

  /// En cours → Terminé.
  Future<void> finish(String tripId, String driverId);

  Stream<List<Reservation>> watchTripReservations(String tripId);

  Stream<List<Reservation>> watchMyReservations(String passengerId);

  /// Pending request. Does not take the seats yet.
  Future<void> requestSeat({
    required Trip trip,
    required String passengerId,
    required String passengerName,
    required int seats,
  });

  /// Takes the seats in the same write as the status change.
  Future<void> acceptReservation(String tripId, String passengerId);

  Future<void> refuseReservation(String tripId, String passengerId);

  /// Passenger withdraws a pending request, or an accepted one before departure.
  Future<void> cancelReservation(String tripId, String passengerId);
}
