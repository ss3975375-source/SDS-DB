import { S3Client } from '@aws-sdk/client-s3';
import { config } from './env.js';

export const storageClient = new S3Client({
  region: config.storageRegion,
  endpoint: config.storageEndpoint || undefined,
  forcePathStyle: config.storageForcePathStyle,
  credentials: { accessKeyId: config.storageAccessKey, secretAccessKey: config.storageSecretKey },
});
export const storageBucket = config.storageBucket;
