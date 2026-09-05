# Local Security — Step 8

## App lock

SDS-DB supports:
- off
- passcode
- biometrics

The app observes lifecycle transitions and records only a timestamp used to
decide whether the app should lock when it returns to the foreground.

## Biometrics

SDS-DB delegates biometric verification to the operating system through
`local_auth`. The app never receives or stores the user's fingerprint,
face template, or other biometric material.

A biometric lock is not the same thing as encrypting the database. Local
database encryption and key management remain separate controls.

## Passcodes

The plaintext app passcode must never be persisted. The scaffold stores only
a verifier placeholder. Before production, the verifier must be generated
with a vetted password KDF/crypto library; SDS-DB will not implement a
custom cryptographic algorithm.

## Secure storage

Session credentials and security settings use secure platform-backed storage
where available. Secrets must not be moved to SharedPreferences, ordinary
JSON files, or logs.

## Background privacy

The application can place a lock boundary around protected screens. The OS
may still capture transitions or notification metadata depending on platform
behavior. SDS-DB therefore avoids absolute claims about preventing all
screenshots or screen recording.

## Security limitation

This milestone does not claim that every cached message/file is encrypted
at rest. A separate encrypted local database/key-management implementation
is required before making that claim.
