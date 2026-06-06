import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mood_entry.dart';

// This class handles everything database related.
// Think of it as the only file in your project that's
// "allowed" to talk to SQLite directly — everything else
// goes through this class.
//
// It uses a pattern called "Singleton" — meaning only one
// instance of this class ever exists while the app is running.
// In Python this is like a module-level variable that gets
// created once and reused everywhere.

class DatabaseHelper {
  // This is the singleton instance — a private static variable
  // static means it belongs to the class, not any specific object
  // (like a class variable in Python)
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  // Private constructor — prevents anyone from doing DatabaseHelper()
  // The _internal name is just a convention, it could be anything
  DatabaseHelper._internal();
  
  // This is what other files use to get the singleton:
  // DatabaseHelper.instance
  // Like calling a module-level object in Python
  static DatabaseHelper get instance => _instance;

  // The actual database object — nullable because it starts as null
  // before we've opened it
  Database? _database;

  // A "getter" — lets you access _database like a property
  // but runs code to set it up if it hasn't been opened yet.
  // The async/await works exactly like Python's async/await.
  Future<Database> get database async {
    // If database already exists, return it immediately
    if (_database != null) return _database!;
    // Otherwise create it
    _database = await _initDatabase();
    return _database!;
  }

  // Opens (or creates) the database file on the device
  Future<Database> _initDatabase() async {
    // getDatabasesPath() finds the right folder on the device
    // to store database files — we don't pick this ourselves
    final dbPath = await getDatabasesPath();
    
    // join() builds a file path — like os.path.join() in Python
    final path = join(dbPath, 'hourly_mood.db');

    return await openDatabase(
      path,
      version: 1,           // Schema version — increment this when you change the schema
      onCreate: _onCreate,  // Function to call when database is first created
    );
  }

  // This runs once, the very first time the app opens the database.
  // It creates our tables. This is where our SQL schema lives.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp  INTEGER NOT NULL,
        mood_score INTEGER NOT NULL
      )
    ''');

    // Create an index on timestamp so date-range queries are fast
    // This is like adding an index in any SQL database
    await db.execute('''
      CREATE INDEX idx_timestamp ON mood_entries(timestamp)
    ''');

    // Settings table — stores simple key/value pairs
    // Like a persistent Python dictionary
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Insert default settings
    await db.insert('settings', {'key': 'start_hour', 'value': '9'});
    await db.insert('settings', {'key': 'end_hour',   'value': '21'});
  }

  // ─── MOOD ENTRY METHODS ───────────────────────────────────────

  // Save a new mood entry to the database
  // Returns the id that SQLite assigned to the new row
  Future<int> insertMoodEntry(MoodEntry entry) async {
    final db = await database;
    return await db.insert(
      'mood_entries',
      entry.toMap(),
      // If somehow a duplicate id appears, replace it
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all mood entries for a specific day
  // This is the main query our graph screen will use
  Future<List<MoodEntry>> getEntriesForDay(DateTime day) async {
    final db = await database;

    // Calculate start and end of the day in milliseconds
    // (SQLite stores our timestamps as milliseconds since epoch)
    final startOfDay = DateTime(day.year, day.month, day.day)
        .millisecondsSinceEpoch;
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    final List<Map<String, dynamic>> rows = await db.query(
      'mood_entries',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp ASC',
    );

    // Convert each database row (Map) back into a MoodEntry object
    // This is like a list comprehension in Python:
    // [MoodEntry.from_dict(row) for row in rows]
    return rows.map((row) => MoodEntry.fromMap(row)).toList();
  }

  // Calculate the average mood score for a day
  // Returns null if there are no entries that day
  Future<double?> getDailyAverage(DateTime day) async {
    final entries = await getEntriesForDay(day);
    if (entries.isEmpty) return null;

    // Add up all scores and divide — same as Python's sum()/len()
    final total = entries.fold(0, (sum, entry) => sum + entry.moodScore);
    return total / entries.length;
  }

  // ─── SETTINGS METHODS ─────────────────────────────────────────

  Future<int> getSettingInt(String key, int defaultValue) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return defaultValue;
    return int.parse(rows.first['value'] as String);
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}