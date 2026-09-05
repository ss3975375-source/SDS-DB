# Milestone 29 — Final Privacy & Security Review

This milestone is a release-candidate security gate, not a claim of formal certification or penetration testing.

## Verification baseline

The review is mapped conceptually to OWASP ASVS 5.0.0, the current stable ASVS release. It focuses on authentication, authorization, session management, error handling, logging, secrets, data exposure, file access, and release configuration.

## Fixed in this milestone

- Security plugins are registered before application routes so Helmet, CORS, and rate limiting are applied consistently.
- Malformed/expired JWTs are treated as authentication failures and return 401 rather than an internal-server-error response.
- Generic 4xx responses avoid reflecting internal exception details.
- Health checking is excluded from the application rate limit.
- Helmet uses a restrictive no-referrer policy; CSP remains disabled because this backend is an API rather than an HTML document server.
- Existing sensitive log redaction remains enabled.
- Production configuration continues to reject placeholder JWT secrets and non-HTTPS CORS origins.
- Firebase and storage credentials remain backend-only.

## Privacy gates

The following must remain true before release:

- No message body is placed in push notifications.
- No private file URL is placed in push notifications or public API responses.
- No refresh/access token is logged.
- No Google password is stored.
- Private object storage remains private.
- File access requires authenticated authorization.
- Account deletion remains destructive and requires the documented grace period.
- Contact discovery remains privacy-controlled.
- Feel It visibility is server-authoritative.

## Release gate limitations

A source-level review cannot replace a production penetration test, dependency audit, device test, or independent cryptographic review. Before public release, run the CI pipeline with a real PostgreSQL service, execute Flutter analyzer/tests, build the signed Android AAB, test it on supported Android versions, and perform an external security assessment.
