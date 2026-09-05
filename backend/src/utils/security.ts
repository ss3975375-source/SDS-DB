const SENSITIVE_KEYS = /(authorization|cookie|token|password|secret|private.?key|refresh|access.?token|identity.?token|database.?url|connection.?string|fcm)/i;

export function redactSensitive(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redactSensitive);
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      out[key] = SENSITIVE_KEYS.test(key) ? '[REDACTED]' : redactSensitive(child);
    }
    return out;
  }
  return typeof value === 'string' && SENSITIVE_KEYS.test(value) ? '[REDACTED]' : value;
}

export function isProductionSafeCorsOrigin(origin: string): boolean {
  return origin.split(',').map((v) => v.trim()).filter(Boolean).every((v) => {
    try {
      const u = new URL(v);
      return u.protocol === 'https:' && !['localhost', '127.0.0.1', '::1'].includes(u.hostname);
    } catch {
      return false;
    }
  });
}
