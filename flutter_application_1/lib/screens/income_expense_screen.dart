import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';

const _palette = [
  Colors.deepPurple, Colors.orange, Colors.teal, Colors.pink,
  Colors.indigo, Colors.brown, Colors.cyan, Colors.lime,
];

/// หน้า Income/Expense (3.4.9) - แสดงสัดส่วนรายจ่ายแบบ Pie Chart และประวัติรายวัน
class IncomeExpenseScreen extends StatefulWidget {
  const IncomeExpenseScreen({super.key});

  @override
  State<IncomeExpenseScreen> createState() => _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends State<IncomeExpenseScreen> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final byCategory = service.expenseByCategory();
    final entries = byCategory.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    final today = DateTime.now();
    final list = _showAll ? service.transactions : service.transactionsForDay(today);

    return Scaffold(
      appBar: AppBar(title: const Text('Income/Expense')),
      body: Column(
        children: [
          if (entries.isNotEmpty)
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: List.generate(entries.length, (i) {
                          final e = entries[i];
                          final pct = total == 0 ? 0 : (e.value / total) * 100;
                          return PieChartSectionData(
                            color: _palette[i % _palette.length],
                            value: e.value,
                            title: '${pct.toStringAsFixed(0)}%',
                            radius: 60,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 11),
                          );
                        }),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                  width: 10, height: 10,
                                  color: _palette[i % _palette.length]),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(entries[i].key.name,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('ยังไม่มีข้อมูลรายจ่าย'),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _filterChip('All', _showAll, () => setState(() => _showAll = true)),
                const SizedBox(width: 8),
                _filterChip('Daily', !_showAll, () => setState(() => _showAll = false)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('ยังไม่มีรายการ'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final t = list[i];
                      final isIncome = t.type == CategoryType.income;
                      return ListTile(
                        leading: Icon(t.category.icon,
                            color: isIncome ? Colors.green : Colors.red),
                        title: Text(t.category.name),
                        subtitle: Text(DateFormat('d MMM yyyy').format(t.date)),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}฿${t.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: isIncome ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black, fontSize: 12)),
      ),
    );
  }
}
