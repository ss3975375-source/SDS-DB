class ContactUser {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const ContactUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });
}

enum ContactRequestStatus { pending, accepted, declined, cancelled }

class ContactRequest {
  final String id;
  final String userId;
  final ContactRequestStatus status;

  const ContactRequest({
    required this.id,
    required this.userId,
    required this.status,
  });
}
