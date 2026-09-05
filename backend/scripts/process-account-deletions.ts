import { processPendingAccountDeletions } from '../src/services/accountLifecycleService.js';
import { pool } from '../src/db/pool.js';

try {
  const processed = await processPendingAccountDeletions(10);
  console.log(JSON.stringify({processed}));
} finally {
  await pool.end();
}
