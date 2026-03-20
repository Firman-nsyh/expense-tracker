import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'archive_page.dart';
import 'settings_page.dart';
import 'scanner_page.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  // Gunakan GlobalKey agar bisa trigger refresh HomePageContent dari luar
  final _homeKey = GlobalKey<HomePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePageContent(key: _homeKey),
      const ChatPageContent(),
      const ArchivePageContent(),
      const SettingsPageContent(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    // Refresh home setiap kali kembali ke tab home
    if (index == 0) _homeKey.currentState?.reload();
  }

  Color _getAccentColor() {
    switch (_selectedIndex) {
      case 0: return Colors.purple;
      case 1: return Colors.blueAccent;
      case 2: return Colors.greenAccent;
      case 3: return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: _getAccentColor().withOpacity(0.4),
                  blurRadius: 100, spreadRadius: 10,
                )],
              ),
            ),
          ),
          IndexedStack(index: _selectedIndex, children: _pages),
          Positioned(
            left: 20, right: 20, bottom: 30,
            child: _buildGlassNavbar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavbar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF181818).withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(Icons.home_filled, 0),
              _navItem(Icons.chat_bubble_outline, 1),
              GestureDetector(
                onTap: () => _showInputBubble(context),
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 25, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 30),
                ),
              ),
              _navItem(Icons.folder_open, 2),
              _navItem(Icons.settings, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.white : Colors.white24, size: 28),
      onPressed: () => _onItemTapped(index),
    );
  }

  void _showInputBubble(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const Text("Tambah Transaksi",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.keyboard, "Teks", Colors.blueAccent, () {
                  Navigator.pop(context);
                  _showManualInputForm(context);
                }),
                _actionButton(Icons.mic, "Suara", Colors.redAccent, () {
                  Navigator.pop(context);
                  _showVoiceInputDialog(context);
                }),
                _actionButton(Icons.camera_alt, "Scan", Colors.greenAccent, () {
                  Navigator.pop(context);
                  _openCameraScanner(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3))),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  // --- FORM INPUT MANUAL (menyimpan ke SQLite) ---
  void _showManualInputForm(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = TransactionCategory.all.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Input Manual",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nominal (Rp)",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Keterangan (Cth: Makan Siang)",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dropdown kategori
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        items: TransactionCategory.all.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text('${TransactionCategory.iconForCategory(cat)} $cat'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(
                            amountController.text.replaceAll('.', '').replaceAll(',', ''));
                        final desc = descController.text.trim();
                        if (amount == null || amount <= 0 || desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("Nominal dan keterangan wajib diisi"),
                            backgroundColor: Colors.redAccent,
                          ));
                          return;
                        }
                        final saved = await DatabaseHelper.instance.insertTransaction(TransactionModel(
                          amount: amount,
                          description: desc,
                          category: selectedCategory,
                          date: DateTime.now(),
                          inputMethod: 'manual',
                        ));
                        await SyncService.instance.uploadOne(saved);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _homeKey.currentState?.reload();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("✅ Transaksi berhasil disimpan"),
                            backgroundColor: Colors.green,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Simpan Transaksi",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showVoiceInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.mic, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            const Text("Mendengarkan...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Sebutkan nominal dan keterangan.\nCth: 'Dua puluh ribu untuk bensin'",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.2), elevation: 0),
              child: const Text("Batal", style: TextStyle(color: Colors.redAccent)),
            )
          ],
        ),
      ),
    );
  }

  void _openCameraScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScannerPage(
        onTransactionSaved: () => _homeKey.currentState?.reload(),
      )),
    );
  }
}