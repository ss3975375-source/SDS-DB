# Milestone 19 — Feel It production implementation

Feel It is now a database-backed ephemeral content feature.

## Server guarantees
- Every post expires 24 hours after creation and expired/deleted posts are inaccessible through the API.
- Visibility is enforced server-side for `contacts`, `selected`, and `exclude`.
- Selected/excluded identities must be accepted contacts and cannot be blocked in either direction.
- A blocked relationship prevents viewing regardless of visibility mode.
- Media is referenced by an existing private attachment; no public object URL is created.
- Media access uses a short-lived signed URL only after post visibility authorization.
- Views are idempotent.
- One reaction per user/post is enforced by the database primary key.
- Replies are length-limited and require visibility authorization.
- Only the post author can read viewer information or delete the post.
- Deletion marks both post and attachment deleted and attempts immediate object removal; account deletion remains the asynchronous cleanup backstop.
- Push notifications contain only a generic category and post ID; content is never placed in notification payloads.

## Media limitation
The existing upload system is conversation-scoped. A Feel It media post therefore consumes an attachment that was already uploaded by the same account through the private file pipeline. A future media-upload milestone can add a dedicated Feel It upload scope if required.
