import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('money.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        amount      REAL    NOT NULL,
        description TEXT    NOT NULL,
        category    TEXT    NOT NULL,
        date        TEXT    NOT NULL,
        inputMethod TEXT    NOT NULL DEFAULT 'manual'
      )
    ''');
  }

  // --- CREATE ---
  Future<TransactionModel> insertTransaction(TransactionModel t) async {
    final db = await database;
    final id = await db.insert('transactions', t.toMap());
    return TransactionModel(
      id: id,
      amount: t.amount,
      description: t.description,
      category: t.category,
      date: t.date,
      inputMethod: t.inputMethod,
    );
  }

  // --- READ: semua transaksi, terbaru di atas ---
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // --- READ: transaksi bulan tertentu ---
  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end   = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // --- READ: total bulan ini ---
  Future<double> getTotalThisMonth() async {
    final now = DateTime.now();
    final txs = await getTransactionsByMonth(now.year, now.month);
    return txs.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // --- READ: total minggu ini ---
  Future<double> getTotalThisWeek() async {
    final db = await database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)
        .toIso8601String();
    final result = await db.query('transactions', where: 'date >= ?', whereArgs: [start]);
    final txs = result.map((map) => TransactionModel.fromMap(map)).toList();
    return txs.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // --- READ: total per bulan untuk chart ---
  Future<Map<int, double>> getMonthlyTotals(int year) async {
    final db = await database;
    final start = DateTime(year, 1, 1).toIso8601String();
    final end   = DateTime(year + 1, 1, 1).toIso8601String();
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
    );
    final Map<int, double> totals = {for (var i = 1; i <= 12; i++) i: 0.0};
    for (final map in result) {
      final t = TransactionModel.fromMap(map);
      totals[t.date.month] = (totals[t.date.month] ?? 0) + t.amount;
    }
    return totals;
  }

  // --- READ: daftar bulan yang ada datanya (untuk halaman arsip) ---
  Future<List<Map<String, dynamic>>> getAvailableMonths() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        strftime('%Y', date) AS year,
        strftime('%m', date) AS month,
        COUNT(*) AS count,
        SUM(amount) AS total
      FROM transactions
      GROUP BY year, month
      ORDER BY year DESC, month DESC
    ''');
    return result;
  }

  // --- UPDATE ---
  Future<int> updateTransaction(TransactionModel t) async {
    final db = await database;
    return await db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  // --- DELETE ---
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // --- CLEAR: hapus semua data lokal (saat logout / ganti akun) ---
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('transactions');
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}