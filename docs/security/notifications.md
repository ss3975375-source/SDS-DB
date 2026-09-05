# Push Notifications — Step 13

## Privacy contract

Notification payloads are generic and contain no:
- message bodies
- file names or file contents
- Feel It text/media
- private object URLs
- access/refresh tokens
- cryptographic keys
- sensitive profile information

The app defaults lock-screen previews to off.

## Device token security

Push tokens are credentials and are not treated as public identifiers.
The server should:
1. authenticate the app session;
2. validate the token format;
3. hash the token for lookup/deduplication;
4. encrypt the token at rest using a backend-only key;
5. associate it with the authenticated user;
6. revoke/disable stale tokens;
7. never return the raw token from the API.

## Delivery

Push notifications are hints to wake/surface the app. The client must fetch
authorized data over HTTPS/WSS rather than trusting push payloads as a source
of private content.

## Revocation

Logout/session revocation and device notification-token revocation should be
handled independently. Account deletion must revoke notification devices.

## FCM

Actual Firebase/FCM SDK integration and provider credentials must be added only
through the Android/iOS build configuration and backend secret management.
No provider secret belongs in the Flutter APK.
