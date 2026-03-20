import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class ScannerPage extends StatefulWidget {
  final VoidCallback? onTransactionSaved;
  const ScannerPage({super.key, this.onTransactionSaved});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  // Hasil OCR (simulasi - ganti dengan AI/OCR asli)
  double _detectedAmount = 75000;
  String _detectedDescription = "Struk Belanja Indomaret";
  String _selectedCategory = 'Belanja';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo != null) {
      setState(() {
        _capturedImage = File(photo.path);
        _isProcessing = true;
      });

      // Simulasi proses OCR (ganti dengan integrasi AI/OCR asli nanti)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showResultDialog();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showResultDialog() {
    final amountController = TextEditingController(
        text: _detectedAmount.toStringAsFixed(0));
    final descController = TextEditingController(text: _detectedDescription);
    String selectedCategory = _selectedCategory;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                Row(children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text("Hasil Scan",
                      style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 16),
                // Edit nominal hasil scan
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Nominal (Rp)",
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    prefixText: "Rp ",
                    prefixStyle: const TextStyle(color: Colors.white54),
                    filled: true, fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                // Edit keterangan hasil scan
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Keterangan",
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
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
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openCamera();
                      },
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text("Scan Ulang"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text.replaceAll('.', ''));
                        final desc = descController.text.trim();
                        if (amount == null || amount <= 0 || desc.isEmpty) return;

                        final saved = await DatabaseHelper.instance.insertTransaction(TransactionModel(
                          amount: amount,
                          description: desc,
                          category: selectedCategory,
                          date: DateTime.now(),
                          inputMethod: 'scan',
                        ));
                        await SyncService.instance.uploadOne(saved);

                        widget.onTransactionSaved?.call();

                        if (context.mounted) {
                          Navigator.pop(context); // tutup result sheet
                          Navigator.pop(context); // kembali ke home
                        }
                      },
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Scan Struk", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 20),
                  Text("Memproses struk...", style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              )
            : _capturedImage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_capturedImage!, width: 280, height: 400, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _openCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Foto Ulang"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 280, height: 400,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.greenAccent, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_outlined, color: Colors.white54, size: 50),
                              SizedBox(height: 16),
                              Text("Membuka kamera...", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _openCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Buka Kamera"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}