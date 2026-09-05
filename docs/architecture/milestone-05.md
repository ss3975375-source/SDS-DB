# SDS-DB Milestone 05 — Groups & Group Messaging

## Delivered
- First-class group conversations backed by the existing `conversations` and `conversation_members` model.
- Roles: `member`, `moderator`, `admin`.
- Server-authoritative membership and administrator checks on every mutation.
- Group creation, listing, details, rename, member add/remove, role changes, leave-group.
- Bounded group size of 500 active members.
- Secure invite links: 32-byte random bearer token, SHA-256 token hash at rest, expiration, maximum-use count, revocation, and transactional consumption.
- Group message send/read/delete endpoints reuse the conversation membership boundary; no special client-side authorization is trusted.
- Flutter group repository and initial group management UI.

## Invite security
Invite tokens are returned only at creation time. The database stores only a SHA-256 hash. Links expire and can be revoked by an administrator. Invite use is serialized with a row lock to avoid concurrent use-count races.

## Authorization
The client may hide controls for non-admins, but the backend is authoritative. A user who is not an active group member cannot read, send, or mutate group resources.

## Limits
- Maximum active members: 500.
- Invite TTL: 1–168 hours.
- Invite maximum uses: 1–1000.

## Not yet claimed
Group E2EE is not implemented. Group messages currently use the authenticated TLS transport and server-side access control. A future E2EE layer must be designed and reviewed separately.
