import pg from 'pg';
import { config } from '../config/env.js';

export const pool = new pg.Pool({
  connectionString: config.databaseUrl,
  max: 10,
  ssl: config.nodeEnv === 'production' ? { rejectUnauthorized: true } : undefined,
});
