import { S3Client } from '@aws-sdk/client-s3';
import { config } from './env.js';

const clientConfig = {
  region: config.storageRegion,
  forcePathStyle: config.storageForcePathStyle,
  credentials: { accessKeyId: config.storageAccessKey, secretAccessKey: config.storageSecretKey },
  ...(config.storageEndpoint ? { endpoint: config.storageEndpoint } : {}),
};

export const storageClient = new S3Client(clientConfig);
export const storageBucket = config.storageBucket;
