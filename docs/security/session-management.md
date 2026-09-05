# Session Management Security — Milestone 20

SDS-DB treats the access JWT as a short-lived capability, while the database session is the authoritative revocation state.

### Controls

1. Access tokens contain only session/user identifiers and a token type.
2. Every authenticated request checks the session database row.
3. Expired, revoked, or deleted-account sessions are rejected.
4. Refresh credentials are stored only as hashes.
5. Refresh rotation revokes the old session before returning the replacement credential.
6. Session revocation is ownership-checked against the authenticated principal.
7. Device revocation prevents stale refresh credentials from being reused.
8. Push registrations are disabled when their owning device/session is revoked.
9. Session listings intentionally omit IP address, precise location, and hardware identifiers.

The client must treat local logout as credential deletion and should also unregister the push token where appropriate.
