# Notification API

- `GET /api/v1/notifications/preferences`
- `PUT /api/v1/notifications/preferences`
- `POST /api/v1/notifications/devices`
- `DELETE /api/v1/notifications/devices/:deviceId`

All endpoints require an authenticated SDS-DB session.

The server must enforce ownership of notification devices and preferences.
Push delivery should contain only privacy-safe generic metadata.
