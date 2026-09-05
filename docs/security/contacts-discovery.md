# Contacts and discovery security

The Contacts API does not expose a public user directory. Exact user-ID discovery is permitted only when the target's `discoverable_by_user_id` privacy setting is enabled and the target is active.

Contact requests are authenticated, authorization-checked, block-aware, and protected against duplicate pending requests. Accepting a request creates reciprocal accepted contact rows in one transaction.

QR tokens are 256-bit random opaque values. Only SHA-256 hashes are stored. Tokens have bounded expiry and use counts; consumption locks the token row and the user pair so concurrent scans cannot exceed the configured maximum. A token is revoked automatically when its final permitted use is consumed.

QR payloads must contain only the opaque token. They must never contain access tokens, refresh tokens, passwords, private keys, message contents, or private object URLs.
