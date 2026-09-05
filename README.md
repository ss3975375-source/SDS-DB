# SDS-DB

Privacy-first communication and secure file-sharing platform.

## Milestone 01 — working foundation

This repository now contains the first real application foundation rather than a UI-only mock:

- Flutter app shell with Material 3.
- Current `google_sign_in` 7.x integration pattern.
- Server-side Google ID-token verification using Google's published signing keys.
- Separate SDS-DB access/refresh sessions with refresh-token rotation.
- PostgreSQL users, devices and sessions.
- Authenticated per-conversation upload quota reservation.
- **Direct:** 12 GiB/day per user per 1-to-1 conversation.
- **Groups:** 24 GiB/day per user per group, independently for every group.
- Secure-session storage on Flutter via `flutter_secure_storage`.
- Initial security-focused app shell and sign-out flow.

## Not yet production-ready

Messaging, WebSockets, private object storage, offline encrypted database, push notifications, account deletion, full device/session UI, genuine E2EE, malware scanning and complete Android release configuration still need implementation and testing.

The available build environment does not contain the Flutter SDK, so Flutter/Android compilation cannot be honestly reported as passed here.

## Backend

```bash
cd backend
npm install
npm run typecheck
npm test
npm run build
```

Set the variables in `.env` using `.env.example` before starting the API.

## Flutter

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

Never place database credentials, JWT signing secrets, object-storage master credentials, or private API keys in Flutter `--dart-define` values.

## Milestone 05
Secure private file sharing: S3-compatible signed uploads/downloads, transactional quota reservations, attachment finalization, and private-object authorization.


## Current milestone
Milestone 05 adds groups, role-based administration, secure invite links, and group messaging APIs. Group E2EE is not claimed.


## Milestone 06 — Feel It

Added the Feel It ephemeral-content domain:
- 24-hour server-enforced expiry
- contacts / selected / exclude visibility
- private media attachment integration point
- viewer receipts
- reactions
- replies
- author-only viewer lists
- delete flow
- Flutter Feel It UI/repository foundation

This milestone intentionally does not claim end-to-end encryption.


## Milestone 07 — Push Notifications

Added the notification privacy foundation:
- FCM device registration model
- per-user notification preferences
- per-conversation mute model
- privacy-safe notification payload builder
- Flutter notification settings/repository foundation
- notification security and API documentation

Notification payloads intentionally exclude private message/file/Feel It content.


## Milestone 08 — App Lock & Local Security

Added:
- app lock modes: off, passcode, biometrics
- lifecycle lock controller
- OS-backed biometric authentication foundation
- secure-storage-based lock settings
- security settings UI
- local-security architecture and threat-boundary documentation

The passcode implementation intentionally does not invent cryptography.
Local database encryption remains a separate future milestone.


## Milestone 09 — Device & Session Security

Added:
- session/device revocation data model
- refresh-token hashing helpers
- session metadata sanitization
- revoke-one / revoke-others / revoke-all API foundation
- Flutter sessions repository and device/session UI
- session security documentation and tests

Precise location, hardware identifiers, raw refresh tokens, and other
unnecessary identifiers are intentionally excluded from the session UI.


## Milestone 10 — Account Lifecycle & Privacy

Added:
- privacy settings data model and Flutter UI foundation
- account deletion job model
- deletion workflow service contract
- privacy/report/account API foundation
- reporting target validation
- account deletion and retention security documentation

Deletion is intentionally asynchronous and does not make an unsupported
instantaneous physical-deletion guarantee.


## Milestone 11 — Contacts, Discovery & QR Invitations

Added:
- contact request and contact database model
- privacy-aware contact service contract
- QR invitation token model
- contact API foundation
- Flutter contact models/repository/UI foundation
- private discovery and QR security documentation

The route layer intentionally retains TODO/501 markers until the next
implementation pass; no unverified production behavior is claimed.

## Milestone 12 — Contact & Discovery Hardening

