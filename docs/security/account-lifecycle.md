# Account Lifecycle & Privacy — Step 10

## Privacy controls

Users can control:
- discovery by user ID
- contact requests
- read receipts
- typing indicators
- presence
- default Feel It visibility

Backend authorization is always authoritative. Hiding a client control does
not itself enforce privacy.

## Blocking

A blocked relationship must be enforced at the server for contact discovery,
invitations, messaging, group operations, and other applicable interactions.

## Reporting

Reports can target exactly one supported object:
- user
- message
- conversation
- attachment

Report records contain only the minimum data required for moderation and
security workflows. Moderation internals are not exposed to normal users.

## Account deletion

Deletion is a backend-controlled asynchronous workflow:
1. authenticate the requesting account;
2. require explicit confirmation;
3. revoke active sessions;
4. mark the account as pending deletion;
5. remove profile/device/contact/block/notification data;
6. remove Feel It data and private objects;
7. handle messages according to the documented retention policy;
8. preserve only minimum records that must legally or operationally remain;
9. mark the deletion job completed.

Private object deletion may be asynchronous because object storage cleanup is
a separate system. SDS-DB therefore does not promise instantaneous physical
deletion of every copy.

## Data minimization

The product should not collect unnecessary advertising identifiers,
precise location, or unrelated device telemetry.
