# Milestone 15 — Contacts + QR

Contacts are database-backed and authenticated. There is no public directory.

## Operations
- List accepted contacts and pending requests.
- Send, accept, decline, and cancel contact requests.
- Remove a contact from both users' lists.
- Discover a user by exact UUID only when that user has enabled discovery.
- Generate opaque, hashed, expiring QR tokens.
- Consume QR tokens atomically; QR consumption creates a mutual accepted contact.

## Security
- Every endpoint requires the SDS-DB access session.
- Deleted users are excluded.
- Blocking either direction prevents contact operations.
- Contact-request privacy is checked server-side.
- QR plaintext is returned only at creation time and is never persisted.
- QR consumption uses a row lock and increments usage atomically.
- Pair operations use a PostgreSQL transaction advisory lock to serialize races.
- No Google credentials or session tokens are stored in contact records.
