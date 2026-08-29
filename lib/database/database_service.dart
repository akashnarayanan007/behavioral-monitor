import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static Database? _database;

  // ✅ INSERT FULL BEHAVIOR
  static Future<void> insertBehavior(Map<String, dynamic> data) async {
    final db = await database;

    await db.insert(
      'behavior',
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // ✅ UPDATE MOOD (LATEST ENTRY)
  static Future<void> insertMood(int mood) async {
    final db = await database;

    List<Map<String, dynamic>> result =
    await db.query('behavior', orderBy: 'id DESC', limit: 1);

    if (result.isNotEmpty) {
      int id = result.first['id'];

      await db.update(
        'behavior',
        {'mood': mood},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ✅ FETCH LAST 10 ENTRIES (FOR STABILITY)
  static Future<List<Map<String, dynamic>>> getLast10() async {
    final db = await database;

    return await db.query(
      'behavior',
      orderBy: 'id DESC',
      limit: 10,
    );
  }

  // ✅ FETCH RECENT ENTRIES (FLEXIBLE LIMIT)
  static Future<List<Map<String, dynamic>>> getRecentEntries(int count) async {
    final db = await database;
    return await db.query(
      'behavior',
      orderBy: 'id DESC',
      limit: count,
    );
  }

  // ✅ DELETE SPECIFIC ENTRY
  static Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete(
      'behavior',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ FETCH TOTAL COUNT
  static Future<int> getCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM behavior')) ?? 0;
  }

  // --- SESSION SUMMARY METHODS ---

  // ✅ INSERT SESSION SUMMARY (Updated to return ID)
  static Future<int> insertSummary(String category, String summaryText) async {
    final db = await database;
    return await db.insert('summaries', {
      'category': category,
      'summary_text': summaryText,
      'timestamp': DateTime.now().toIso8601String(),
      'rating': 0, // Default rating
    });
  }

  // ✅ UPDATE SESSION RATING
  static Future<void> updateSummaryRating(int id, int rating) async {
    final db = await database;
    await db.update(
      'summaries',
      {'rating': rating},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ FETCH ALL SUMMARIES
  static Future<List<Map<String, dynamic>>> getAllSummaries() async {
    final db = await database;
    return await db.query('summaries', orderBy: 'timestamp DESC');
  }

  // ✅ DELETE SESSION SUMMARY
  static Future<void> deleteSessionSummary(int id) async {
    final db = await database;
    await db.delete('summaries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ UPDATE AI INTERPRETATION
  static Future<void> updateAIInterpretation(int id, String text) async {
    final db = await database;
    await db.update(
      'behavior',
      {'ai_interpretation': text},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ DATABASE INSTANCE
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  // ✅ CREATE DATABASE
  static Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'behavior.db');

    return await openDatabase(
      path,
      version: 4, // Incremented version to add ai_interpretation
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE behavior(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sleep REAL,
  work REAL,
  study REAL,
  workout REAL,
  food INTEGER,
  mealSkipped INTEGER,
  routine INTEGER,
  screenTime REAL,
  calls INTEGER,
  maxCallDuration REAL,
  mood INTEGER,
  date TEXT,
  ai_interpretation TEXT
)
''');
        await db.execute('''
CREATE TABLE summaries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT,
  summary_text TEXT,
  timestamp TEXT,
  rating INTEGER DEFAULT 0
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
CREATE TABLE summaries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT,
  summary_text TEXT,
  timestamp TEXT,
  rating INTEGER DEFAULT 0
)
''');
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE summaries ADD COLUMN rating INTEGER DEFAULT 0');
          } catch (e) {}
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE behavior ADD COLUMN ai_interpretation TEXT');
        }
      },
    );
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('behavior');
    await db.delete('summaries');
  }

  // ✅ FACTORY RESET LOGIC
  static Future<void> factoryReset() async {
    // 1. Clear Database
    await clearAllData();

    // 2. Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. Reset _database instance to force re-init if needed
    _database = null;
  }
}
