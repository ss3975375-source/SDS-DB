import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('../..', import.meta.url).pathname);
const failures = [];
const files = [];

function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    if (['node_modules', '.git', 'dist', 'build', '.dart_tool'].includes(name)) continue;
    const file = path.join(dir, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) walk(file);
    else files.push(file);
  }
}

walk(root);
for (const file of files) {
  let text;
  try { text = fs.readFileSync(file, 'utf8'); } catch { continue; }
  if (/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text)) failures.push(`private key material in ${file}`);
  if (/postgres(?:ql)?:\/\/[^\s"']+:[^\s"'@]+@/i.test(text) && !file.endsWith('.env.example') && !file.includes('.github/workflows/')) {
    failures.push(`database credential in ${file}`);
  }
  if (/http:\/\/(?!localhost|127\.0\.0\.1)/i.test(text) && /\.(ts|dart|kt|kts)$/.test(file) && !file.includes('securityAudit.test.ts') && !file.includes('env.ts') && !file.endsWith('app_config.dart')) {
    failures.push(`possible cleartext URL in ${file}`);
  }
}

const server = fs.readFileSync(path.join(root, 'backend/src/server.ts'), 'utf8');
if (!server.includes('app.register(helmet')) failures.push('Helmet is not registered');
if (!server.includes('app.register(cors')) failures.push('CORS is not registered');
if (!server.includes('app.register(rateLimit')) failures.push('rate limiting is not registered');

const auth = fs.readFileSync(path.join(root, 'backend/src/middleware/auth.ts'), 'utf8');
if (!auth.includes('jwtVerify')) failures.push('JWT verification missing');

if (failures.length) {
  console.error(failures.map((failure) => `FAIL: ${failure}`).join('\n'));
  process.exit(1);
}
console.log('SECURITY GATE PASSED: no configured high-confidence violations found.');
