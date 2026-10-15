/**
 * During the account-deletion grace period, the existing session may only
 * inspect deletion status or cancel the pending deletion. All other API access
 * is blocked until deletion is cancelled.
 */
export function isAllowedDuringAccountDeletion(method: string, url: string): boolean {
  const path = url.split('?')[0];
  return path === '/api/v1/account/deletion'
    && (method.toUpperCase() === 'GET' || method.toUpperCase() === 'DELETE');
}
