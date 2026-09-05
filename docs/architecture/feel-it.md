# Feel It — Step 6

Feel It is SDS-DB's temporary status/story-style content feature.

## Lifecycle

1. User creates text or attaches private media.
2. Backend validates ownership and visibility settings.
3. Backend assigns a 24-hour expiry.
4. Backend authorizes every read using the visibility rules.
5. A view is recorded once per viewer/post.
6. Reactions and replies are authorized against the same visibility rules.
7. At expiry, the post is no longer readable through the API.
8. A cleanup worker asynchronously deletes expired database rows and
   associated private objects according to the storage retention policy.

## Visibility

Supported modes:
- contacts
- selected contacts
- exclude

The client does not decide whether a viewer is allowed to see a post.

## Privacy

Feel It is not a public directory. Media uses the existing private object
storage model and short-lived authorized access. Notification payloads must
not contain private post contents by default.

## Viewer privacy

Viewer information is author-only. A user cannot enumerate viewers of
another user's post.

## Expiry

Expiry is server-enforced. The Flutter client may hide expired items for UX,
but that is not a security boundary.

## Security status

This milestone does not claim end-to-end encryption for Feel It. Transport
protection and private storage authorization are separate from E2EE.
