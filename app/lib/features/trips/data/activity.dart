/// In-app notification. Push messages are not sent: the center below is the
/// reference, and it never contains a phone number, a plate or a position.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.tripId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String type;
  final String tripId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
}

/// One rating of a participant by another participant of the same finished trip.
class Rating {
  const Rating({
    required this.tripId,
    required this.authorId,
    required this.targetId,
    required this.stars,
    this.comment,
  });

  final String tripId;
  final String authorId;
  final String targetId;
  final int stars;
  final String? comment;
}

/// Short chat message between the driver and accepted passengers of one trip.
class TripMessage {
  const TripMessage({
    required this.id,
    required this.tripId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
}

/// Reasons a verified user can flag another participant or a trip.
const reportReasons = <String>[
  'Comportement inapproprié',
  'Retard ou non-présentation',
  'Annulation abusive',
  'Harcèlement',
  'Autre',
];

/// One signalement stored for later admin review (no phone / plate / GPS).
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.tripId,
    required this.targetUserId,
    required this.targetName,
    required this.reason,
    required this.createdAt,
    this.details,
    this.status = 'open',
  });

  final String id;
  final String reporterId;
  final String reporterName;
  final String tripId;
  final String targetUserId;
  final String targetName;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
}
