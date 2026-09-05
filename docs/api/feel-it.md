# Feel It API

Base path: `/api/v1/feel-it`

| Method | Path | Purpose |
|---|---|---|
| POST | `/feel-it` | Create a 24-hour post |
| GET | `/feel-it` | List posts visible to caller |
| POST | `/feel-it/:postId/view` | Record a view |
| PUT | `/feel-it/:postId/reaction` | Set/replace reaction |
| DELETE | `/feel-it/:postId/reaction` | Remove reaction |
| POST | `/feel-it/:postId/replies` | Reply to a visible post |
| GET | `/feel-it/:postId/viewers` | Author-only viewer list |
| DELETE | `/feel-it/:postId` | Author deletes own post |

All endpoints require an authenticated SDS-DB session.

Expired posts return as unavailable even if a client retains an old post ID.
