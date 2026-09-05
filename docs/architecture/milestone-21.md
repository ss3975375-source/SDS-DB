# Milestone 21 — Messaging reliability and offline synchronization

## Scope

This milestone adds server-side idempotency and cursor-based message synchronization, plus a Flutter offline message repository backed by SQLite.

## Reliability model

- Every offline send gets a cryptographically random UUID client message ID.
- The backend uniquely scopes that ID to the sender and treats retries as idempotent.
- Reusing a client ID with different conversation/body/expiry is rejected with `409 client_message_id_reused`.
- The sync cursor is `(created_at, id)`, avoiding timestamp-only pagination gaps when multiple rows share a timestamp.
- Sync is authorized through active conversation membership.
- Deleted/expired messages are represented as tombstones; message content is not returned for them.

## Local security

Message bodies cached for offline use are encrypted at the application layer with AES-256-GCM. The key is generated once and stored in platform secure storage. SQLite metadata is not itself encrypted; therefore this milestone does not claim full-database-at-rest encryption.

The cryptography package is used rather than custom cryptographic code. Flutter's offline-first guidance recommends repositories as the single source of truth combining local and remote data sources. citeturn0search0turn1search1

## Sync behavior

1. Write encrypted message locally as `pending`.
2. Attempt authenticated POST with the client message ID.
3. On network failure, retain the row and retry later.
4. On success, store the server ID and mark the row sent.
5. Pull server changes using the cursor.
6. Merge by client message ID when available; otherwise insert by server ID.
7. Apply tombstones without restoring deleted content.

PostgreSQL's concurrency model supports explicit locking and transaction isolation for concurrent state transitions; the server uses a transaction plus row locking around idempotent message retries. citeturn0search3turn0search5

## Limitations

- Background synchronization scheduling is not yet wired to Android WorkManager.
- Real end-to-end encryption is not implemented or claimed.
- SQLite database metadata remains unencrypted.
