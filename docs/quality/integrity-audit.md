# SDS-DB Integrity Audit / Step 13.5

This milestone repairs known source-level consistency problems and adds
security-invariant tests.

## Repairs performed
- Backend route registration no longer uses an `await` form that conflicts with
  a synchronous Fastify app builder.
- Migration 013 no longer redefines notification tables already introduced
  earlier; it owns only the notification delivery log.
- Flutter test imports use the actual package name `sds_db`.
- Added dependency-free backend security invariant tests for notification
  payloads, pagination bounds, and file-size bounds.

## Verification status

This environment does not contain the Flutter SDK and previously did not have
the backend dependency tree installed. Therefore Flutter analyze/test/build and
backend test execution are not claimed as passed here.

Before release, run:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Android debug/release build
- backend `npm ci`
- backend typecheck
- backend test suite
- PostgreSQL migrations against a clean database
- PostgreSQL migrations against an upgraded database
- API integration tests
- dependency/license/SBOM scan

A green source audit is not a substitute for executing these commands.
