import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  GOOGLE_WEB_CLIENT_ID: z.string().min(1),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  STORAGE_REGION: z.string().default('us-east-1'),
  STORAGE_BUCKET: z.string().min(1).default('sds-db-private'),
  STORAGE_ENDPOINT: z.string().url().optional(),
  STORAGE_FORCE_PATH_STYLE: z.coerce.boolean().default(false),
  STORAGE_ACCESS_KEY: z.string().min(1),
  STORAGE_SECRET_KEY: z.string().min(1),
  FILE_MAX_BYTES: z.coerce.bigint().positive().default(5368709120n),
  UPLOAD_URL_TTL_SECONDS: z.coerce.number().int().min(60).max(900).default(600),
  PUSH_PROVIDER_ENABLED: z.coerce.boolean().default(false),
  PUSH_TOKEN_ENCRYPTION_KEY: z.string().optional(),
  FIREBASE_PROJECT_ID: z.string().optional(),
  FIREBASE_CLIENT_EMAIL: z.string().email().optional(),
  FIREBASE_PRIVATE_KEY: z.string().optional(),
});

const parsed = schema.parse(process.env);
if (parsed.NODE_ENV === 'production') {
  if (!isProductionSafeCorsOrigin(parsed.CORS_ORIGIN)) throw new Error('CORS_ORIGIN must contain only HTTPS origins in production');
  if (parsed.JWT_SECRET === 'replace-with-at-least-32-random-characters') throw new Error('JWT_SECRET must be replaced in production');
  if (parsed.PUSH_PROVIDER_ENABLED && (!parsed.PUSH_TOKEN_ENCRYPTION_KEY || !parsed.FIREBASE_PROJECT_ID || !parsed.FIREBASE_CLIENT_EMAIL || !parsed.FIREBASE_PRIVATE_KEY)) {
    throw new Error('Push provider credentials are incomplete in production');
  }
}

function isProductionSafeCorsOrigin(origin: string): boolean {
  return origin.split(',').map((v) => v.trim()).filter(Boolean).every((v) => {
    try {
      const u = new URL(v);
      return u.protocol === 'https:' && !['localhost', '127.0.0.1', '::1'].includes(u.hostname);
    } catch { return false; }
  });
}
export const config = {
  nodeEnv: parsed.NODE_ENV,
  port: parsed.PORT,
  corsOrigin: parsed.CORS_ORIGIN,
  databaseUrl: parsed.DATABASE_URL,
  jwtSecret: parsed.JWT_SECRET,
  googleWebClientId: parsed.GOOGLE_WEB_CLIENT_ID,
  accessTokenTtlSeconds: parsed.ACCESS_TOKEN_TTL_SECONDS,
  refreshTokenTtlDays: parsed.REFRESH_TOKEN_TTL_DAYS,
  storageRegion: parsed.STORAGE_REGION,
  storageBucket: parsed.STORAGE_BUCKET,
  storageEndpoint: parsed.STORAGE_ENDPOINT,
  storageForcePathStyle: parsed.STORAGE_FORCE_PATH_STYLE,
  storageAccessKey: parsed.STORAGE_ACCESS_KEY,
  storageSecretKey: parsed.STORAGE_SECRET_KEY,
  fileMaxBytes: parsed.FILE_MAX_BYTES,
  uploadUrlTtlSeconds: parsed.UPLOAD_URL_TTL_SECONDS,
  pushProviderEnabled: parsed.PUSH_PROVIDER_ENABLED,
  pushTokenEncryptionKey: parsed.PUSH_TOKEN_ENCRYPTION_KEY,
  firebaseProjectId: parsed.FIREBASE_PROJECT_ID,
  firebaseClientEmail: parsed.FIREBASE_CLIENT_EMAIL,
  firebasePrivateKey: parsed.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
};
