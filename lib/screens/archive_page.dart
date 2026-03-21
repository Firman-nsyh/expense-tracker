import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../models/transaction_model.dart';
import '../services/sync_service.dart';

class ArchivePageContent extends StatefulWidget {
  const ArchivePageContent({super.key});
  @override
  State<ArchivePageContent> createState() => ArchivePageState();
}

class ArchivePageState extends State<ArchivePageContent> {
  void reload() => _loadData();
  List<Map<String, dynamic>> _availableMonths = [];
  bool _isLoading = true;
  bool _isExporting = false;

  static const _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Tunggu sampai proses sinkronisasi dari Firebase selesai
    while (SyncService.instance.isSyncing) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final months = await DatabaseHelper.instance.getAvailableMonths();

    if (mounted) {
      setState(() {
        _availableMonths = months;
        _isLoading = false;
      });
    }
  }

  String _formatTotal(dynamic total) {
    final amount = (total as num).toDouble();
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'Rp $formatted';
  }

  Future<void> _exportMonth(int year, int month) async {
    setState(() => _isExporting = true);
    try {
      final transactions = await DatabaseHelper.instance.getTransactionsByMonth(year, month);
      if (transactions.isEmpty) {
        _showSnack("Tidak ada data untuk bulan ini", isError: true);
        return;
      }
      final fileName = ExportService.monthlyFileName(year, month);
      final path = await ExportService.instance.exportToExcel(
          transactions: transactions, fileName: fileName);
      if (path != null) {
        _showSnack("✅ File disimpan dan dibuka");
      } else {
        _showSnack("Gagal mengekspor file", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAll() async {
    setState(() => _isExporting = true);
    try {
      final transactions = await DatabaseHelper.instance.getAllTransactions();
      if (transactions.isEmpty) {
        _showSnack("Belum ada data transaksi", isError: true);
        return;
      }
      final fileName = ExportService.allDataFileName();
      final path = await ExportService.instance.exportToExcel(
          transactions: transactions, fileName: fileName);
      if (path != null) {
        _showSnack("✅ Semua data berhasil diekspor");
      } else {
        _showSnack("Gagal mengekspor file", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Arsip Data",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("Kelola & Download Laporan",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.refresh, color: Colors.greenAccent),
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.table_view, color: Colors.greenAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text("Export Semua Data",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Format .xlsx (Excel) kompatibel",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 20),
                  _isExporting
                      ? const CircularProgressIndicator(color: Colors.greenAccent)
                      : ElevatedButton.icon(
                          onPressed: _exportAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text("Download Sekarang"),
                        )
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text("Riwayat Bulanan",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                : _availableMonths.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                          child: Column(children: [
                            Icon(Icons.inbox, color: Colors.white24, size: 40),
                            SizedBox(height: 12),
                            Text("Belum ada data laporan",
                                style: TextStyle(color: Colors.white38)),
                          ]),
                        ),
                      )
                    : Column(
                        children: _availableMonths.map((item) {
                          final year  = int.parse(item['year'].toString());
                          final month = int.parse(item['month'].toString());
                          final count = item['count'] as int;
                          final total = item['total'];
                          return Column(children: [
                            _buildArchiveItem(
                              title: 'Laporan ${_monthNames[month]} $year',
                              subtitle: '${_formatTotal(total)} • $count Transaksi',
                              onDownload: () => _exportMonth(year, month),
                            ),
                            const SizedBox(height: 12),
                          ]);
                        }).toList(),
                      ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveItem({
    required String title,
    required String subtitle,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.description, color: Colors.green, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12))
        ])),
        _isExporting
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
            : IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.white70),
                onPressed: onDownload,
              )
      ]),
    );
  }
}