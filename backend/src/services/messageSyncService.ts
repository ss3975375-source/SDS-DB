import { pool } from '../db/pool.js';

export type MessageCursor = { createdAt: string; id: string };

export function encodeMessageCursor(cursor: MessageCursor): string {
  return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
}

export function decodeMessageCursor(value: string | undefined): MessageCursor | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as Partial<MessageCursor>;
    if (typeof parsed.createdAt !== 'string' || typeof parsed.id !== 'string') return null;
    return parsed as MessageCursor;
  } catch {
    return null;
  }
}

export async function syncMessages(userId: string, cursor: MessageCursor | null, limit: number, conversationId?: string) {
  const args: unknown[] = [userId];
  let cursorWhere = '';
  let conversationWhere = '';
  if (conversationId) { args.push(conversationId); conversationWhere = `AND m.conversation_id=$${args.length}`; }
  if (cursor) {
    const base = args.length + 1;
    args.push(cursor.createdAt, cursor.id);
    cursorWhere = `AND (m.created_at, m.id) > ($${base}::timestamptz, $${base + 1}::uuid)`;
  }
  args.push(Math.min(Math.max(limit, 1), 100));
  const limitParam = `$${args.length}`;
  const result = await pool.query(
    `SELECT m.id,m.conversation_id,m.sender_id,m.body,m.created_at,m.edited_at,m.expires_at,m.deleted_at,m.client_message_id
       FROM messages m
       JOIN conversation_members cm ON cm.conversation_id=m.conversation_id
                                    AND cm.user_id=$1
                                    AND cm.left_at IS NULL
       JOIN conversations c ON c.id=m.conversation_id AND c.deleted_at IS NULL
      WHERE m.created_at IS NOT NULL ${conversationWhere} ${cursorWhere}
      ORDER BY m.created_at ASC,m.id ASC
      LIMIT ${limitParam}`,
    args,
  );

  const rows = result.rows.map((row) => {
    const expired = row.expires_at && new Date(row.expires_at).getTime() <= Date.now();
    return {
      id: row.id,
      conversationId: row.conversation_id,
      senderId: row.sender_id,
      body: row.deleted_at || expired ? null : row.body,
      createdAt: row.created_at,
      editedAt: row.edited_at,
      expiresAt: row.expires_at,
      deletedAt: row.deleted_at ?? (expired ? row.expires_at : null),
      clientMessageId: row.client_message_id,
    };
  });

  const last = result.rows.at(-1);
  return {
    messages: rows,
    nextCursor: last
      ? encodeMessageCursor({ createdAt: new Date(last.created_at).toISOString(), id: last.id })
      : null,
  };
}
