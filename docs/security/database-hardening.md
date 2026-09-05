# Database Security and Integrity Hardening

SDS-DB treats PostgreSQL as an enforcement boundary, not merely persistence.

## Rules

- Apply schema changes through the migration runner.
- Never mutate an already-applied migration.
- Back up before production migrations.
- Keep the migration ledger protected from application-level writes.
- Use transactions for state transitions that must be atomic.
- Use unique/check/foreign-key constraints for invariants that must survive application bugs.
- Avoid mutable expressions such as `now()` in partial-index predicates.
- Do not expose PostgreSQL directly to the Flutter client.
- Use least-privilege database credentials in production.
- Review query plans and lock impact for large indexes/constraints.

PostgreSQL supports constraints and indexes as database-level integrity mechanisms, and its documentation describes `NOT VALID` plus later validation as a way to reduce disruption when adding some constraints to populated tables. citeturn0search7turn0search2
