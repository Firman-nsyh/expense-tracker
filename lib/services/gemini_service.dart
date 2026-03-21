import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/transaction_model.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  GenerativeModel? _model;
  String? _apiKey;

  void init() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    print('🔵 API Key length: ${_apiKey!.length}');
    if (_apiKey!.isEmpty) {
      print('🔴 GEMINI_API_KEY tidak ditemukan di .env');
      return;
    }
    
    // ---> PERBAIKAN: Gunakan model Lite yang bebas limit kuota 0 <---
    _model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: _apiKey!,
    );
    print('🟢 Gemini siap dengan model gemini-flash-lite-latest');
  }

  bool get isReady => _model != null;

  // Cek model apa saja yang tersedia
  Future<void> listAvailableModels() async {
    if (_apiKey == null || _apiKey!.isEmpty) return;
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      client.close();

      // Parse dan print hanya nama model
      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = json['models'] as List<dynamic>? ?? [];
      print('🔵 Daftar model tersedia:');
      for (final m in models) {
        final name = m['name'];
        final methods = m['supportedGenerationMethods'] as List<dynamic>? ?? [];
        if (methods.contains('generateContent')) {
          print('  ✅ $name');
        }
      }
    } catch (e) {
      print('🔴 List models error: $e');
    }
  }

  Future<List<ReceiptItem>> parseReceiptText(String receiptText) async {
    // List models dulu untuk debug
    await listAvailableModels();

    if (!isReady) {
      print('🔴 Gemini belum diinisialisasi');
      return [];
    }
    if (receiptText.trim().isEmpty) return [];

    final prompt = '''
Kamu adalah asisten pencatatan keuangan. Analisis teks struk belanja berikut.

Tugas kamu:
1. Kelompokkan semua item ke dalam kategori yang sesuai
2. Hitung total harga per kategori
3. Tentukan nama toko jika ada

Kategori yang tersedia:
- Makanan & Minuman (makanan, minuman, snack, cemilan, buah)
- Belanja (deterjen, sabun, shampoo, kebutuhan rumah, alat tulis)
- Kesehatan (obat, vitamin, masker, alat kesehatan)
- Lainnya (item yang tidak masuk kategori lain)

TEKS STRUK:
$receiptText

Balas HANYA dengan JSON valid, tanpa penjelasan, tanpa markdown, tanpa backtick.
Format JSON:
{
  "toko": "nama toko atau kosong jika tidak ada",
  "items": [
    {
      "kategori": "nama kategori",
      "deskripsi": "ringkasan item dalam kategori ini",
      "total": 50000
    }
  ]
}

Penting:
- total harus berupa angka (integer), bukan string
- Jika tidak bisa membaca total dengan pasti, gunakan 0
- Gabungkan item sejenis dalam satu kategori
- Maksimal 4 kategori
''';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('🔵 Mengirim ke Gemini (percobaan $attempt)...');
        final content = [Content.text(prompt)];
        final response = await _model!.generateContent(content);
        final text = response.text ?? '';
        print('🟢 Response Gemini: $text');
        return _parseGeminiResponse(text);
      } catch (e) {
        final errorStr = e.toString();
        print('🔴 Gemini error (percobaan $attempt): $e');
        if (errorStr.contains('quota') || errorStr.contains('429') ||
            errorStr.contains('SocketException')) {
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 10));
            continue;
          }
        }
        return [];
      }
    }
    return [];
  }

  List<ReceiptItem> _parseGeminiResponse(String responseText) {
    try {
      String clean = responseText
          .replaceAll('```json', '').replaceAll('```', '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return [];
      clean = clean.substring(start, end + 1);

      final items = <ReceiptItem>[];
      final tokoMatch = RegExp(r'"toko"\s*:\s*"([^"]*)"').firstMatch(clean);
      final toko = tokoMatch?.group(1) ?? '';

      final itemsMatch = RegExp(
        r'"kategori"\s*:\s*"([^"]*)"\s*,\s*"deskripsi"\s*:\s*"([^"]*)"\s*,\s*"total"\s*:\s*(\d+)',
      ).allMatches(clean);

      for (final match in itemsMatch) {
        final kategori = match.group(1) ?? 'Lainnya';
        final deskripsi = match.group(2) ?? '';
        final totalStr = match.group(3)?.replaceAll('.', '') ?? '0';
        final total = double.tryParse(totalStr) ?? 0;
        final validKategori = TransactionCategory.all.contains(kategori)
            ? kategori : 'Lainnya';
        String desc = deskripsi.isNotEmpty ? deskripsi : kategori;
        if (toko.isNotEmpty) desc = '$desc ($toko)';
        items.add(ReceiptItem(kategori: validKategori, deskripsi: desc, total: total));
      }
      print('🟢 Parsed ${items.length} item dari struk');
      return items;
    } catch (e) {
      print('🔴 Parse error: $e');
      return [];
    }
  }
}

class ReceiptItem {
  final String kategori;
  final String deskripsi;
  final double total;
  ReceiptItem({required this.kategori, required this.deskripsi, required this.total});
}