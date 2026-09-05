# Milestone 20 — Session and Device Lifecycle Hardening

## Scope

This milestone makes device/session management database-backed and authorization-safe.

## Session rules

- Every access token is tied to a database session.
- Authentication rejects revoked/expired sessions and deleted accounts.
- Authenticated requests update `last_seen_at` for the session and device.
- Refresh-token rotation creates a replacement session and records `replaced_by_session_id`.
- A refresh token cannot revive a revoked device.
- Users may list sessions, revoke one session, revoke all other sessions, or revoke all sessions.
- Session revocation is always scoped to the authenticated user.

## Device rules

- Device records do not expose precise location, IP address, hardware identifiers, or other unnecessary metadata.
- When a device has no active session, it is revoked.
- Push registrations associated with a revoked device are disabled.
- Re-authentication creates a fresh device/session association.

## Security properties

- User-supplied `userId` is never accepted for session ownership.
- Session IDs are UUID-validated at the route boundary.
- Revocation is atomic with associated device invalidation.
- `revoke-all` immediately invalidates the caller's current access token; clients must clear local credentials after receiving the response.
- Refresh-token plaintext is never logged or stored.
