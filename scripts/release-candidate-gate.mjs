import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const checks = [];
function check(name, fn) {
  try { fn(); checks.push(`${name}: PASS`); }
  catch (error) { checks.push(`${name}: FAIL — ${error.message}`); }
}

check('security gate', () => execFileSync(process.execPath, [join(root, 'backend/scripts/security-gate.mjs')], { stdio: 'pipe' }));
check('release config script syntax', () => execFileSync(process.execPath, ['--check', join(root, 'scripts/check-release-config.mjs')], { stdio: 'pipe' }));
check('release script executable', () => {
  if (!existsSync(join(root, 'scripts/build-release.sh'))) throw new Error('scripts/build-release.sh missing');
});
check('no local release credentials', () => {
  if (existsSync(join(root, 'android/key.properties'))) throw new Error('local key.properties must not be packaged');
  if (existsSync(join(root, 'android/app/google-services.json'))) throw new Error('local google-services.json must not be packaged');
});
check('version is release candidate', () => {
  const pubspec = readFileSync(join(root, 'app/pubspec.yaml'), 'utf8');
  if (!/^version:\s*1\.0\.0\+30\s*$/m.test(pubspec)) throw new Error('unexpected app version');
});

console.log(checks.join('\n'));
if (checks.some((line) => line.includes(': FAIL'))) process.exit(1);
console.log('RELEASE CANDIDATE GATE PASSED.');
