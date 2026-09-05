
## Push notification privacy
FCM registration tokens are credentials. SDS-DB stores a SHA-256 lookup hash and an AES-256-GCM encrypted token using a backend-only 32-byte key. Push payloads are generic and exclude message text, file metadata/content, Feel It content, private object URLs, session credentials, and cryptographic keys. Invalid FCM tokens are revoked automatically. FCM provider credentials remain server-side.
