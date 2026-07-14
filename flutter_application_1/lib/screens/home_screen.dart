import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'history_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];

/// หน้า Home (3.4.6) - แสดงภาพรวมทางการเงินของผู้ใช้งาน
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final summary = service.monthlySummary(months: 6);
    final maxVal = summary
        .map((e) => e.value['expense'] ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text('สวัสดี, ${service.currentUser?.name ?? 'ผู้ใช้งาน'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _summaryCard('รายรับรวม', service.totalIncome,
                        Colors.green.shade100, Colors.green.shade800)),
                const SizedBox(width: 12),
                Expanded(
                    child: _summaryCard('รายจ่ายรวม', service.totalExpense,
                        Colors.red.shade100, Colors.red.shade800)),
              ],
            ),
            const SizedBox(height: 12),
            _summaryCard('คงเหลือสุทธิ', service.balance,
                Colors.blueGrey.shade100, Colors.blueGrey.shade800,
                fullWidth: true),
            const SizedBox(height: 24),
            const Text('Total Expenses (6 เดือนล่าสุด)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxVal == 0 ? 100 : maxVal * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= summary.length) {
                            return const SizedBox.shrink();
                          }
                          final month = summary[idx].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_thaiMonthsShort[month.month - 1],
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(summary.length, (i) {
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: summary[i].value['expense'] ?? 0,
                        color: Colors.deepPurple.shade300,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Exchange Rate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: const [
                    _RateRow(flag: '🇺🇸', code: 'USD', buy: '31.55', sell: '31.75'),
                    _RateRow(flag: '🇪🇺', code: 'EUR', buy: '36.60', sell: '36.90'),
                    _RateRow(flag: '🇬🇧', code: 'GBP', buy: '42.20', sell: '42.55'),
                    _RateRow(flag: '🇯🇵', code: 'JPY', buy: '0.2000', sell: '0.2015'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _summaryCard(String title, double value, Color bg, Color fg,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: fg, fontSize: 13)),
          const SizedBox(height: 6),
          Text('฿${value.toStringAsFixed(2)}',
              style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String flag, code, buy, sell;
  const _RateRow({required this.flag, required this.code, required this.buy, required this.sell});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$flag  $code'),
          const Spacer(),
          Text('ซื้อ $buy'),
          const SizedBox(width: 12),
          Text('ขาย $sell'),
        ],
      ),
    );
  }
}
