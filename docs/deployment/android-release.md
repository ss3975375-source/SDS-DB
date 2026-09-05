# Android release procedure

SDS-DB uses an Android App Bundle for Play distribution. Flutter recommends AAB for Play delivery and documents release signing, R8, manifest review, and bundle testing. See the official Flutter Android release guide.

## Required local files

Never commit these files:

- `android/key.properties`
- `android/upload-keystore.jks`
- `android/app/google-services.json` (the file contains project identifiers; keeping it out of source is the repository policy)

Use `android/key.properties.example` as the template.

## Release build

From the repository root:

```text
./scripts/build-release.sh
```

The script validates signing/Firebase configuration, runs Flutter analysis/tests, then builds an obfuscated release AAB and stores Dart symbol files outside the distributable.

Flutter's current documentation states that release builds support `--obfuscate` and `--split-debug-info`; the symbol files must be retained securely for later stack-trace symbolization.

## CI secrets

Configure these repository secrets:

- `ANDROID_KEYSTORE_B64`
- `ANDROID_KEY_PROPERTIES`
- `GOOGLE_SERVICES_JSON`

The workflow writes them only into the ephemeral runner workspace and does not print them.

## Signing

Use Google Play App Signing for Play distribution. The repository contains only signing configuration templates; it must never contain a production private key.

## Firebase

The Android app applies the Google Services Gradle plugin. Firebase's Android setup requires the plugin and `google-services.json`. Obtain the configuration from the project's Firebase console and provide it through the protected deployment mechanism.

## Release invariants

- No debug signing for release.
- No production secrets in Git.
- No release build without explicit signing configuration.
- No plaintext credentials in CI logs.
- Keep obfuscation symbols private.
- Test the AAB through an internal Play testing track before production.
