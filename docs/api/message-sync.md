# Message synchronization API

## Send

`POST /api/v1/messages/:conversationId`

Authenticated JSON body:

- `body`: 1–10,000 characters
- `expiresInSeconds`: optional, 0–30 days
- `clientMessageId`: optional UUID; clients should always supply one for retry-safe offline sends

A successful retry with the same sender/client ID returns the existing message with `replayed: true`. Reuse with different message parameters returns `409 client_message_id_reused`.

## Sync

`GET /api/v1/messages/:conversationId/sync?limit=100&cursor=...`

Returns messages for the specified conversation, provided the authenticated user is an active member. Cursor ordering is `(created_at, id)`.

Deleted or expired messages have `body: null` and a deletion/expiry marker. The endpoint never exposes message rows from conversations for which the user lacks active membership.
