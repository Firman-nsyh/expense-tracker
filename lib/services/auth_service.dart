import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Future<User?> signInWithGoogle() async {
    try {
      print('🔵 Memulai Google Sign-In...');

      // Pastikan sign out dulu agar paksa pilih akun ulang
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('🔴 User membatalkan login');
        return null;
      }
      print('🟢 Akun dipilih: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('🔵 accessToken: ${googleAuth.accessToken != null ? "ADA" : "NULL"}');
      print('🔵 idToken: ${googleAuth.idToken != null ? "ADA" : "NULL"}');

      // Cek null sebelum lanjut
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        print('🔴 Kedua token null — kemungkinan SHA-1 tidak cocok');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      print('🟢 Login berhasil: ${userCredential.user?.email}');

      return userCredential.user;
    } catch (e) {
      print('🔴 Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String get displayName => currentUser?.displayName ?? 'Pengguna';
  String get email => currentUser?.email ?? '';
  String? get photoUrl => currentUser?.photoURL;
  String get uid => currentUser?.uid ?? '';
}