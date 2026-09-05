# SDS-DB 1.0.0 Release Candidate

## Release identity

- App version: `1.0.0+30`
- Application ID: `com.example.ultimate_privacy`
- Distribution target: Android App Bundle (AAB)

## Required before signing

1. Provision the production Firebase project and place its `google-services.json` only in the local Android project or CI secret store.
2. Provision Android release signing credentials through a secret manager/CI secret store. Never commit `android/key.properties` or the keystore.
3. Configure production backend environment variables outside the APK/AAB.
4. Apply database migrations using the controlled migration runner.
5. Run the backend security gate, typecheck, lint, and complete test suite in CI.
6. Run `flutter pub get`, `flutter analyze`, `flutter test`, and integration tests on supported Android devices/emulators.
7. Build with `flutter build appbundle --release --obfuscate --split-debug-info=<secure-symbol-dir>`.
8. Archive symbols securely; do not publish them with the application.
9. Verify the resulting AAB with bundletool/Play Console internal testing.

## Release gates

- No private keys in source/package.
- No backend secrets in Flutter assets or Dart source.
- No production cleartext HTTP endpoints.
- Security middleware registered before routes.
- Release signing cannot fall back to debug signing.
- Firebase configuration is supplied only at deployment time.
- Database migrations are checksum protected.
- Account deletion worker is run privately, not through a public endpoint.
- Push payloads contain no message bodies, private file URLs, tokens, or cryptographic keys.
- E2EE is not claimed unless a separately audited E2EE protocol is implemented.

## Known environment limitation

The repository package is a release candidate source package, not a signed production binary. The current build environment does not provide the Flutter SDK, Android SDK, production Firebase configuration, signing keys, or PostgreSQL service, so those release gates must be executed in the project's controlled CI/release environment.
