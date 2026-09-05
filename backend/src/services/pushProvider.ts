import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { config } from '../config/env.js';

export type PushPayload = { title: string; body: string; data: Record<string,string> };

let messaging: Messaging | null = null;

function getMessagingClient(): Messaging {
  if (!config.pushProviderEnabled) throw new Error('PUSH_PROVIDER_DISABLED');
  if (!config.firebaseProjectId || !config.firebaseClientEmail || !config.firebasePrivateKey) throw new Error('FIREBASE_CONFIG_MISSING');
  if (getApps().length === 0) initializeApp({ credential: cert({ projectId: config.firebaseProjectId, clientEmail: config.firebaseClientEmail, privateKey: config.firebasePrivateKey }) });
  messaging ??= getMessaging();
  return messaging;
}

export async function sendFcm(token: string, payload: PushPayload): Promise<{ messageId: string }> {
  const id = await getMessagingClient().send({ token, notification: { title: payload.title, body: payload.body }, data: payload.data, android: { priority: 'high', notification: { channelId: 'sds_messages' } } });
  return { messageId: id };
}

export function isInvalidFcmTokenError(error: unknown): boolean {
  const code = typeof error === 'object' && error && 'code' in error ? String((error as {code?:unknown}).code) : '';
  return ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(code);
}
