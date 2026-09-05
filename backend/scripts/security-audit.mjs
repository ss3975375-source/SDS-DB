import { promises as fs } from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('.', import.meta.url).pathname, '..', '..');
const ignored = new Set(['node_modules', '.git', 'build', 'coverage', 'dist']);
const allowedExample = new Set(['.env.example']);
const findings = [];
const patterns = [
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, 'private key material'],
  [/(aws_secret_access_key|private_key|client_secret)\s*[:=]\s*['"][^'"\n]{12,}/i, 'hard-coded secret'],
  [/postgres(?:ql)?:\/\/[^\s"']+:[^\s"'@]+@/i, 'database password in connection string'],
  [/(AIza[0-9A-Za-z_-]{30,})/, 'Google API key-like value'],
];

async function walk(dir) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) await walk(full);
    else {
      const rel = path.relative(root, full);
      if (allowedExample.has(rel)) continue;
      let text;
      try { text = await fs.readFile(full, 'utf8'); } catch { continue; }
      for (const [regex, label] of patterns) {
        if (regex.test(text)) findings.push(`${rel}: ${label}`);
      }
    }
  }
}

await walk(root);
if (findings.length) {
  console.error('SECURITY AUDIT FAILED');
  for (const finding of findings) console.error(`- ${finding}`);
  process.exit(1);
}
console.log('SECURITY AUDIT PASSED: no configured high-confidence hard-coded secret patterns found.');
