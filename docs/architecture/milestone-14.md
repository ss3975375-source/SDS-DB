# Milestone 14 — Production file transfer

SDS-DB now uses authenticated S3 multipart uploads rather than a single in-memory client upload.

## Transfer lifecycle

1. Backend authorizes conversation membership and atomically reserves the declared byte count in `file_usage_daily`.
2. Backend creates a private S3 multipart upload and stores its provider upload ID.
3. Client requests a short-lived signed URL for each part.
4. Client uploads the part directly to private object storage.
5. Client records the returned ETag and exact expected byte count through the authenticated API.
6. Backend requires every part from 1 through N before completion.
7. Backend completes the provider multipart upload and verifies final object size with `HeadObject`.
8. Backend converts the reservation into `bytes_used` and creates attachment metadata in one DB transaction.

## Quota invariants

- Direct conversations: 12 GiB/day per user per conversation.
- Groups: 24 GiB/day per user per group.
- Reservations and usage are keyed by user + UTC database `CURRENT_DATE` + conversation.
- Uploads retain their original `usage_date`, so completion/abort after midnight does not affect a different day's quota.

## Security boundaries

The Flutter client never receives storage credentials. Object keys are private and are not exposed as public URLs. Signed URLs are short-lived. The backend remains the authorization boundary for starting, resuming, completing, and aborting transfers.

End-to-end encryption is not claimed. Malware scanning and client-side file encryption remain separate milestones.

## Message attachment linking

Completion creates private attachment metadata without guessing which message will contain it. The authenticated owner can then link the completed upload to a message only when the message belongs to the same conversation and was authored by that user. Download authorization follows the resulting message membership relationship.
