import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const errors = [];
const key = join(root, 'android', 'key.properties');
const firebase = join(root, 'android', 'app', 'google-services.json');

if (!existsSync(key)) errors.push('Missing android/key.properties');
if (!existsSync(firebase)) errors.push('Missing android/app/google-services.json');
if (existsSync(key)) {
  const text = readFileSync(key, 'utf8');
  for (const name of ['storePassword', 'keyPassword', 'keyAlias', 'storeFile']) {
    if (!new RegExp(`^${name}\\s*=\\s*.+$`, 'm').test(text)) errors.push(`Missing ${name} in android/key.properties`);
  }
  if (/REPLACE_ME|change-me|password123/i.test(text)) errors.push('Placeholder release credential detected');
}
if (errors.length) {
  console.error(errors.map(e => `ERROR: ${e}`).join('\n'));
  process.exit(1);
}
console.log('Release configuration looks structurally complete. Secrets were not printed.');
