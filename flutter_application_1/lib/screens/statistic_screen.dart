import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';

/// หน้า Statistic (3.4.8) - วิเคราะห์แนวโน้มรายรับ/รายจ่าย และความคืบหน้าการออม
class StatisticScreen extends StatelessWidget {
  const StatisticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final summary = service.monthlySummary(months: 7);
    final mostSpent = service.mostSpentCategory;
    final pct = service.incomeExpensePercentage;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Statistic', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Income / Expense', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            spots: List.generate(summary.length,
                                (i) => FlSpot(i.toDouble(), summary[i].value['income'] ?? 0)),
                          ),
                          LineChartBarData(
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            spots: List.generate(summary.length,
                                (i) => FlSpot(i.toDouble(), summary[i].value['expense'] ?? 0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendDot(Colors.blue, 'รายรับ ${pct['income']!.toStringAsFixed(0)}%'),
                      const SizedBox(width: 16),
                      _legendDot(Colors.orange, 'รายจ่าย ${pct['expense']!.toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (mostSpent != null)
              AppCard(
                color: Colors.amber.shade50,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(mostSpent.key.icon, color: Colors.amber.shade800),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('หมวดหมู่ที่ใช้จ่ายมากที่สุด',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(mostSpent.key.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    Text('฿${mostSpent.value.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            const Text('Goal Saving', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            if (service.goals.isEmpty)
              const EmptyState(icon: Icons.savings_outlined, text: 'ยังไม่มีเป้าหมายการออม')
            else
              ...service.goals.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(g.icon, color: Colors.amber.shade800, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(g.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Text('${(g.progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 9,
                              backgroundColor: Colors.grey.shade200,
                              color: g.progress >= 1 ? AppColors.success : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '฿${g.savedAmount.toStringAsFixed(0)} / ฿${g.targetAmount.toStringAsFixed(0)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (g.isNearTarget)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('🔔 ใกล้ถึงเป้าหมายแล้ว!',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}