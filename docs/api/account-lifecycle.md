# Account, Privacy & Report API

- `GET /api/v1/privacy`
- `PUT /api/v1/privacy`
- `POST /api/v1/account/deletion`
- `POST /api/v1/reports`

All endpoints require an authenticated SDS-DB application session.

Account deletion requires explicit confirmation and creates a server-side
deletion job. It is not a client-only local logout.
