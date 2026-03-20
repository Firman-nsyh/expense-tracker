import 'package:firebase_database/firebase_database.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _userRef {
    final uid = AuthService.instance.uid;
    return _db.ref('users/$uid/transactions');
  }

  // --- Upload semua transaksi lokal ke Firebase ---
  Future<void> uploadAll() async {
    if (!AuthService.instance.isLoggedIn) return;
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    for (final t in transactions) {
      // Pakai prefix 'tx_' agar Firebase tidak konversi ke Array
      await _userRef.child('tx_${t.id}').set(_toFirebaseMap(t));
    }
    print('🟢 uploadAll selesai — ${transactions.length} transaksi');
  }

  // --- Upload satu transaksi baru ke Firebase ---
  Future<void> uploadOne(TransactionModel t) async {
    final uid = AuthService.instance.uid;
    print('🔵 uploadOne — isLoggedIn: ${AuthService.instance.isLoggedIn}, uid: $uid, txId: ${t.id}');
    if (!AuthService.instance.isLoggedIn) {
      print('🔴 uploadOne dibatalkan — user belum login');
      return;
    }
    try {
      await _userRef.child('tx_${t.id}').set(_toFirebaseMap(t));
      print('🟢 uploadOne berhasil — users/$uid/transactions/tx_${t.id}');
    } catch (e) {
      print('🔴 uploadOne error: $e');
    }
  }

  // --- Hapus satu transaksi dari Firebase ---
  Future<void> deleteOne(int id) async {
    if (!AuthService.instance.isLoggedIn) return;
    await _userRef.child('tx_$id').remove();
    print('🟢 deleteOne berhasil — id: $id');
  }

  // --- Download semua transaksi dari Firebase ke SQLite lokal ---
  Future<void> downloadAll() async {
    final uid = AuthService.instance.uid;
    print('🔵 downloadAll — isLoggedIn: ${AuthService.instance.isLoggedIn}, uid: $uid');
    if (!AuthService.instance.isLoggedIn) {
      print('🔴 downloadAll dibatalkan — user belum login');
      return;
    }
    try {
      final snapshot = await _userRef.get();
      print('🔵 snapshot.exists: ${snapshot.exists}');
      if (!snapshot.exists) {
        print('🟡 Tidak ada data di Firebase untuk uid: $uid');
        return;
      }

      // Firebase kadang return List jika key berupa angka — konversi ke Map
      Map<String, dynamic> data;
      final raw = snapshot.value;
      if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      } else if (raw is List) {
        data = {};
        for (int i = 0; i < raw.length; i++) {
          if (raw[i] != null) data[i.toString()] = raw[i];
        }
      } else {
        print('🔴 Format data tidak dikenali: ${raw.runtimeType}');
        return;
      }

      print('🔵 Jumlah data dari Firebase: ${data.length}');
      final db = DatabaseHelper.instance;
      int inserted = 0;

      for (final entry in data.entries) {
        try {
          final map = Map<String, dynamic>.from(entry.value as Map);
          final t = _fromFirebaseMap(map);
          await db.insertTransaction(t);
          inserted++;
        } catch (e) {
          print('🔴 Gagal parse transaksi ${entry.key}: $e');
        }
      }
      print('🟢 downloadAll selesai — $inserted transaksi diinsert');
    } catch (e) {
      print('🔴 downloadAll error: $e');
    }
  }

  // --- Sinkronisasi saat login ---
  Future<void> syncOnLogin() async {
    print('🔵 syncOnLogin mulai...');
    await DatabaseHelper.instance.clearAll();
    print('🟢 SQLite lokal dibersihkan');
    await downloadAll();
    await uploadAll();
    print('🟢 syncOnLogin selesai');
  }

  // --- Helper: konversi ke format Firebase ---
  Map<String, dynamic> _toFirebaseMap(TransactionModel t) {
    return {
      'id': t.id,
      'amount': t.amount.toDouble(),
      'description': t.description,
      'category': t.category,
      'date': t.date.toIso8601String(),
      'inputMethod': t.inputMethod,
    };
  }

  // --- Helper: konversi dari Firebase (handle num → double) ---
  TransactionModel _fromFirebaseMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: (map['id'] as num?)?.toInt(),
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      inputMethod: (map['inputMethod'] as String?) ?? 'manual',
    );
  }
}