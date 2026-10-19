import 'trip.dart';

abstract class TripRepository {
  /// Planned trips, soonest first. Cancelled trips stay out of the feed.
  Stream<List<Trip>> watchFeed();

  Stream<List<Trip>> watchMine(String driverId);

  Future<Trip> publish(TripDraft draft);

  /// Only while the trip is still [Trip.editable].
  Future<void> update(Trip trip);

  /// Planned trips become cancelled. They are never deleted.
  Future<void> cancel(String tripId, String driverId);
}
