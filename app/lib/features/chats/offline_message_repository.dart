import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/local_message_database.dart';
import '../../core/network/api_client.dart';

class OfflineMessage {
  const OfflineMessage({required this.id, required this.conversationId, required this.senderId, required this.body, required this.createdAt, this.expiresAt, this.deletedAt, required this.state, this.clientMessageId, this.serverId});
  final String id, conversationId, senderId, body, state;
  final DateTime createdAt;
  final DateTime? expiresAt, deletedAt;
  final String? clientMessageId, serverId;
}

class OfflineMessageRepository {
  OfflineMessageRepository({required this.api, FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final ApiClient api;
  final FlutterSecureStorage _storage;
  final _crypto = AesGcm.with256bits();
  static const _keyName = 'sds.local_message_key';
  String _cursorName(String conversationId) => 'sds.message_sync_cursor.$conversationId';

  Future<SecretKey> _key() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final key = await _crypto.newSecretKey();
      encoded = base64UrlEncode(await key.extractBytes());
      await _storage.write(key: _keyName, value: encoded);
    }
    return SecretKey(base64Url.decode(encoded));
  }

  String _id() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  Future<void> _store(Database db, {required String id, required String conversationId, required String senderId, required String body, required DateTime createdAt, String? clientMessageId, String state = 'pending', String? serverId, DateTime? expiresAt, DateTime? deletedAt}) async {
    final box = await _crypto.encrypt(utf8.encode(body), secretKey: await _key());
    await db.insert('messages', {
      'id': id, 'conversation_id': conversationId, 'sender_id': senderId,
      'ciphertext': base64UrlEncode(box.cipherText), 'nonce': base64UrlEncode(box.nonce), 'mac': base64UrlEncode(box.mac.bytes),
      'created_at': createdAt.toIso8601String(), 'expires_at': expiresAt?.toIso8601String(), 'deleted_at': deletedAt?.toIso8601String(),
      'client_message_id': clientMessageId, 'sync_state': state, 'server_id': serverId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<OfflineMessage> sendOrQueue({required String conversationId, required String senderId, required String body, int? expiresInSeconds}) async {
    final db = await LocalMessageDatabase.instance.database;
    final clientId = _id();
    final created = DateTime.now().toUtc();
    final expires = expiresInSeconds == null ? null : created.add(Duration(seconds: expiresInSeconds));
    await _store(db, id: clientId, conversationId: conversationId, senderId: senderId, body: body, createdAt: created, clientMessageId: clientId, expiresAt: expires);
    try {
      final response = await api.post('/api/v1/messages/$conversationId', authenticated: true, body: {'body': body, if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds, 'clientMessageId': clientId});
      await db.update('messages', {'sync_state': 'sent', 'server_id': response['id']}, where: 'id = ?', whereArgs: [clientId]);
    } catch (_) {}
    return (await listConversation(conversationId)).firstWhere((m) => m.clientMessageId == clientId);
  }

  Future<int> flushPending() async {
    final db = await LocalMessageDatabase.instance.database;
    final rows = await db.query('messages', where: 'sync_state = ?', whereArgs: ['pending'], orderBy: 'created_at ASC', limit: 100);
    var sent = 0;
    for (final row in rows) {
      try {
        final body = await _decrypt(row);
        final expires = row['expires_at'] as String?;
        final response = await api.post('/api/v1/messages/${row['conversation_id']}', authenticated: true, body: {'body': body, if (expires != null) 'expiresInSeconds': DateTime.parse(expires).difference(DateTime.parse(row['created_at'] as String)).inSeconds.clamp(0, 30 * 24 * 60 * 60), 'clientMessageId': row['client_message_id']});
        await db.update('messages', {'sync_state': 'sent', 'server_id': response['id']}, where: 'id = ?', whereArgs: [row['id']]);
        sent++;
      } catch (_) { break; }
    }
    return sent;
  }

  Future<String?> syncConversation(String conversationId) async {
    var cursor = await _storage.read(key: _cursorName(conversationId));
    for (;;) {
      final response = await api.get('/api/v1/messages/$conversationId/sync?limit=100${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}', authenticated: true);
      final messages = (response['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      final db = await LocalMessageDatabase.instance.database;
      for (final m in messages) {
        if (m['body'] == null) {
          await db.update('messages', {'deleted_at': m['deletedAt'], 'sync_state': 'synced'}, where: 'server_id = ? OR id = ?', whereArgs: [m['id'], m['clientMessageId'] ?? m['id']]);
          continue;
        }
        final clientId = m['clientMessageId'] as String?;
        final local = clientId == null ? null : await db.query('messages', where: 'client_message_id = ?', whereArgs: [clientId], limit: 1);
        if (local != null && local.isNotEmpty) {
          await db.update('messages', {'server_id': m['id'], 'sync_state': 'synced'}, where: 'id = ?', whereArgs: [local.first['id']]);
        } else {
          await _store(db, id: _id(), conversationId: m['conversationId'], senderId: m['senderId'], body: m['body'], createdAt: DateTime.parse(m['createdAt']).toUtc(), clientMessageId: clientId, state: 'synced', serverId: m['id'], expiresAt: m['expiresAt'] == null ? null : DateTime.parse(m['expiresAt']).toUtc());
        }
      }
      final next = response['nextCursor'] as String?;
      if (next == null) break;
      cursor = next;
      await _storage.write(key: _cursorName(conversationId), value: cursor);
      if (messages.isEmpty) break;
    }
    return cursor;
  }

  Future<String?> sync() async {
    final db = await LocalMessageDatabase.instance.database;
    final conversations = await db.rawQuery('SELECT DISTINCT conversation_id FROM messages');
    String? last;
    for (final row in conversations) {
      last = await syncConversation(row['conversation_id'] as String);
    }
    return last;
  }

  Future<String> _decrypt(Map<String, Object?> row) async {
    final box = SecretBox(base64Url.decode(row['ciphertext'] as String), nonce: base64Url.decode(row['nonce'] as String), mac: Mac(base64Url.decode(row['mac'] as String)));
    return utf8.decode(await _crypto.decrypt(box, secretKey: await _key()));
  }

  Future<List<OfflineMessage>> listConversation(String conversationId) async {
    final db = await LocalMessageDatabase.instance.database;
    final rows = await db.query('messages', where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'created_at ASC');
    final result = <OfflineMessage>[];
    for (final row in rows) {
      result.add(OfflineMessage(id: row['id'] as String, conversationId: row['conversation_id'] as String, senderId: row['sender_id'] as String, body: await _decrypt(row), createdAt: DateTime.parse(row['created_at'] as String), expiresAt: row['expires_at'] == null ? null : DateTime.parse(row['expires_at'] as String), deletedAt: row['deleted_at'] == null ? null : DateTime.parse(row['deleted_at'] as String), state: row['sync_state'] as String, clientMessageId: row['client_message_id'] as String?, serverId: row['server_id'] as String?));
    }
    return result;
  }
}
