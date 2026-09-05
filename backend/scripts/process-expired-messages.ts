import { pool } from '../src/db/pool.js';
import { expireMessages } from '../src/services/messageLifecycleService.js';

try {
  const count = await expireMessages(500);
  console.log(`expired_messages=${count}`);
} finally {
  await pool.end();
}
