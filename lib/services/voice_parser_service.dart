// Service untuk parse hasil speech-to-text menjadi data transaksi
class VoiceParserService {
  static final VoiceParserService instance = VoiceParserService._();
  VoiceParserService._();

  // Parse teks hasil suara → nominal, deskripsi, kategori
  VoiceParseResult parse(String text) {
    final lower = text.toLowerCase().trim();

    final amount = _extractAmount(lower);
    final description = _extractDescription(text, lower);
    final category = _guessCategory(lower);

    return VoiceParseResult(
      amount: amount,
      description: description,
      category: category,
      rawText: text,
    );
  }

  // --- Ekstrak nominal ---
  double _extractAmount(String text) {
    // Ganti kata bilangan ke angka dulu
    String normalized = _wordsToNumbers(text);

    // Cari pola angka (dengan atau tanpa titik/koma)
    final patterns = [
      RegExp(r'(\d+(?:[.,]\d+)*)\s*(?:ribu|rb|k\b)'),   // 50 ribu, 50rb, 50k
      RegExp(r'(\d+(?:[.,]\d+)*)\s*(?:juta|jt\b)'),      // 2 juta, 2jt
      RegExp(r'(\d+(?:[.,]\d+)*)\s*(?:ratus(?:\s*ribu)?)'), // 5 ratus, 5 ratus ribu
      RegExp(r'rp\.?\s*(\d+(?:[.,]\d+)*)'),               // Rp 50.000
      RegExp(r'(\d{4,})'),                                 // angka langsung >= 4 digit
      RegExp(r'(\d+)'),                                    // angka apapun
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final numStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '');
        double value = double.tryParse(numStr) ?? 0;

        // Kalikan sesuai satuan
        if (pattern.pattern.contains('juta') && !pattern.pattern.contains(r'\d{4}')) {
          value *= 1000000;
        } else if (pattern.pattern.contains('ribu') || pattern.pattern.contains('rb') || pattern.pattern.contains(r'k\b')) {
          if (value < 1000) value *= 1000;
        } else if (pattern.pattern.contains('ratus') && !pattern.pattern.contains('ribu')) {
          if (value < 100) value *= 100;
        }

        if (value > 0) return value;
      }
    }
    return 0;
  }

  // --- Konversi kata bilangan ke angka ---
  String _wordsToNumbers(String text) {
    final Map<String, String> wordMap = {
      'satu': '1', 'dua': '2', 'tiga': '3', 'empat': '4', 'lima': '5',
      'enam': '6', 'tujuh': '7', 'delapan': '8', 'sembilan': '9',
      'sepuluh': '10', 'sebelas': '11', 'dua belas': '12',
      'tiga belas': '13', 'empat belas': '14', 'lima belas': '15',
      'dua puluh': '20', 'tiga puluh': '30', 'empat puluh': '40',
      'lima puluh': '50', 'enam puluh': '60', 'tujuh puluh': '70',
      'delapan puluh': '80', 'sembilan puluh': '90',
      'seratus': '100', 'seribu': '1000', 'sejuta': '1000000',
    };

    String result = text;
    // Sort by length descending agar "dua puluh" diproses sebelum "dua"
    final sorted = wordMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in sorted) {
      result = result.replaceAll(word, wordMap[word]!);
    }
    return result;
  }

  // --- Ekstrak deskripsi ---
  String _extractDescription(String original, String lower) {
    // Hapus kata-kata terkait nominal
    final removePatterns = [
      RegExp(r'\b\d+(?:[.,]\d+)*\s*(?:ribu|juta|ratus|rb|jt|k)\b', caseSensitive: false),
      RegExp(r'\brp\.?\s*\d+(?:[.,]\d+)*\b', caseSensitive: false),
      RegExp(r'\b\d{4,}\b'),
      RegExp(r'\b(?:satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh|sebelas|'
             r'dua belas|lima belas|dua puluh|lima puluh|seratus|seribu)\b', caseSensitive: false),
      RegExp(r'\b(?:ribu|juta|ratus|rb|jt|rupiah|rp)\b', caseSensitive: false),
      RegExp(r'\b(?:buat|untuk|dengan|senilai|sebesar|seharga|harga|bayar|beli|aku|saya|ke|di)\b', caseSensitive: false),
    ];

    String desc = original;
    for (final p in removePatterns) {
      desc = desc.replaceAll(p, ' ');
    }

    // Bersihkan spasi berlebih
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Kapitalisasi kata pertama
    if (desc.isNotEmpty) {
      desc = desc[0].toUpperCase() + desc.substring(1);
    }

    return desc.isEmpty ? 'Transaksi' : desc;
  }

  // --- Tebak kategori dari kata kunci ---
  String _guessCategory(String text) {
    final Map<String, List<String>> categoryKeywords = {
      'Makanan & Minuman': [
        'makan', 'minum', 'nasi', 'ayam', 'soto', 'bakso', 'mie', 'kopi',
        'teh', 'jus', 'snack', 'cemilan', 'sarapan', 'makan siang', 'makan malam',
        'warteg', 'resto', 'restoran', 'cafe', 'kantin', 'pizza', 'burger', 'sate',
        'gorengan', 'buah', 'sayur', 'belanja dapur', 'groceries',
      ],
      'Transportasi': [
        'bensin', 'bbm', 'solar', 'pertamax', 'pertalite', 'parkir', 'tol',
        'ojek', 'gojek', 'grab', 'taksi', 'bus', 'angkot', 'kereta', 'mrt',
        'transjakarta', 'motor', 'mobil', 'servis', 'ganti oli', 'ban',
        'bensin motor', 'isi bensin',
      ],
      'Belanja': [
        'belanja', 'beli', 'toko', 'mall', 'supermarket', 'indomaret',
        'alfamart', 'shopee', 'tokopedia', 'lazada', 'baju', 'sepatu',
        'tas', 'pakaian', 'elektronik', 'hp', 'charger', 'aksesoris',
      ],
      'Hiburan': [
        'hiburan', 'nonton', 'bioskop', 'film', 'game', 'netflix', 'spotify',
        'youtube', 'main', 'karaoke', 'wisata', 'jalan', 'liburan', 'tiket',
      ],
      'Kesehatan': [
        'obat', 'apotek', 'dokter', 'rumah sakit', 'rs', 'klinik', 'periksa',
        'kesehatan', 'vitamin', 'suplemen', 'masker', 'konsultasi',
      ],
      'Pendidikan': [
        'buku', 'kursus', 'les', 'sekolah', 'kuliah', 'pendidikan', 'seminar',
        'pelatihan', 'ujian', 'spp', 'ukt', 'alat tulis', 'stationery',
      ],
      'Tagihan': [
        'tagihan', 'listrik', 'air', 'pdam', 'internet', 'wifi', 'pulsa',
        'kuota', 'data', 'telepon', 'cicilan', 'kredit', 'iuran', 'asuransi',
        'pln', 'indihome', 'telkom',
      ],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) return entry.key;
      }
    }
    return 'Lainnya';
  }
}

class VoiceParseResult {
  final double amount;
  final String description;
  final String category;
  final String rawText;

  VoiceParseResult({
    required this.amount,
    required this.description,
    required this.category,
    required this.rawText,
  });

  bool get isValid => amount > 0 && description.isNotEmpty;
}