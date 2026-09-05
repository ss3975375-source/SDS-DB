# Messaging reliability security notes

- Offline message bodies are encrypted locally with AES-256-GCM before entering SQLite.
- The local encryption key is kept in Android/iOS secure storage.
- Client message IDs are random UUIDs and are not authentication credentials.
- The backend validates authenticated conversation membership on every send and sync request.
- Retry idempotency is scoped to `(sender_id, client_message_id)` and cannot be used to impersonate another sender.
- A client ID cannot be rebound to a different conversation or message body.
- Sync cursors are opaque base64url values containing only a timestamp and UUID; they do not contain message content or credentials.
- Push notification payloads remain generic; synchronization should retrieve actual content through the authenticated API.
- No E2EE claim is made.
