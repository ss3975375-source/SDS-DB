# Milestone 17 — Production Push Notifications

Implemented:
- Firebase Admin FCM provider on the backend.
- Backend-only Firebase credentials; never placed in Flutter.
- AES-256-GCM encryption for FCM tokens at rest plus SHA-256 lookup hash.
- Authenticated device registration tied to the current SDS-DB session/device.
- Device disable/revocation endpoint.
- Database-backed notification preferences.
- Notification outbox and worker script for delivery processing.
- Delivery logging and automatic invalid-token revocation.
- Privacy-safe generic push content only; no message body, filenames, private URLs, Feel It content, access tokens, refresh tokens, or cryptographic keys.
- Flutter Firebase Messaging integration, token rotation handling, background initialization, and tap routing hooks.
- Message and contact-request notification events are queued by the backend.

Deployment requirements:
- Create/configure a Firebase project and Android/iOS apps.
- Supply FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY and a random 32-byte base64 PUSH_TOKEN_ENCRYPTION_KEY only to the backend secret manager.
- Configure Flutter Firebase files using the deployment project's generated configuration; they are intentionally not fabricated in this repository.
- Run `npm run process:notifications` from a scheduler/worker environment.

Security note: notification delivery is not end-to-end encrypted. Payloads are deliberately minimized and contain generic text plus non-secret routing identifiers.
