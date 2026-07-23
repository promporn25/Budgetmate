import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';


const _palette = [
  Colors.deepPurple, Colors.orange, Colors.teal, Colors.pink,
  Colors.indigo, Colors.brown, Colors.cyan, Colors.lime,
];

/// วิดเจ็ตแสดง Pie Chart สัดส่วนรายจ่าย + ประวัติรายการแบบจัดกลุ่มตามวัน (TODAY/YESTERDAY/...)
/// แยกออกมาจาก [IncomeExpenseScreen] เพื่อให้ฝังใช้ซ้ำได้ทั้งเป็นหน้าเต็มจอ
/// และฝังอยู่ใน AddIncomeExpenseScreen ตอนเลือกแท็บ "Expenses"
class IncomeExpenseOverview extends StatefulWidget {
  const IncomeExpenseOverview({super.key});

  @override
  State<IncomeExpenseOverview> createState() => _IncomeExpenseOverviewState();
}

class _IncomeExpenseOverviewState extends State<IncomeExpenseOverview> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final byCategory = service.expenseByCategory();
    final entries = byCategory.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    final today = DateTime.now();
    final list = _showAll ? service.transactions : service.transactionsForDay(today);

    return Column(
      children: [
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                height: 186,
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
                              radius: 58,
                              titleStyle: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                    width: 9, height: 9,
                                    decoration: BoxDecoration(
                                      color: _palette[i % _palette.length],
                                      shape: BoxShape.circle,
                                    )),
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
              ),
            ),
          )
        else
          const EmptyState(icon: Icons.pie_chart_outline_rounded, text: 'ยังไม่มีข้อมูลรายจ่าย'),
        const SizedBox(height: 6),
        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black26),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('History', style: AppTextStyles.heading),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _segmentOption('All', _showAll, () => setState(() => _showAll = true)),
                      _segmentOption('Daily', !_showAll, () => setState(() => _showAll = false)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, text: 'ยังไม่มีรายการ')
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _buildGroupedHistory(list),
                ),
        ),
      ],
    );
  }

  /// จัดกลุ่มรายการตามวัน แล้วสร้างหัวข้อ TODAY / YESTERDAY / วันที่
  List<Widget> _buildGroupedHistory(List<TransactionModel> list) {
    final widgets = <Widget>[];
    DateTime? currentDay;

    for (final t in list) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (currentDay == null || day != currentDay) {
        if (currentDay != null) widgets.add(const SizedBox(height: 8));
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            _dayLabel(day),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
                color: Colors.grey.shade700),
          ),
        ));
        currentDay = day;
      }
      widgets.add(_historyTile(t));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final yesterday = todayDay.subtract(const Duration(days: 1));
    if (day == todayDay) return 'TODAY';
    if (day == yesterday) return 'YESTERDAY';
    return DateFormat('d MMM yyyy').format(day).toUpperCase();
  }

  Widget _historyTile(TransactionModel t) {
    final isIncome = t.type == CategoryType.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(DateFormat('HH:mm').format(t.date),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const Spacer(),
              Text(
                '${isIncome ? '+' : '-'}฿${t.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.black,
                child: Icon(t.category.icon, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Text(t.category.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmentOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}