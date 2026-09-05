# Security baseline

- Transport: HTTPS/WSS only in production.
- Google authentication: client obtains Google identity assertion; backend independently verifies it before issuing an SDS-DB session.
- Sessions: application access credentials are distinct from Google credentials; refresh tokens are stored hashed server-side and revocable.
- Client secrets: no backend secrets, storage credentials, JWT signing secrets, or signing keys in Flutter.
- Files: object storage is private. Downloads require authenticated authorization and short-lived access where appropriate.
- Logs: redact authorization headers and never log passwords, tokens, private keys, message bodies, or file contents.
- E2EE: not claimed in this milestone. The architecture leaves room for future E2EE, but transport encryption is not equivalent to E2EE.
- App lock/biometrics: local protection is defense-in-depth and does not guarantee protection against a compromised device.
- Quotas: 12 GB/user/day across direct conversations; 24 GB/user/group/day independently for every group. Quota enforcement is server-side and must be atomic.
- Feel It: default 24-hour expiration, privacy-controlled visibility, private storage, server-enforced expiry.
