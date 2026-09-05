# Milestone 25 — Security Audit and Regression Hardening

## Scope

This milestone performs a source-level security review of authentication, authorization boundaries, secrets, logging, configuration, and privacy-sensitive data handling.

## Controls added

- Production startup rejects placeholder JWT secrets.
- Production startup requires HTTPS-only, non-local CORS origins.
- Production push notifications require all provider credentials when enabled.
- Fastify logging redacts authorization, cookies, identity/refresh/access tokens, passwords, secrets, private keys, database credentials, and FCM tokens.
- Unexpected errors are returned as a generic 500 response; authentication failures return 401 without internal details.
- A repository security scanner checks for high-confidence hard-coded private keys, credentials, database passwords, and Google API-key-like values.
- Security regression tests cover redaction and production CORS policy.

## Logging policy

Security events may be logged using request IDs and event names, but message bodies, private files, tokens, credentials, cryptographic keys, and sensitive personal data must not be logged. This follows OWASP guidance that access tokens, passwords, database connection strings, encryption keys, and sensitive personal data should not be recorded directly. citehttps://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html

Authentication failures and authorization failures should be observable as security events without recording the protected data itself. citehttps://cornucopia.owasp.org/taxonomy/asvs-5.0/16-security-logging-and-error-handling/03-security-events

## Secrets policy

Secrets remain deployment-time configuration and are never committed to the repository or shipped to Flutter. Secrets should be rotatable, revocable, and never written to logs. citehttps://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

## Verification

Run:

```text
npm run security:audit
npm test
npm run typecheck
```

The latter two require installed backend dependencies. Flutter verification additionally requires a Flutter SDK and platform toolchain.
