import crypto from 'node:crypto';
import { config } from '../config/env.js';

function key(): Buffer {
  if (!config.pushTokenEncryptionKey) throw new Error('PUSH_TOKEN_ENCRYPTION_KEY_MISSING');
  const value = Buffer.from(config.pushTokenEncryptionKey, 'base64');
  if (value.length !== 32) throw new Error('PUSH_TOKEN_ENCRYPTION_KEY_INVALID');
  return value;
}

export function encryptPushToken(token: string): { ciphertext: string; nonce: string; tag: string } {
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key(), nonce);
  const ciphertext = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
  return { ciphertext: ciphertext.toString('base64'), nonce: nonce.toString('base64'), tag: cipher.getAuthTag().toString('base64') };
}

export function decryptPushToken(ciphertext: string, nonce: string, tag: string): string {
  const decipher = crypto.createDecipheriv('aes-256-gcm', key(), Buffer.from(nonce, 'base64'));
  decipher.setAuthTag(Buffer.from(tag, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(ciphertext, 'base64')), decipher.final()]).toString('utf8');
}
