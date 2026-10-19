enum ReservationStatus { pending, accepted, refused, cancelled }

/// One passenger's request for one trip. The document id is the passenger id,
/// so the same person cannot request the same trip twice.
class Reservation {
  const Reservation({
    required this.tripId,
    required this.passengerId,
    required this.passengerName,
    required this.seats,
    required this.status,
  });

  final String tripId;
  final String passengerId;
  final String passengerName;
  final int seats;
  final ReservationStatus status;
}

String reservationStatusLabel(ReservationStatus status) => switch (status) {
  ReservationStatus.pending => 'En attente',
  ReservationStatus.accepted => 'Acceptée',
  ReservationStatus.refused => 'Refusée',
  ReservationStatus.cancelled => 'Annulée',
};
