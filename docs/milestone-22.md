# Milestone 22 — Message lifecycle

This milestone adds durable delivery/read receipts and server-side expiry processing.

## Disappearing messages
`expires_at` is authoritative on the server. Read/sync APIs suppress expired content, while the expiry worker converts expired messages into tombstones (`deleted_at` + `body=NULL`) and marks linked attachments deleted. Private object deletion is attempted asynchronously.

Run periodically with `npm run process:expired-messages`.

## Receipts
Authenticated members may mark a received message delivered. Read receipts are only recorded when the reader's `privacy_settings.read_receipts_enabled` is enabled. Only the sender may retrieve receipts for a message.

Receipt endpoints are intentionally separate from message content endpoints and return no message body.

## Concurrency
Expiry claiming uses PostgreSQL row locks with `SKIP LOCKED`, allowing multiple workers to process different expired messages without waiting on one another. PostgreSQL documents `SKIP LOCKED` as suitable for queue-like concurrent consumers. 

## Security
- No receipt endpoint exposes message contents.
- Membership is checked before every receipt operation.
- Read-receipt privacy is enforced server-side.
- Expiry is enforced by query predicates and by a worker; the client is never trusted to delete disappearing messages.
- Storage deletion failures do not restore expired message visibility.
