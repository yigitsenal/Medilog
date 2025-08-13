import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';
import '../models/medication_stock.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medilog.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        times TEXT NOT NULL,
        stomachCondition TEXT NOT NULL,
        notes TEXT,
        startDate INTEGER,
        endDate INTEGER,
        isActive INTEGER NOT NULL DEFAULT 1,
        stock INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationId INTEGER NOT NULL,
        scheduledTime INTEGER NOT NULL,
        takenTime INTEGER,
        isTaken INTEGER NOT NULL DEFAULT 0,
        isSkipped INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (medicationId) REFERENCES medications (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_stocks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationId INTEGER NOT NULL,
        currentStock INTEGER NOT NULL DEFAULT 0,
        minimumStock INTEGER NOT NULL DEFAULT 5,
        maximumStock INTEGER NOT NULL DEFAULT 30,
        unit TEXT NOT NULL DEFAULT 'tablet',
        lastUpdated TEXT NOT NULL,
        expiryDate TEXT,
        batchNumber TEXT,
        costPerUnit REAL,
        pharmacy TEXT,
        notes TEXT,
        UNIQUE(medicationId)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medication_stocks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicationId INTEGER NOT NULL,
          currentStock INTEGER NOT NULL DEFAULT 0,
          minimumStock INTEGER NOT NULL DEFAULT 5,
          maximumStock INTEGER NOT NULL DEFAULT 30,
          unit TEXT NOT NULL DEFAULT 'tablet',
          lastUpdated TEXT NOT NULL,
          expiryDate TEXT,
          batchNumber TEXT,
          costPerUnit REAL,
          pharmacy TEXT,
          notes TEXT,
          UNIQUE(medicationId)
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // Add stock column to medications table
      await db.execute('ALTER TABLE medications ADD COLUMN stock INTEGER NOT NULL DEFAULT 0');
    }
    
    if (oldVersion < 4) {
      // Drop and recreate medication_stocks table to ensure all columns exist
      await db.execute('DROP TABLE IF EXISTS medication_stocks');
      await db.execute('''
        CREATE TABLE medication_stocks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicationId INTEGER NOT NULL,
          currentStock INTEGER NOT NULL DEFAULT 0,
          minimumStock INTEGER NOT NULL DEFAULT 5,
          maximumStock INTEGER NOT NULL DEFAULT 30,
          unit TEXT NOT NULL DEFAULT 'tablet',
          lastUpdated TEXT NOT NULL,
          expiryDate TEXT,
          batchNumber TEXT,
          costPerUnit REAL,
          pharmacy TEXT,
          notes TEXT,
          UNIQUE(medicationId)
        )
      ''');
    }
  }

  // Medication CRUD operations
  Future<int> insertMedication(Medication medication) async {
    final db = await database;
    return await db.insert('medications', medication.toMap());
  }

  Future<List<Medication>> getAllMedications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('medications');
    return List.generate(maps.length, (i) {
      return Medication.fromMap(maps[i]);
    });
  }

  Future<List<Medication>> getActiveMedications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medications',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return Medication.fromMap(maps[i]);
    });
  }

  Future<Medication?> getMedication(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Medication.fromMap(maps.first);
  }

  Future<int> updateMedication(Medication medication) async {
    final db = await database;
    return await db.update(
      'medications',
      medication.toMap(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  Future<int> deleteMedication(int id) async {
    final db = await database;

    // İlacı deaktif et (tamamen silmek yerine)
    // Bu sayede geçmiş loglar korunur
    await db.update(
      'medications',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    // İsteğe bağlı: Gelecekteki logları sil (bugünden sonraki)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    await db.delete(
      'medication_logs',
      where:
          'medicationId = ? AND scheduledTime > ? AND isTaken = 0 AND isSkipped = 0',
      whereArgs: [id, today.millisecondsSinceEpoch],
    );

    return 1;
  }

  // Yeni metod: İlacı tamamen sil (geçmiş verilerle birlikte)
  Future<int> permanentlyDeleteMedication(int id) async {
    final db = await database;

    // Önce ilgili logları sil
    await db.delete(
      'medication_logs',
      where: 'medicationId = ?',
      whereArgs: [id],
    );

    // Sonra ilacı sil
    return await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  // Medication Log CRUD operations
  Future<int> insertMedicationLog(MedicationLog log) async {
    final db = await database;
    return await db.insert('medication_logs', log.toMap());
  }

  Future<List<MedicationLog>> getMedicationLogs(int medicationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_logs',
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      orderBy: 'scheduledTime DESC',
    );
    return List.generate(maps.length, (i) {
      return MedicationLog.fromMap(maps[i]);
    });
  }

  Future<List<MedicationLog>> getTodayLogs() async {
    final db = await database;
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );

    final List<Map<String, dynamic>> maps = await db.query(
      'medication_logs',
      where: 'scheduledTime >= ? AND scheduledTime <= ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'scheduledTime ASC',
    );
    return List.generate(maps.length, (i) {
      return MedicationLog.fromMap(maps[i]);
    });
  }

  Future<List<MedicationLog>> getLogsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_logs',
      where: 'scheduledTime >= ? AND scheduledTime <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'scheduledTime DESC',
    );
    return List.generate(maps.length, (i) {
      return MedicationLog.fromMap(maps[i]);
    });
  }

  Future<MedicationLog?> getLogById(int logId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    if (maps.isEmpty) return null;
    return MedicationLog.fromMap(maps.first);
  }

  Future<int> updateMedicationLog(MedicationLog log) async {
    final db = await database;
    return await db.update(
      'medication_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteMedicationLog(int id) async {
    final db = await database;
    return await db.delete('medication_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all pending (not taken and not skipped) logs for the given medication
  /// on the provided date (00:00 - 23:59:59).
  Future<void> deletePendingLogsForMedicationOnDate(int medicationId, DateTime date) async {
    final db = await database;
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    await db.delete(
      'medication_logs',
      where: 'medicationId = ? AND isTaken = 0 AND isSkipped = 0 AND scheduledTime >= ? AND scheduledTime <= ?',
      whereArgs: [
        medicationId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );
  }

  /// Returns all logs for the given medication on the provided date (any status)
  Future<List<MedicationLog>> getLogsForMedicationOnDate(int medicationId, DateTime date) async {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final List<MedicationLog> logs = await getLogsByDateRange(startOfDay, endOfDay);
    return logs.where((l) => l.medicationId == medicationId).toList();
  }

  /// Deletes all logs (any status) for the given medication on the provided date
  Future<void> deleteAllLogsForMedicationOnDate(int medicationId, DateTime date) async {
    final db = await database;
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    await db.delete(
      'medication_logs',
      where: 'medicationId = ? AND scheduledTime >= ? AND scheduledTime <= ?',
      whereArgs: [
        medicationId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );
  }

  // STOCK HELPERS
  Future<MedicationStock?> getStockByMedicationId(int medicationId) async {
    final db = await database;
    final maps = await db.query(
      'medication_stocks',
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MedicationStock.fromMap(maps.first);
  }

  Future<void> upsertStock({
    required int medicationId,
    int? currentStock,
    int minimumStock = 5,
    int maximumStock = 30,
    String unit = 'tablet',
    String notes = '',
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final existing = await getStockByMedicationId(medicationId);
    if (existing == null) {
      await db.insert('medication_stocks', {
        'medicationId': medicationId,
        'currentStock': currentStock ?? 0,
        'minimumStock': minimumStock,
        'maximumStock': maximumStock,
        'unit': unit,
        'lastUpdated': nowIso,
        'notes': notes,
      });
    } else {
      await db.update(
        'medication_stocks',
        {
          'currentStock': currentStock ?? existing.currentStock,
          'minimumStock': minimumStock,
          'maximumStock': maximumStock,
          'unit': unit,
          'lastUpdated': nowIso,
          'notes': notes,
        },
        where: 'medicationId = ?',
        whereArgs: [medicationId],
      );
    }
  }

  Future<void> incrementStock(int medicationId, {int by = 1}) async {
    final db = await database;
    final medication = await getMedication(medicationId);
    if (medication != null) {
      final newStock = medication.stock + by;
      await db.update(
        'medications',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [medicationId],
      );
    }
  }

  Future<void> decrementStock(int medicationId, {int by = 1}) async {
    final db = await database;
    final medication = await getMedication(medicationId);
    if (medication != null) {
      final newStock = (medication.stock - by).clamp(0, 1 << 31);
      await db.update(
        'medications',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [medicationId],
      );
    }
  }

  Future<List<MedicationStock>> getAllStocks() async {
    final db = await database;
    final maps = await db.query('medication_stocks');
    return maps.map((e) => MedicationStock.fromMap(e)).toList();
  }

  Future<int> getLowStockCount({int threshold = 3}) async {
    final stocks = await getAllStocks();
    int count = 0;
    for (final s in stocks) {
      if (s.currentStock <= threshold || s.currentStock <= s.minimumStock) {
        count++;
      }
    }
    return count;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
