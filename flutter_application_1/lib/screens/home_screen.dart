import 'package:budgetmate/screens/app_theme.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text('สวัสดี, ${service.currentUser?.name ?? 'ผู้ใช้งาน'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
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
                        AppColors.incomeBg, AppColors.income, Icons.arrow_downward_rounded)),
                const SizedBox(width: 12),
                Expanded(
                    child: _summaryCard('รายจ่ายรวม', service.totalExpense,
                        AppColors.expenseBg, AppColors.expense, Icons.arrow_upward_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('คงเหลือสุทธิ',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('฿${service.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Total Expenses (6 เดือนล่าสุด)', style: AppTextStyles.heading),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
              child: SizedBox(
                height: 200,
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
                          color: Colors.orange.shade400,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ]);
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Exchange Rate', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: const [
                  _RateRow(flag: '🇺🇸', code: 'USD', buy: '31.55', sell: '31.75'),
                  _RateRow(flag: '🇪🇺', code: 'EUR', buy: '36.60', sell: '36.90'),
                  _RateRow(flag: '🇬🇧', code: 'GBP', buy: '42.20', sell: '42.55'),
                  _RateRow(flag: '🇯🇵', code: 'JPY', buy: '0.2000', sell: '0.2015'),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _summaryCard(String title, double value, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: fg, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text('฿${value.toStringAsFixed(2)}',
              style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('ซื้อ $buy', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(width: 12),
          Text('ขาย $sell', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
        ],
      ),
    );
  }
}