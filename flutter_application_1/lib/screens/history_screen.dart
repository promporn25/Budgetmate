import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';

/// หน้า History (3.4.7) - แสดงประวัติการทำรายการ พร้อมตัวกรอง All / Daily
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final all = service.transactions;
    final today = DateTime.now();
    final list = _showAll ? all : service.transactionsForDay(today);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _filterChip('All', _showAll, () => setState(() => _showAll = true)),
                const SizedBox(width: 8),
                _filterChip('Daily', !_showAll, () => setState(() => _showAll = false)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, text: 'ยังไม่มีรายการ')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = list[index];
                      return _transactionTile(context, t, service);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : AppColors.surface,
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

  Widget _transactionTile(
      BuildContext context, TransactionModel t, DataService service) {
    final isIncome = t.type == CategoryType.income;
    return Dismissible(
      key: ValueKey(t.id),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) async => service.deleteTransaction(t.id),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
            child: Icon(t.category.icon,
                color: isIncome ? AppColors.income : AppColors.expense),
          ),
          title: Text(t.category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${DateFormat('d MMM yyyy').format(t.date)}${t.note != null ? ' • ${t.note}' : ''}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: Text(
            '${isIncome ? '+' : '-'}฿${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}