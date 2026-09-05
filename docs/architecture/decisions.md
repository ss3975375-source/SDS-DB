# Architecture decisions

1. **Flutter + feature-oriented clean architecture** for Android-first delivery and future iOS/web portability.
2. **Fastify + TypeScript** for a small, strongly typed backend with explicit schema validation and low overhead.
3. **PostgreSQL** for normalized relational integrity and transactional quota enforcement.
4. **Private object storage** rather than public file URLs.
5. **Per-user/per-conversation daily file usage**: direct conversations have a 12 GB daily limit per user; each group conversation independently gives each member a 24 GB daily limit.
6. **Feel It is a first-class domain**, separate from messages, because visibility and expiry are different lifecycle rules.
