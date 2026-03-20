class TransactionModel {
  final int? id;
  final double amount;
  final String description;
  final String category;
  final DateTime date;
  final String inputMethod; // 'manual', 'voice', 'scan'

  TransactionModel({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.inputMethod = 'manual',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'inputMethod': inputMethod,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount'],
      description: map['description'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      inputMethod: map['inputMethod'] ?? 'manual',
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txDate).inDays;
    if (diff == 0) return 'Hari ini, ${_formatTime(date)}';
    if (diff == 1) return 'Kemarin';
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month];
  }

  String get formattedAmount {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '- Rp $formatted';
  }
}

class TransactionCategory {
  static const List<String> all = [
    'Makanan & Minuman',
    'Transportasi',
    'Belanja',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Tagihan',
    'Lainnya',
  ];

  static String iconForCategory(String category) {
    switch (category) {
      case 'Makanan & Minuman': return '🍔';
      case 'Transportasi':      return '⛽';
      case 'Belanja':           return '🛒';
      case 'Hiburan':           return '🎬';
      case 'Kesehatan':         return '💊';
      case 'Pendidikan':        return '📚';
      case 'Tagihan':           return '💡';
      default:                  return '💰';
    }
  }
}