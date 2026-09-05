# Milestone 16 — Privacy and Account Lifecycle

## Privacy
All privacy reads/writes require an authenticated SDS-DB session. Settings are upserted server-side and constrained to the documented fields and Feel It visibility enum.

## Account deletion
A deletion request creates one pending job per account and immediately revokes all sessions. A 24-hour grace period allows cancellation. When due, the worker records all private object keys, removes them from private object storage, then deletes account-owned relational data and marks the user as deleted with non-reusable placeholder identity data.

The current relational model has no anonymous-message sender representation, so messages authored by a deleted account are removed during finalization; messages authored by other users remain.

## Reports
Reports require exactly one target. User targets require an active target user. Message, conversation, and attachment targets require the reporter to be an active member of the relevant conversation. Moderation internals are not returned to clients.

## Worker execution

`npm run process:account-deletions` runs the pending deletion worker. In production it should be invoked by a private scheduler/container job, with storage and database credentials supplied through the deployment secret manager. No public HTTP endpoint is provided for destructive deletion processing.
