import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'nma_inventory.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            barcode TEXT NOT NULL,
            product_name TEXT,
            scanned_qty INTEGER DEFAULT 1,
            scanned_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  static Future<int> insertScan(Map<String, dynamic> scan) async {
    final database = await db;
    return database.insert('pending_scans', scan);
  }

  static Future<List<Map<String, dynamic>>> getPendingScans(
    String sessionId,
  ) async {
    final database = await db;
    return database.query(
      'pending_scans',
      where: 'session_id = ? AND synced = 0',
      whereArgs: [sessionId],
      orderBy: 'scanned_at DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getAllPending() async {
    final database = await db;
    return database.query('pending_scans', where: 'synced = 0');
  }

  static Future<void> markSynced(int localId) async {
    final database = await db;
    await database.update(
      'pending_scans',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  static Future<void> deleteScan(int localId) async {
    final database = await db;
    await database.delete(
      'pending_scans',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}
