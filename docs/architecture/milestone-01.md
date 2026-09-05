# SDS-DB Milestone 01 — Secure foundation

Implemented in this milestone:
- Server-side Google ID-token verification using Google's published JWKS.
- Separate SDS-DB access and rotating refresh sessions.
- PostgreSQL-backed users/devices/sessions.
- Authenticated quota reservation with atomic per-user/per-conversation accounting.
- Direct quota: 12 GiB/day per user per direct conversation.
- Group quota: 24 GiB/day per user per group conversation, independently for each group.
- Redacted authorization/cookie headers in server logs.
- Health endpoint and backend injection test.

Not yet implemented:
- Actual message transport and persistence APIs.
- WebSocket delivery.
- Private object-storage upload/download signing.
- Offline encrypted local database.
- Genuine end-to-end encryption.
- Push notifications.
- Account deletion workflow.
- Full Flutter Android build files (requires Flutter SDK/toolchain).
