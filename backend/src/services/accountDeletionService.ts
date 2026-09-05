export type DeletionPlan = {
  revokeSessions: boolean;
  deleteDevices: boolean;
  deleteContacts: boolean;
  deleteBlocks: boolean;
  deleteNotifications: boolean;
  deleteFeelIt: boolean;
  deletePrivateFiles: boolean;
  deleteProfile: boolean;
  handleMessagesAccordingToRetentionPolicy: boolean;
  retainMinimumLegalOrAbuseRecordsWhenRequired: boolean;
};

export const DEFAULT_DELETION_PLAN: DeletionPlan = {
  revokeSessions: true,
  deleteDevices: true,
  deleteContacts: true,
  deleteBlocks: true,
  deleteNotifications: true,
  deleteFeelIt: true,
  deletePrivateFiles: true,
  deleteProfile: true,
  handleMessagesAccordingToRetentionPolicy: true,
  retainMinimumLegalOrAbuseRecordsWhenRequired: true,
};

/**
 * Account deletion must be a backend transaction/job, not a client-only
 * operation. Private objects are deleted asynchronously after database
 * references are safely handled.
 */
export function normalizeDeletionRequest(confirm: boolean): { confirmed: boolean } {
  return { confirmed: confirm === true };
}
