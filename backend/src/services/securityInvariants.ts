export function isSafeNotificationBody(body: string): boolean {
  return body.length <= 512 &&
    !body.includes('Authorization: Bearer') &&
    !body.includes('refresh_token') &&
    !body.includes('access_token');
}

export function isValidPagination(limit: number | undefined, cursor: string | undefined): boolean {
  if (limit !== undefined && (!Number.isInteger(limit) || limit < 1 || limit > 100)) return false;
  if (cursor !== undefined && (cursor.length < 1 || cursor.length > 512)) return false;
  return true;
}

export function isValidFileSize(bytes: number, maxBytes: number): boolean {
  return Number.isSafeInteger(bytes) && bytes > 0 && bytes <= maxBytes;
}
