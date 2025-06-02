import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';

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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
        isActive INTEGER NOT NULL DEFAULT 1
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

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