Added security primitives, database uniqueness/index hardening, bounded discovery
contract, QR token generation/hashing, contact-request invariants, cancellation
contract, and automated primitive tests. Database-backed handlers remain explicitly
marked for integration with the repository's existing DB/auth helpers.

## Milestone 13 — Push Notifications & Privacy

Added notification-device and preference schema, privacy-safe payload helpers,
provider-neutral device registration contracts, Flutter preferences/repository/UI,
and notification security/API documentation. Provider-specific FCM delivery
remains intentionally unconfigured until Firebase credentials and native SDK
configuration are supplied.

## Step 13.5 — Project Integrity & Repair

This release consolidates known source-level repairs before further feature work.
It removes the duplicate notification schema introduced by the prior milestone,
fixes backend route-registration syntax, corrects Flutter package-name test
imports, and adds dependency-free backend security-invariant tests.

Build/test execution remains explicitly unverified where the required SDK or
dependency installation is unavailable.

## Milestone 14 — Resumable private file transfer

- S3 multipart uploads with 8 MiB parts.
- Authenticated upload-session creation and part URL issuance.
- Server-side part metadata tracking and contiguous-part validation before completion.
- Daily quota reservations are tied to the upload's reservation date, so uploads crossing midnight cannot debit the wrong quota bucket.
- Completed objects are HEAD-verified against the declared size before attachment creation.
- Incomplete multipart uploads can be aborted and their reserved quota released.
- Download URLs remain short-lived and are issued only after conversation-membership authorization.
- This milestone does **not** provide end-to-end encryption or malware scanning.

## Step 15 — Contacts + QR
Implemented database-backed Contacts and QR flows with authenticated request/response authorization, block/privacy enforcement, reciprocal contacts, exact-ID discovery, hashed expiring QR tokens, atomic QR consumption, and backend contract tests. See `docs/architecture/milestone-15.md` and `docs/security/contacts-discovery.md`.

## Milestone 16 — Privacy + Account Lifecycle

Implemented database-backed privacy settings, account deletion requests with a 24-hour grace period, immediate session revocation, deletion cleanup tracking, private object cleanup, cancellation during the grace period, and authorized report creation. Reports validate that the reporter can access the target and store only the minimum moderation fields required by the schema.

Deletion processing is exposed only as a development/test internal route in this milestone; production should run the same service from a private scheduler/worker with authenticated internal execution.

## Milestone 20

Session and device lifecycle hardening is included in `database/migrations/020_session_device_hardening.sql`, with authenticated session management routes and refresh/device revocation safeguards.

## Database migration hardening

Milestone 24 adds a checksum-protected migration runner and canonical schema repair. Use `npm run migrate:status` to inspect migration state and `npm run migrate` to apply pending migrations. See `docs/architecture/milestone-24.md` and `docs/security/database-hardening.md`.

## Milestone 26 — Automated Verification Infrastructure

Added CI for backend and Flutter analysis/tests, PostgreSQL-backed backend test
execution, security-contract tests, and testing guidance. A package lockfile is
not fabricated when it is absent; create it with the project's approved npm
version before using `npm ci`.

## Android release

Use `./scripts/build-release.sh` after provisioning local signing and Firebase configuration. See `docs/deployment/android-release.md`. Production signing credentials and Firebase configuration are intentionally excluded from this repository.

## Security release gate

Before a public release, run `npm run security:gate` from `backend`, the full CI pipeline, Flutter analyzer/tests, and a signed Android release build. This repository does not claim independent penetration testing or formal ASVS certification.


## Milestone 30 — Release Candidate

This package is the final source release-candidate handoff. It adds a deterministic release-candidate gate, final release documentation, and version `1.0.0+30`. A signed AAB is intentionally not included because signing credentials and Firebase production configuration are deployment secrets.

Run `node scripts/release-candidate-gate.mjs` from the repository root before the controlled CI release process. See `docs/release-candidate.md`.
