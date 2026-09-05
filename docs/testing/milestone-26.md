# Milestone 26 — Automated Backend & Integration Test Infrastructure

This milestone establishes repeatable CI rather than claiming tests passed in an
environment without installed dependencies.

## Backend

CI provisions PostgreSQL 17, installs the locked dependency tree with `npm ci`,
then runs typecheck, lint, security audit, and the Node test suite.

Integration tests that require a real database should use the CI PostgreSQL
service and the test database URL. Tests must create their own fixtures and must
never use production credentials or production databases.

## Flutter

CI installs the stable Flutter SDK, runs `flutter pub get`, `flutter analyze`,
and `flutter test`. Device-level integration tests can be added separately with
an Android emulator or Firebase Test Lab. Flutter's official integration-test
workflow supports running on devices/emulators and Test Lab.

## Security test priorities

The suite explicitly targets OWASP API risks, especially object-level and
function-level authorization, authentication, and unrestricted resource
consumption. Every endpoint accepting an object identifier must have an
authorization test for both the owner/member and an unrelated user.

Reference: OWASP API Security Top 10 2023.
