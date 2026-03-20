import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class SettingsPageContent extends StatefulWidget {
  const SettingsPageContent({super.key});
  @override
  State<SettingsPageContent> createState() => _SettingsPageContentState();
}

class _SettingsPageContentState extends State<SettingsPageContent> {
  bool _isSyncing = false;

  Future<void> _handleLogin() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null) {
      setState(() => _isSyncing = true);
      await SyncService.instance.syncOnLogin();
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Login berhasil & data tersinkronisasi'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    await SyncService.instance.uploadAll();
    setState(() => _isSyncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Data berhasil disinkronisasi ke cloud'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar Akun', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Data lokal tetap tersimpan di perangkat ini. Yakin ingin keluar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.signOut();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data != null;
        final user = snapshot.data;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pengaturan",
                    style: TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),

                // --- Profil ---
                Center(
                  child: Column(children: [
                    Stack(children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orangeAccent, width: 2)),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: isLoggedIn && user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : const NetworkImage('https://i.pravatar.cc/300'),
                        ),
                      ),
                      if (!isLoggedIn)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.orangeAccent, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, color: Colors.black, size: 16),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Text(
                      isLoggedIn ? (user?.displayName ?? 'Pengguna') : 'Belum Login',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isLoggedIn ? (user?.email ?? '') : 'Login untuk sinkronisasi data',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),

                // --- Tombol Login / Sync / Logout ---
                if (!isLoggedIn)
                  _buildGoogleLoginButton()
                else ...[
                  _buildSyncButton(),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle("Preferensi"),
                _buildSettingTile(
                    Icons.notifications_none,
                    "Notifikasi",
                    Switch(value: true, activeColor: Colors.orangeAccent, onChanged: (v) {})),
                _buildSettingTile(Icons.translate, "Bahasa",
                    const Text("ID", style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 24),
                _buildSectionTitle("Lainnya"),
                _buildSettingTile(Icons.help_outline, "Bantuan & Support", null),
                const SizedBox(height: 32),

                // --- Tombol Keluar ---
                if (isLoggedIn)
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.redAccent.withOpacity(0.1),
                      ),
                      child: const Center(
                        child: Text("Keluar Akun",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tombol Google Sign In
  Widget _buildGoogleLoginButton() {
    return GestureDetector(
      onTap: _handleLogin,
      child: Container(
        width: double.infinity, height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 20)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.network(
            'https://www.google.com/favicon.ico',
            width: 20, height: 20,
            errorBuilder: (_, __, ___) => const Icon(Icons.login, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          const Text("Masuk dengan Google",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    );
  }

  // Tombol Sync Manual
  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: _isSyncing ? null : _handleSync,
      child: Container(
        width: double.infinity, height: 55,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(20),
          color: Colors.blueAccent.withOpacity(0.1),
        ),
        child: Center(
          child: _isSyncing
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.sync, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text("Sinkronisasi Data",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ]),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, Widget? trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
        if (trailing != null) trailing
        else const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
      ]),
    );
  }
}