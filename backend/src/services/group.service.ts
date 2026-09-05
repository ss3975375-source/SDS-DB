import { createHash, randomBytes } from 'node:crypto';
import { pool } from '../db/pool.js';

const MAX_MEMBERS = 500;
const MAX_INVITE_TTL_HOURS = 168;

function hashInviteToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function normalizeName(name: string): string {
  return name.trim().replace(/\s+/g, ' ');
}

async function requireMember(userId: string, conversationId: string, client = pool) {
  const result = await client.query(
    `SELECT cm.role, g.name
       FROM conversation_members cm
       JOIN groups g ON g.conversation_id = cm.conversation_id
      WHERE cm.conversation_id = $1 AND cm.user_id = $2 AND cm.left_at IS NULL`,
    [conversationId, userId],
  );
  if (!result.rows[0]) throw new Error('FORBIDDEN');
  return result.rows[0] as { role: 'member' | 'moderator' | 'admin'; name: string };
}

async function requireAdmin(userId: string, conversationId: string, client = pool) {
  const member = await requireMember(userId, conversationId, client);
  if (member.role !== 'admin') throw new Error('ADMIN_REQUIRED');
  return member;
}

export async function createGroup(userId: string, name: string, memberIds: string[]) {
  const groupName = normalizeName(name);
  if (groupName.length < 1 || groupName.length > 100) throw new Error('INVALID_NAME');
  const ids = [...new Set([userId, ...memberIds])];
  if (ids.length > MAX_MEMBERS) throw new Error('TOO_MANY_MEMBERS');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const users = await client.query(
      `SELECT id FROM users WHERE id = ANY($1::uuid[]) AND deleted_at IS NULL`, [ids],
    );
    if (users.rowCount !== ids.length) throw new Error('USER_NOT_FOUND');
    const conversation = await client.query(`INSERT INTO conversations(kind) VALUES ('group') RETURNING id`);
    const conversationId = conversation.rows[0].id as string;
    await client.query(
      `INSERT INTO groups(conversation_id, name, created_by) VALUES ($1,$2,$3)`,
      [conversationId, groupName, userId],
    );
    for (const id of ids) {
      await client.query(
        `INSERT INTO conversation_members(conversation_id,user_id,role) VALUES ($1,$2,$3)`,
        [conversationId, id, id === userId ? 'admin' : 'member'],
      );
    }
    await client.query('COMMIT');
    return getGroup(userId, conversationId);
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally { client.release(); }
}

export async function listGroups(userId: string) {
  const result = await pool.query(
    `SELECT c.id AS conversation_id, g.name, g.created_by, g.created_at,
            cm.role, COUNT(active.user_id)::int AS member_count
       FROM conversations c
       JOIN groups g ON g.conversation_id = c.id
       JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = $1 AND cm.left_at IS NULL
       LEFT JOIN conversation_members active ON active.conversation_id = c.id AND active.left_at IS NULL
      WHERE c.deleted_at IS NULL
      GROUP BY c.id, g.name, g.created_by, g.created_at, cm.role
      ORDER BY g.created_at DESC`, [userId],
  );
  return result.rows;
}

export async function getGroup(userId: string, conversationId: string) {
  await requireMember(userId, conversationId);
  const result = await pool.query(
    `SELECT c.id AS conversation_id, g.name, g.created_by, g.created_at,
            json_agg(json_build_object('userId',u.id,'displayName',u.display_name,'photoUrl',u.photo_url,'role',cm.role,'joinedAt',cm.joined_at)
              ORDER BY cm.joined_at) AS members
       FROM conversations c
       JOIN groups g ON g.conversation_id = c.id
       JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.left_at IS NULL
       JOIN users u ON u.id = cm.user_id
      WHERE c.id = $1 AND c.kind = 'group' AND c.deleted_at IS NULL
      GROUP BY c.id, g.name, g.created_by, g.created_at`, [conversationId],
  );
  if (!result.rows[0]) throw new Error('NOT_FOUND');
  return result.rows[0];
}

export async function updateGroupName(userId: string, conversationId: string, name: string) {
  await requireAdmin(userId, conversationId);
  const normalized = normalizeName(name);
  if (!normalized || normalized.length > 100) throw new Error('INVALID_NAME');
  const result = await pool.query(
    `UPDATE groups SET name=$1 WHERE conversation_id=$2 RETURNING conversation_id,name,created_by,created_at`,
    [normalized, conversationId],
  );
  return result.rows[0];
}

export async function addMembers(userId: string, conversationId: string, memberIds: string[]) {
  await requireAdmin(userId, conversationId);
  const ids = [...new Set(memberIds)];
  if (!ids.length) throw new Error('INVALID_MEMBERS');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const count = await client.query(`SELECT count(*)::int AS n FROM conversation_members WHERE conversation_id=$1 AND left_at IS NULL`, [conversationId]);
    if (Number(count.rows[0].n) + ids.length > MAX_MEMBERS) throw new Error('TOO_MANY_MEMBERS');
    const users = await client.query(`SELECT id FROM users WHERE id=ANY($1::uuid[]) AND deleted_at IS NULL`, [ids]);
    if (users.rowCount !== ids.length) throw new Error('USER_NOT_FOUND');
    for (const id of ids) {
      await client.query(
        `INSERT INTO conversation_members(conversation_id,user_id,role) VALUES($1,$2,'member')
         ON CONFLICT (conversation_id,user_id) DO UPDATE SET left_at=NULL`, [conversationId,id]);
    }
    await client.query('COMMIT');
  } catch(e) { await client.query('ROLLBACK'); throw e; }
  finally { client.release(); }
  return getGroup(userId, conversationId);
}

