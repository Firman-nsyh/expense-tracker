import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});
  @override
  State<HomePageContent> createState() => HomePageState();
}

class HomePageState extends State<HomePageContent> {
  // Method publik agar bisa dipanggil dari main_screen.dart
  void reload() => _loadData();
  String _selectedFilter = 'Bulan Ini';
  double _totalAmount = 0;
  List<TransactionModel> _recentTransactions = [];
  Map<int, double> _monthlyTotals = {for (var i = 1; i <= 12; i++) i: 0.0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final total = _selectedFilter == 'Bulan Ini'
        ? await db.getTotalThisMonth()
        : await db.getTotalThisWeek();
    final all = await db.getAllTransactions();
    final monthly = await db.getMonthlyTotals(DateTime.now().year);
    if (mounted) {
      setState(() {
        _totalAmount = total;
        _recentTransactions = all.take(5).toList();
        _monthlyTotals = monthly;
        _isLoading = false;
      });
    }
  }

  void _toggleFilter() async {
    setState(() {
      _selectedFilter = _selectedFilter == 'Bulan Ini' ? 'Minggu Ini' : 'Bulan Ini';
    });
    await _loadData();
  }

  String get _displayAmount {
    final formatted = _totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.white,
        backgroundColor: const Color(0xFF1A1A1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildExpenseCard(),
              const SizedBox(height: 24),
              _buildChartHeader(),
              const SizedBox(height: 16),
              _buildYearlyChart(),
              const SizedBox(height: 32),
              _buildTransactionHeader(),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                  : _buildTransactionList(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fullName = AuthService.instance.displayName;
    final firstName = fullName.isNotEmpty ? fullName.split(' ')[0] : 'Pengguna';
    final photoUrl = AuthService.instance.photoUrl ?? 'https://i.pravatar.cc/300';
    final isLoggedIn = AuthService.instance.isLoggedIn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Halo, $firstName!",
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Row(children: [
            Icon(
              isLoggedIn ? Icons.cloud_done : Icons.cloud_off,
              size: 14,
              color: isLoggedIn ? Colors.greenAccent : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              isLoggedIn ? "Data Tersinkronisasi" : "Mode Offline",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            )
          ])
        ]),
        CircleAvatar(radius: 24, backgroundImage: NetworkImage(photoUrl))
      ],
    );
  }

  Widget _buildExpenseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF151515)]),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Text("Total Pengeluaran",
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          InkWell(
              onTap: _toggleFilter,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    Text(_selectedFilter,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16)
                  ])))
        ]),
        const SizedBox(height: 24),
        _isLoading
            ? const SizedBox(
                height: 44,
                child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)))
            : Text(_displayAmount,
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildChartHeader() => const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Statistik Tahunan",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Icon(Icons.bar_chart, color: Colors.white54, size: 20)
        ],
      );

  Widget _buildYearlyChart() {
    final maxVal = _monthlyTotals.values.isEmpty
        ? 1.0
        : _monthlyTotals.values.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal == 0 ? 10.0 : maxVal * 1.2;
    const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white10)),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMax,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = group.x + 1;
              final val = _monthlyTotals[month] ?? 0;
              final formatted = val.toStringAsFixed(0).replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
              return BarTooltipItem(
                  'Rp $formatted', const TextStyle(color: Colors.white, fontSize: 11));
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(monthLabels[val.toInt()],
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          final month = i + 1;
          final value = _monthlyTotals[month] ?? 0;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: value,
              color: Colors.transparent,
              gradient: const LinearGradient(
                  colors: [Color(0xFF60EFFF), Color(0xFF0061FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              width: 12,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                  show: true, toY: chartMax, color: Colors.white.withOpacity(0.05)),
            )
          ]);
        }),
      )),
    );
  }

  Widget _buildTransactionHeader() => const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Transaksi Terakhir",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Icon(Icons.arrow_forward, color: Colors.white54, size: 20)
        ],
      );

  Widget _buildTransactionList() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: const Center(
          child: Column(children: [
            Icon(Icons.receipt_long, color: Colors.white24, size: 40),
            SizedBox(height: 12),
            Text("Belum ada transaksi", style: TextStyle(color: Colors.white38)),
            Text("Tekan + untuk menambah",
                style: TextStyle(color: Colors.white24, fontSize: 12)),
          ]),
        ),
      );
    }

    return Column(
      children: _recentTransactions.asMap().entries.map((entry) {
        final t = entry.value;
        final isLast = entry.key == _recentTransactions.length - 1;
        return Column(children: [
          _transactionItem(t),
          if (!isLast) const SizedBox(height: 12),
        ]);
      }).toList(),
    );
  }

  Widget _transactionItem(TransactionModel t) {
    final emoji = TransactionCategory.iconForCategory(t.category);
    return Dismissible(
      key: Key(t.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) async {
        await DatabaseHelper.instance.deleteTransaction(t.id!);
        await SyncService.instance.deleteOne(t.id!);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.description,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            Text(t.formattedDate,
                style: TextStyle(color: Colors.grey[500], fontSize: 12))
          ])),
          Text(t.formattedAmount,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))
        ]),
      ),
    );
  }
}