enum TripStatus { planned, ongoing, completed, cancelled }

/// A published trip. The licence plate is never part of this object.
class Trip {
  const Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicleBrand,
    required this.departureId,
    required this.destinationId,
    required this.departureAt,
    required this.seatsTotal,
    required this.seatsAvailable,
    this.acceptedCount = 0,
    this.pricePerSeat,
    this.description,
    this.luggage = false,
    this.roundTrip = false,
    this.status = TripStatus.planned,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String vehicleBrand;
  final String departureId;
  final String destinationId;
  final DateTime departureAt;
  final int seatsTotal;
  final int seatsAvailable;

  /// Accepted reservations. Pending ones do not count and do not take seats.
  final int acceptedCount;
  final double? pricePerSeat;
  final String? description;
  final bool luggage;
  final bool roundTrip;
  final TripStatus status;

  bool get editable =>
      status == TripStatus.planned && seatsAvailable == seatsTotal;

  Trip copyWith({
    String? departureId,
    String? destinationId,
    DateTime? departureAt,
    int? seatsTotal,
    int? seatsAvailable,
    int? acceptedCount,
    double? Function()? pricePerSeat,
    String? Function()? description,
    bool? luggage,
    bool? roundTrip,
    TripStatus? status,
  }) {
    return Trip(
      id: id,
      driverId: driverId,
      driverName: driverName,
      vehicleBrand: vehicleBrand,
      departureId: departureId ?? this.departureId,
      destinationId: destinationId ?? this.destinationId,
      departureAt: departureAt ?? this.departureAt,
      seatsTotal: seatsTotal ?? this.seatsTotal,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      pricePerSeat: pricePerSeat != null ? pricePerSeat() : this.pricePerSeat,
      description: description != null ? description() : this.description,
      luggage: luggage ?? this.luggage,
      roundTrip: roundTrip ?? this.roundTrip,
      status: status ?? this.status,
    );
  }
}

class TripDraft {
  const TripDraft({
    required this.driverId,
    required this.driverName,
    required this.vehicleBrand,
    required this.departureId,
    required this.destinationId,
    required this.departureAt,
    required this.seatsTotal,
    this.pricePerSeat,
    this.description,
    this.luggage = false,
    this.roundTrip = false,
  });

  final String driverId;
  final String driverName;
  final String vehicleBrand;
  final String departureId;
  final String destinationId;
  final DateTime departureAt;
  final int seatsTotal;
  final double? pricePerSeat;
  final String? description;
  final bool luggage;
  final bool roundTrip;

  Trip toTrip(String id) => Trip(
    id: id,
    driverId: driverId,
    driverName: driverName,
    vehicleBrand: vehicleBrand,
    departureId: departureId,
    destinationId: destinationId,
    departureAt: departureAt,
    seatsTotal: seatsTotal,
    seatsAvailable: seatsTotal,
    pricePerSeat: pricePerSeat,
    description: description,
    luggage: luggage,
    roundTrip: roundTrip,
  );
}

/// What the search form sends to the feed (UC08).
class TripQuery {
  const TripQuery({
    required this.departureId,
    required this.destinationId,
    required this.date,
    required this.seats,
  });

  final String departureId;
  final String destinationId;
  final DateTime date;
  final int seats;

  bool matches(Trip trip) {
    if (trip.status != TripStatus.planned) return false;
    if (trip.seatsAvailable < seats) return false;
    if (trip.departureId != departureId) return false;
    if (trip.destinationId != destinationId) return false;
    final day = DateTime(
      trip.departureAt.year,
      trip.departureAt.month,
      trip.departureAt.day,
    );
    final wanted = DateTime(date.year, date.month, date.day);
    return day == wanted;
  }
}

class TripFailure implements Exception {
  const TripFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

String tripStatusLabel(TripStatus status) => switch (status) {
  TripStatus.planned => 'Prévu',
  TripStatus.ongoing => 'En cours',
  TripStatus.completed => 'Terminé',
  TripStatus.cancelled => 'Annulé',
};
