# App Lock Security Model

## Scope

Milestone 18 integrates the existing app-lock foundation into authenticated Flutter content.

- `off`: authenticated content is not gated by app lock.
- `biometrics`: the operating system performs biometric verification through `local_auth`.
- `passcode`: remains intentionally unavailable for unlock until a vetted passcode verifier/KDF is integrated. SDS-DB does not invent password cryptography.

## Lifecycle behavior

The lock controller observes Flutter lifecycle transitions. When the app is backgrounded it records a timestamp in secure storage. On resume it evaluates whether the configured lock policy requires authentication. An explicit lock action immediately places the authenticated UI behind the lock surface.

The background timestamp is cleared only after successful biometric authentication.

## Privacy guarantees and limits

SDS-DB does not receive or store biometric templates. The OS owns biometric verification. The lock gate is application-level protection; it does not by itself prevent screenshots or task-switcher previews. Android `FLAG_SECURE` and any platform-specific privacy controls must be integrated in the Android shell before claiming screenshot/task-switcher protection.

## Android integration requirement

`local_auth` requires a `FlutterFragmentActivity` on Android and the `USE_BIOMETRIC` permission. The current repository snapshot does not contain a generated Flutter Android host, so these platform changes are documented as deployment/build integration work rather than represented by a fabricated Android project.

The current `local_auth` documentation confirms the FragmentActivity and `USE_BIOMETRIC` requirements. See the official package documentation for the exact platform setup. 
