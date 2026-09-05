# SDS-DB Milestone 04 — Secure Private File Sharing

Flutter authenticates -> backend authorizes conversation membership and quota -> backend issues a short-lived private object-storage PUT URL -> Flutter uploads directly -> backend verifies object size -> attachment metadata is committed. Downloads repeat authorization and use a short-lived GET URL.

- Direct quota: 12 GiB/day/user/conversation.
- Group quota: 24 GiB/day/user/group.
- Reservations count against quota to prevent concurrent oversubscription.
- Private bucket; storage master credentials remain server-side.
- Filename normalization, size limits, MIME allow-list, object-size verification.
- Production still needs malware scanning, lifecycle cleanup, resumable multipart transfers, and optional client-side file encryption.
