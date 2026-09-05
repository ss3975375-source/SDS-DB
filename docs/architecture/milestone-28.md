# Milestone 28 — Android release automation

This milestone converts the previously documented Android release hardening into a reproducible release project structure.

Key decisions:

- Application ID remains `com.example.ultimate_privacy`.
- Release signing is mandatory and never falls back to the debug key.
- `FlutterFragmentActivity` is used for biometric compatibility.
- Cleartext HTTP is disabled at the Android application layer.
- Android backup/transfer excludes local private application data.
- R8/resource shrinking is enabled for release builds.
- Dart obfuscation uses `--obfuscate` plus `--split-debug-info`.
- Firebase Android configuration is deployment-time input, not a repository secret.
- AAB is the preferred Play artifact.