export async function removeMember(actorId: string, conversationId: string, targetId: string) {
  const actor = await requireAdmin(actorId, conversationId);
  const target = await pool.query(`SELECT role FROM conversation_members WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [conversationId,targetId]);
  if (!target.rows[0]) throw new Error('NOT_FOUND');
  if (target.rows[0].role === 'admin' && actorId !== targetId) throw new Error('ADMIN_REQUIRED');
  if (targetId === actorId) throw new Error('SELF_REMOVE_FORBIDDEN');
  await pool.query(`UPDATE conversation_members SET left_at=now() WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [conversationId,targetId]);
}

export async function leaveGroup(userId: string, conversationId: string) {
  await requireMember(userId, conversationId);
  const admins = await pool.query(`SELECT count(*)::int AS n FROM conversation_members WHERE conversation_id=$1 AND role='admin' AND left_at IS NULL`, [conversationId]);
  const me = await pool.query(`SELECT role FROM conversation_members WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [conversationId,userId]);
  if (me.rows[0]?.role === 'admin' && Number(admins.rows[0].n) <= 1) throw new Error('LAST_ADMIN');
  await pool.query(`UPDATE conversation_members SET left_at=now() WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [conversationId,userId]);
}

export async function setMemberRole(actorId: string, conversationId: string, targetId: string, role: 'member'|'moderator'|'admin') {
  await requireAdmin(actorId, conversationId);
  const target = await pool.query(`SELECT role FROM conversation_members WHERE conversation_id=$1 AND user_id=$2 AND left_at IS NULL`, [conversationId,targetId]);
  if (!target.rows[0]) throw new Error('NOT_FOUND');
  if (targetId === actorId && role !== 'admin') throw new Error('SELF_DEMOTION_FORBIDDEN');
  await pool.query(`UPDATE conversation_members SET role=$1 WHERE conversation_id=$2 AND user_id=$3 AND left_at IS NULL`, [role,conversationId,targetId]);
}

export async function createInvite(userId: string, conversationId: string, ttlHours = 24, maxUses = 1) {
  await requireAdmin(userId, conversationId);
  if (!Number.isInteger(ttlHours) || ttlHours < 1 || ttlHours > MAX_INVITE_TTL_HOURS) throw new Error('INVALID_TTL');
  if (!Number.isInteger(maxUses) || maxUses < 1 || maxUses > 1000) throw new Error('INVALID_MAX_USES');
  const token = randomBytes(32).toString('base64url');
  const result = await pool.query(
    `INSERT INTO group_invites(conversation_id,token_hash,created_by,expires_at,max_uses)
     VALUES($1,$2,$3,now()+($4::int * interval '1 hour'),$5)
     RETURNING id,expires_at,max_uses`,
    [conversationId, hashInviteToken(token), userId, ttlHours, maxUses],
  );
  return { inviteId: result.rows[0].id, token, expiresAt: result.rows[0].expires_at, maxUses: result.rows[0].max_uses };
}

export async function revokeInvite(userId: string, inviteId: string) {
  const result = await pool.query(
    `UPDATE group_invites gi SET revoked_at=now()
       WHERE gi.id=$1 AND gi.revoked_at IS NULL
         AND EXISTS (SELECT 1 FROM conversation_members cm WHERE cm.conversation_id=gi.conversation_id AND cm.user_id=$2 AND cm.role='admin' AND cm.left_at IS NULL)
       RETURNING gi.id`, [inviteId,userId]);
  if (!result.rows[0]) throw new Error('NOT_FOUND');
}

export async function joinByInvite(userId: string, token: string) {
  const tokenHash = hashInviteToken(token);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const invite = await client.query(
      `SELECT gi.id,gi.conversation_id,gi.max_uses,gi.use_count
         FROM group_invites gi JOIN conversations c ON c.id=gi.conversation_id
        WHERE gi.token_hash=$1 AND gi.revoked_at IS NULL AND gi.expires_at>now() AND gi.use_count<gi.max_uses AND c.deleted_at IS NULL
        FOR UPDATE`, [tokenHash]);
    if (!invite.rows[0]) throw new Error('INVALID_INVITE');
    const conversationId = invite.rows[0].conversation_id as string;
    const existing = await client.query(`SELECT left_at FROM conversation_members WHERE conversation_id=$1 AND user_id=$2`, [conversationId,userId]);
    await client.query(
      `INSERT INTO conversation_members(conversation_id,user_id,role) VALUES($1,$2,'member')
       ON CONFLICT(conversation_id,user_id) DO UPDATE SET left_at=NULL`, [conversationId,userId]);
    if (existing.rows[0]?.left_at === null) {
      await client.query('COMMIT');
      return getGroup(userId, conversationId);
    }
    const count = await client.query(`SELECT count(*)::int AS n FROM conversation_members WHERE conversation_id=$1 AND left_at IS NULL`, [conversationId]);
    if (Number(count.rows[0].n) > MAX_MEMBERS) throw new Error('TOO_MANY_MEMBERS');
    await client.query(`UPDATE group_invites SET use_count=use_count+1 WHERE id=$1`, [invite.rows[0].id]);
    await client.query('COMMIT');
    return getGroup(userId, conversationId);
  } catch(e) { await client.query('ROLLBACK'); throw e; }
  finally { client.release(); }
}
