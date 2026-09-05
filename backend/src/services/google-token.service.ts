import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';
import { config } from '../config/env.js';

const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
const allowedIssuers = new Set(['https://accounts.google.com', 'accounts.google.com']);

export type VerifiedGoogleIdentity = {
  subject: string;
  email: string;
  displayName: string;
  photoUrl: string | null;
};

export async function verifyGoogleIdentityToken(identityToken: string): Promise<VerifiedGoogleIdentity> {
  const { payload } = await jwtVerify(identityToken, googleKeys, {
    audience: config.googleWebClientId,
    algorithms: ['RS256'],
  });

  if (!payload.iss || !allowedIssuers.has(payload.iss)) throw new Error('Invalid Google issuer');
  if (payload.email_verified !== true) throw new Error('Google email is not verified');

  const subject = stringClaim(payload, 'sub');
  const email = stringClaim(payload, 'email');
  const displayName = stringClaim(payload, 'name', email.split('@')[0]);
  const photoUrl = typeof payload.picture === 'string' ? payload.picture : null;
  return { subject, email, displayName, photoUrl };
}

function stringClaim(payload: JWTPayload, key: string, fallback?: string): string {
  const value = payload[key];
  if (typeof value === 'string' && value.length > 0) return value;
  if (fallback !== undefined) return fallback;
  throw new Error(`Missing Google claim: ${key}`);
}
