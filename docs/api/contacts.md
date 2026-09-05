# Contacts API

- `GET /api/v1/contacts`
- `GET /api/v1/contacts/requests`
- `POST /api/v1/contacts/requests`
- `POST /api/v1/contacts/requests/:requestId/accept`
- `POST /api/v1/contacts/requests/:requestId/decline`
- `DELETE /api/v1/contacts/:userId`
- `POST /api/v1/contacts/qr`
- `POST /api/v1/contacts/qr/consume`

Every endpoint requires an SDS-DB application session.

QR token consumption results in the same privacy-checked contact-request
flow as a normal request; it is not a privileged bypass.
