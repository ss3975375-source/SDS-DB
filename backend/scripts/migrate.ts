import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db/pool.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.resolve(here, '../../database/migrations');

async function ensureLedger() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      migration_key text PRIMARY KEY,
      checksum_sha256 text NOT NULL CHECK (char_length(checksum_sha256) = 64),
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `);
}

async function files() {
  const names = (await fs.readdir(migrationsDir))
    .filter((name) => name.endsWith('.sql'))
    .sort();
  return Promise.all(names.map(async (name) => {
    const full = path.join(migrationsDir, name);
    const sql = await fs.readFile(full, 'utf8');
    return { name, sql, checksum: crypto.createHash('sha256').update(sql, 'utf8').digest('hex') };
  }));
}

async function withLock<T>(fn: () => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('SELECT pg_advisory_lock(hashtext($1))', ['sds-db:migrations']);
    return await fn();
  } finally {
    await client.query('SELECT pg_advisory_unlock(hashtext($1))', ['sds-db:migrations']).catch(() => undefined);
    client.release();
  }
}

async function status() {
  await ensureLedger();
  const applied = new Map<string, { checksum_sha256: string; applied_at: Date }>();
  for (const row of (await pool.query('SELECT migration_key,checksum_sha256,applied_at FROM schema_migrations ORDER BY migration_key')).rows) {
    applied.set(row.migration_key, row);
  }
  for (const migration of await files()) {
    const row = applied.get(migration.name);
    console.log(`${row ? row.checksum_sha256 === migration.checksum ? 'applied' : 'CHANGED' : 'pending'} ${migration.name}`);
  }
}

async function apply() {
  await withLock(async () => {
    await ensureLedger();
    const migrations = await files();
    for (const migration of migrations) {
      const existing = await pool.query('SELECT checksum_sha256 FROM schema_migrations WHERE migration_key=$1', [migration.name]);
      if (existing.rows[0]) {
        if (existing.rows[0].checksum_sha256 !== migration.checksum) {
          throw new Error(`Migration checksum changed after application: ${migration.name}`);
        }
        continue;
      }
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(migration.sql);
        await client.query(
          'INSERT INTO schema_migrations(migration_key,checksum_sha256) VALUES($1,$2)',
          [migration.name, migration.checksum],
        );
        await client.query('COMMIT');
        console.log(`applied ${migration.name}`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`Migration failed: ${migration.name}: ${error instanceof Error ? error.message : String(error)}`);
      } finally {
        client.release();
      }
    }
  });
}

const command = process.argv[2] ?? 'apply';
try {
  if (command === 'status') await status();
  else if (command === 'apply') await apply();
  else throw new Error(`Unknown command: ${command}. Use apply or status.`);
} finally {
  await pool.end();
}
