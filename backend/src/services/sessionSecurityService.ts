import { createHash, randomBytes } from 'node:crypto';

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function generateRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

export type SessionView = {
  id: string;
  deviceId: string | null;
  deviceName: string | null;
  platform: string | null;
  appVersion: string | null;
  createdAt: string;
  lastSeenAt: string | null;
  current: boolean;
  revokedAt: string | null;
};

/**
 * Session metadata deliberately avoids advertising precise location,
 * hardware identifiers, IP addresses, or other unnecessary device data.
 */
export function toSessionView(
  session: {
    id: string;
    device_id?: string | null;
    device_name?: string | null;
    platform?: string | null;
    app_version?: string | null;
    created_at: Date | string;
    last_seen_at?: Date | string | null;
    revoked_at?: Date | string | null;
  },
  currentSessionId: string,
): SessionView {
  return {
    id: session.id,
    deviceId: session.device_id ?? null,
    deviceName: session.device_name ?? null,
    platform: session.platform ?? null,
    appVersion: session.app_version ?? null,
    createdAt: new Date(session.created_at).toISOString(),
    lastSeenAt: session.last_seen_at
      ? new Date(session.last_seen_at).toISOString()
      : null,
    current: session.id === currentSessionId,
    revokedAt: session.revoked_at
      ? new Date(session.revoked_at).toISOString()
      : null,
  };
}
