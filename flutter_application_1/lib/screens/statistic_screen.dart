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
      appBar: AppBar(title: const Text('Statistic')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Income / Expense',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.blue,
                      dotData: const FlDotData(show: false),
                      spots: List.generate(summary.length,
                          (i) => FlSpot(i.toDouble(), summary[i].value['income'] ?? 0)),
                    ),
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.redAccent,
                      dotData: const FlDotData(show: false),
                      spots: List.generate(summary.length,
                          (i) => FlSpot(i.toDouble(), summary[i].value['expense'] ?? 0)),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _legendDot(Colors.blue, 'รายรับ ${pct['income']!.toStringAsFixed(0)}%'),
                const SizedBox(width: 16),
                _legendDot(Colors.redAccent, 'รายจ่าย ${pct['expense']!.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 8),
            if (mostSpent != null)
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: Icon(mostSpent.key.icon),
                  title: const Text('หมวดหมู่ที่ใช้จ่ายมากที่สุด'),
                  subtitle: Text(mostSpent.key.name),
                  trailing: Text('฿${mostSpent.value.toStringAsFixed(0)}'),
                ),
              ),
            const SizedBox(height: 24),
            const Text('Goal Saving',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...service.goals.map((g) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(g.icon, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(g.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Text('${(g.progress * 100).toStringAsFixed(0)}%'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: g.progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: g.progress >= 1 ? Colors.green : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '฿${g.savedAmount.toStringAsFixed(0)} / ฿${g.targetAmount.toStringAsFixed(0)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        if (g.isNearTarget)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('🔔 ใกล้ถึงเป้าหมายแล้ว!',
                                style: TextStyle(color: Colors.orange, fontSize: 12)),
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
