import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/voice_parser_service.dart';

class VoiceInputPage extends StatefulWidget {
  final VoidCallback? onTransactionSaved;
  const VoiceInputPage({super.key, this.onTransactionSaved});

  @override
  State<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends State<VoiceInputPage>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  late AnimationController _pulseController;

  bool _isListening = false;
  bool _isInitialized = false;
  bool _showForm = false;
  String _recognizedText = '';
  String _statusText = 'Tekan tombol untuk mulai berbicara';

  // Form controllers
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = TransactionCategory.all.first;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (error) {
        setState(() {
          _statusText = 'Error: ${error.errorMsg}';
          _isListening = false;
        });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening) _stopListening();
        }
      },
    );
    setState(() => _isInitialized = available);
    if (!available) {
      setState(() => _statusText = 'Mikrofon tidak tersedia di perangkat ini');
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      setState(() => _statusText = 'Mikrofon tidak siap');
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _showForm = false;
      _statusText = 'Sedang mendengarkan...';
    });

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          if (result.finalResult && _recognizedText.isNotEmpty) {
            _processVoiceResult(_recognizedText);
          }
        });
      },
      localeId: 'id_ID', // Bahasa Indonesia
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty) {
      _processVoiceResult(_recognizedText);
    } else {
      setState(() => _statusText = 'Tidak ada suara terdeteksi. Coba lagi.');
    }
  }

  void _processVoiceResult(String text) {
    final result = VoiceParserService.instance.parse(text);

    setState(() {
      _isListening = false;
      _showForm = true;
      _statusText = 'Hasil dikenali — periksa dan edit jika perlu';
      _amountController.text = result.amount > 0
          ? result.amount.toStringAsFixed(0)
          : '';
      _descController.text = result.description;
      _selectedCategory = result.category;
    });
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(
        _amountController.text.replaceAll('.', '').replaceAll(',', ''));
    final desc = _descController.text.trim();

    if (amount == null || amount <= 0 || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nominal dan keterangan wajib diisi'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final saved = await DatabaseHelper.instance.insertTransaction(
      TransactionModel(
        amount: amount,
        description: desc,
        category: _selectedCategory,
        date: DateTime.now(),
        inputMethod: 'voice',
      ),
    );
    await SyncService.instance.uploadOne(saved);

    widget.onTransactionSaved?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Transaksi berhasil disimpan'),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _reset() {
    setState(() {
      _showForm = false;
      _recognizedText = '';
      _statusText = 'Tekan tombol untuk mulai berbicara';
      _amountController.clear();
      _descController.clear();
      _selectedCategory = TransactionCategory.all.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Input Suara', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_showForm)
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
            const SizedBox(height: 20),

            // --- Animasi Mic ---
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening) ...[
                      Container(
                        width: 140 + (_pulseController.value * 30),
                        height: 140 + (_pulseController.value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.1 * _pulseController.value),
                        ),
                      ),
                      Container(
                        width: 110 + (_pulseController.value * 20),
                        height: 110 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.15 * _pulseController.value),
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.redAccent
                              : const Color(0xFF1A1A1A),
                          border: Border.all(
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // --- Status text ---
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isListening ? Colors.redAccent : Colors.white54,
                fontSize: 14,
              ),
            ),

            // --- Teks yang dikenali ---
            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teks terdeteksi:',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '"$_recognizedText"',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],

            // --- Contoh cara bicara ---
            if (!_showForm && !_isListening) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contoh cara bicara:',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _exampleItem('"Beli bensin lima puluh ribu"'),
                    _exampleItem('"Makan siang dua puluh lima ribu"'),
                    _exampleItem('"Bayar listrik tiga ratus ribu"'),
                    _exampleItem('"Belanja indomaret Rp 75.000"'),
                  ],
                ),
              ),
            ],

            // --- Form edit hasil ---
            if (_showForm) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periksa & edit hasil:',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Nominal
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Nominal (Rp)',
                        labelStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Deskripsi
                    TextField(
                      controller: _descController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Keterangan',
                        labelStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kategori
                    StatefulBuilder(
                      builder: (context, setDropState) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white),
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
                                    () => _selectedCategory = val);
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveTransaction,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Simpan Transaksi',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _exampleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}