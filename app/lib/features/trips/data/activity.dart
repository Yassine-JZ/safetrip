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
