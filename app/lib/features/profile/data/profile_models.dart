/// Public profile (`users/{uid}`), readable by other verified users.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.driverEnabled = false,
    this.suspended = false,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String uid;
  final String firstName;
  final String lastName;

  /// Small JPEG/PNG stored inline as a `data:` URL (no Cloud Storage on the
  /// free plan), or `null`.
  final String? photoUrl;
  final bool driverEnabled;

  /// Set by an admin. The app blocks access while true.
  final bool suspended;
  final double? ratingAverage;
  final int ratingCount;
  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    String first(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${first(firstName)}${first(lastName)}';
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? Function()? photoUrl,
    bool? driverEnabled,
    bool? suspended,
  }) => UserProfile(
    uid: uid,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    photoUrl: photoUrl != null ? photoUrl() : this.photoUrl,
    driverEnabled: driverEnabled ?? this.driverEnabled,
    suspended: suspended ?? this.suspended,
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
  );
}

/// Private contact data (`users_private/{uid}`): owner and admins only.
class PrivateInfo {
  const PrivateInfo({required this.email, required this.phone});

  final String email;
  final String phone;
}

/// `vehicles/{uid}`: owner and admins only. The plate is never public.
class Vehicle {
  const Vehicle({
    required this.brand,
    required this.plate,
    required this.seats,
  });

  final String brand;
  final String plate;

  /// Passenger seats, not counting the driver.
  final int seats;
}

/// Why driver mode cannot be turned off right now (cahier des charges §3.2).
enum DriverCommitment { none, upcomingTripWithBookings, tripInProgress }

String commitmentMessage(DriverCommitment commitment) => switch (commitment) {
  DriverCommitment.upcomingTripWithBookings =>
    'Un trajet à venir a des réservations acceptées. Annulez-le d\'abord : '
        'les passagers seront prévenus.',
  DriverCommitment.tripInProgress =>
    'Impossible pendant un trajet en cours. Terminez-le d\'abord.',
  DriverCommitment.none => '',
};

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
