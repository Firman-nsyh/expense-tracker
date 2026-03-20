import 'package:firebase_database/firebase_database.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Path node transaksi milik user yang login
  DatabaseReference get _userRef {
    final uid = AuthService.instance.uid;
    return _db.ref('users/$uid/transactions');
  }

  // --- Upload semua transaksi lokal ke Firebase ---
  Future<void> uploadAll() async {
    if (!AuthService.instance.isLoggedIn) return;
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    for (final t in transactions) {
      await _userRef.child(t.id.toString()).set(t.toMap());
    }
  }

  // --- Upload satu transaksi baru ke Firebase ---
  Future<void> uploadOne(TransactionModel t) async {
    if (!AuthService.instance.isLoggedIn) return;
    await _userRef.child(t.id.toString()).set(t.toMap());
  }

  // --- Hapus satu transaksi dari Firebase ---
  Future<void> deleteOne(int id) async {
    if (!AuthService.instance.isLoggedIn) return;
    await _userRef.child(id.toString()).remove();
  }

  // --- Download semua transaksi dari Firebase ke SQLite lokal ---
  Future<void> downloadAll() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final snapshot = await _userRef.get();
      if (!snapshot.exists) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final db = DatabaseHelper.instance;

      for (final entry in data.entries) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        final t = TransactionModel.fromMap(map);

        // Cek apakah sudah ada di lokal, kalau belum insert
        final existing = await db.getAllTransactions();
        final ids = existing.map((e) => e.id).toSet();
        if (!ids.contains(t.id)) {
          await db.insertTransaction(t);
        }
      }
    } catch (e) {
      // Gagal sync — data lokal tetap aman
    }
  }

  // --- Sinkronisasi dua arah saat login ---
  Future<void> syncOnLogin() async {
    // Bersihkan data lokal dulu agar data akun lama tidak tercampur
    await DatabaseHelper.instance.clearAll();
    // Download data milik akun yang baru login dari Firebase
    await downloadAll();
    // Upload balik ke Firebase (jaga konsistensi)
    await uploadAll();
  }
}