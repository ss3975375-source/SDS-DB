import 'package:sqflite/sqflite.dart';

class LocalMessageDatabase {
  LocalMessageDatabase._();
  static final LocalMessageDatabase instance = LocalMessageDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/sds_messages.sqlite';
    _db = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          ciphertext TEXT NOT NULL,
          nonce TEXT NOT NULL,
          mac TEXT NOT NULL,
          created_at TEXT NOT NULL,
          expires_at TEXT,
          deleted_at TEXT,
          client_message_id TEXT,
          sync_state TEXT NOT NULL,
          server_id TEXT
        )
      ''');
      await db.execute('CREATE INDEX messages_conversation_created_idx ON messages(conversation_id, created_at)');
      await db.execute('CREATE INDEX messages_sync_state_idx ON messages(sync_state, created_at)');
    });
    return _db!;
  }

  Future<void> close() async { await _db?.close(); _db = null; }
}
