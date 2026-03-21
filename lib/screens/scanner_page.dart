import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/ocr_service.dart';
import '../services/gemini_service.dart';

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
  String _processingStatus = '';
  List<ReceiptItem> _receiptItems = [];
  List<TextEditingController> _amountControllers = [];
  List<TextEditingController> _descControllers = [];
  List<String> _selectedCategories = [];

  @override
  void dispose() {
    for (final c in _amountControllers) c.dispose();
    for (final c in _descControllers) c.dispose();
    super.dispose();
  }

  // --- Buka kamera ---
  Future<void> _openCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null) {
      await _processImage(File(photo.path));
    } else {
      if (mounted && _capturedImage == null) Navigator.pop(context);
    }
  }

  // --- Pilih dari galeri ---
  Future<void> _openGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (photo != null) {
      await _processImage(File(photo.path));
    }
  }

  // --- Proses gambar: OCR → Gemini ---
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _capturedImage = imageFile;
      _isProcessing = true;
      _processingStatus = 'Membaca teks dari struk...';
      _receiptItems = [];
    });

    try {
      // Step 1: OCR — baca teks dari gambar
      final rawText = await OcrService.instance.extractText(imageFile);

      if (rawText.isEmpty) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Tidak ada teks terdeteksi. Coba foto lebih jelas.';
        });
        return;
      }

      // Step 2: Gemini — parse teks → kategori + total
      setState(() => _processingStatus = 'Menganalisis struk dengan AI...');
      final items = await GeminiService.instance.parseReceiptText(rawText);

      if (items.isEmpty) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Gagal menganalisis struk. Coba lagi atau input manual.';
        });
        return;
      }

      // Step 3: Siapkan controllers untuk form edit
      _amountControllers = items
          .map((i) => TextEditingController(
              text: i.total > 0 ? i.total.toStringAsFixed(0) : ''))
          .toList();
      _descControllers =
          items.map((i) => TextEditingController(text: i.deskripsi)).toList();
      _selectedCategories = items.map((i) => i.kategori).toList();

      setState(() {
        _receiptItems = items;
        _isProcessing = false;
        _processingStatus = '';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error: $e';
      });
    }
  }

  // --- Simpan semua transaksi ---
  Future<void> _saveAll() async {
    int savedCount = 0;

    for (int i = 0; i < _receiptItems.length; i++) {
      final amount = double.tryParse(
          _amountControllers[i].text.replaceAll('.', '').replaceAll(',', ''));
      final desc = _descControllers[i].text.trim();

      if (amount == null || amount <= 0 || desc.isEmpty) continue;

      final saved = await DatabaseHelper.instance.insertTransaction(
        TransactionModel(
          amount: amount,
          description: desc,
          category: _selectedCategories[i],
          date: DateTime.now(),
          inputMethod: 'scan',
        ),
      );
      await SyncService.instance.uploadOne(saved);
      savedCount++;
    }

    widget.onTransactionSaved?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $savedCount transaksi berhasil disimpan'),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _receiptItems = [];
      _processingStatus = '';
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Struk', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_capturedImage != null && !_isProcessing)
            TextButton(
              onPressed: _reset,
              child: const Text('Ulang', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- Pilih sumber gambar (jika belum ada foto) ---
            if (_capturedImage == null && !_isProcessing) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.document_scanner_outlined,
                        color: Colors.white38, size: 64),
                    const SizedBox(height: 16),
                    const Text('Pilih sumber gambar struk',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Foto struk atau nota belanja kamu',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openCamera,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tips foto yang baik:',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _tipItem('Pastikan struk tidak terlipat atau kusut'),
                    _tipItem('Foto dalam pencahayaan yang cukup'),
                    _tipItem('Pastikan semua teks terlihat jelas'),
                    _tipItem('Hindari bayangan di atas struk'),
                  ],
                ),
              ),
            ],

            // --- Loading indicator ---
            if (_isProcessing) ...[
              const SizedBox(height: 40),
              if (_capturedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_capturedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover),
                ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 16),
              Text(_processingStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],

            // --- Error / status message ---
            if (!_isProcessing &&
                _processingStatus.isNotEmpty &&
                _receiptItems.isEmpty) ...[
              const SizedBox(height: 20),
              if (_capturedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_capturedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_processingStatus,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto Ulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pilih Galeri'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ],

            // --- Hasil scan: form edit per kategori ---
            if (_receiptItems.isNotEmpty && !_isProcessing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_capturedImage!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Text('${_receiptItems.length} kategori terdeteksi — periksa & edit',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
              const SizedBox(height: 16),

              // Form per item
              ...List.generate(_receiptItems.length, (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown kategori
                      StatefulBuilder(
                        builder: (ctx, setDropState) =>
                            DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategories[i],
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            items: TransactionCategory.all
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                          '${TransactionCategory.iconForCategory(cat)} $cat'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDropState(
                                    () => _selectedCategories[i] = val);
                                setState(() => _selectedCategories[i] = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Deskripsi
                      TextField(
                        controller: _descControllers[i],
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Keterangan',
                          labelStyle: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Nominal
                      TextField(
                        controller: _amountControllers[i],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Nominal (Rp)',
                          labelStyle: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          prefixText: 'Rp ',
                          prefixStyle:
                              const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
              // Tombol simpan semua
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.save_alt),
                  label: Text(
                    'Simpan ${_receiptItems.length} Transaksi',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check, color: Colors.greenAccent, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12))),
      ]),
    );
  }
}