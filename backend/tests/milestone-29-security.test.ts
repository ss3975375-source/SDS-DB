import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('security plugins are registered before application routes', () => {
  const s = fs.readFileSync(new URL('../src/server.ts', import.meta.url), 'utf8');
  assert.ok(s.indexOf('app.register(helmet') < s.indexOf('registerAccountRoutes'));
  assert.ok(s.indexOf('app.register(cors') < s.indexOf('registerAccountRoutes'));
  assert.ok(s.indexOf('app.register(rateLimit') < s.indexOf('registerAccountRoutes'));
});

test('authentication middleware verifies access JWTs', () => {
  const s = fs.readFileSync(new URL('../src/middleware/auth.ts', import.meta.url), 'utf8');
  assert.match(s, /jwtVerify/);
  assert.match(s, /algorithms:\s*\['HS256'\]/);
});
