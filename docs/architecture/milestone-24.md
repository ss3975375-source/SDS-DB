# Milestone 24 — Database and Migration Hardening

## Goals

- Make clean and upgraded installations converge on the same canonical schema.
- Detect accidental edits to already-applied migrations.
- Serialize migration execution across deployment processes.
- Repair historical `IF NOT EXISTS` schema collisions.
- Keep security and integrity constraints at the database boundary.

## Migration runner

Backend commands:

- `npm run migrate` — apply pending migrations.
- `npm run migrate:status` — report pending/applied/checksum-changed migrations.

The runner:

1. Discovers SQL migrations in deterministic filename order.
2. Stores SHA-256 checksums in `schema_migrations`.
3. Refuses to silently accept a changed migration after it has been applied.
4. Uses a PostgreSQL advisory lock so two application instances cannot migrate concurrently.
5. Runs each migration in its own transaction.

A production deployment must back up the database and review the migration plan before applying it. Long-running index changes should be handled separately when necessary; PostgreSQL documents `REINDEX CONCURRENTLY` for reducing write blocking during index rebuilds. citeturn0search0

## Canonical schema repairs

Earlier migrations defined Feel It and reports with incompatible column names while using `IF NOT EXISTS`. Migration 024 converges these to:

- `feel_it_posts.author_id`
- `feel_it_posts.text_content`
- `feel_it_posts.attachment_id`
- `reports.reported_user_id`

Legacy Feel It object keys are copied to `legacy_object_key` rather than silently discarded.

The repair is intentionally explicit because PostgreSQL `ALTER TABLE` changes table definitions and constraints at the database level; application-only compatibility would leave different installations with different schemas. citeturn0search2

## Concurrency

Quota, message idempotency, deletion workers, and migration execution rely on PostgreSQL transactional/concurrency guarantees rather than UI coordination. PostgreSQL's concurrency-control model is designed to maintain data integrity when multiple sessions operate concurrently. citeturn0search1

## Production rule

Do not edit an applied migration. Create a new migration. A checksum mismatch is treated as an operational error.

## Historical migration compatibility

A small pre-016 compatibility migration repairs the legacy `reports.target_user_id` name before milestone 016 references `reported_user_id`. Milestone 024 repeats the repair defensively for databases upgraded outside the official migration sequence.
