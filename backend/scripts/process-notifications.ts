import { processNotificationOutbox } from '../src/services/notificationService.js';
const count=await processNotificationOutbox(100);
console.log(`processed ${count} notification job(s)`);
