# Authentication API

## `POST /api/v1/auth/google`

Accepts a Google identity token from the Flutter client. The server verifies the token signature, issuer, audience and verified-email claim before creating/loading the SDS-DB user and issuing an SDS-DB session.

Request:
```json
{
  "identityToken": "<google-id-token>",
  "platform": "android",
  "deviceLabel": "optional device label"
}
```

Response contains the user profile plus a short-lived access token and rotating refresh token. Tokens must never be logged.

## `POST /api/v1/auth/refresh`

Consumes a refresh token and rotates the session. A refresh token can only be used once because the previous session is revoked during rotation.

## `POST /api/v1/auth/logout`

Requires `Authorization: Bearer <access-token>`. Revokes the current session.
