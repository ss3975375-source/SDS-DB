# Local Security Architecture

App lifecycle
  -> AppLockController
  -> AppLockService
  -> Android/iOS secure authentication APIs

Session secrets
  -> platform secure storage

Local database encryption
  -> separate key-management layer
  -> encrypted database implementation in a later milestone

The app lock is a user-interface access control and does not replace
backend authorization, session revocation, or storage encryption.
