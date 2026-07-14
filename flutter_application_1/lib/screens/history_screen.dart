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
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
                ? const Center(child: Text('ยังไม่มีรายการ'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget _transactionTile(
      BuildContext context, TransactionModel t, DataService service) {
    final isIncome = t.type == CategoryType.income;
    return Dismissible(
      key: ValueKey(t.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => service.deleteTransaction(t.id),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
            child: Icon(t.category.icon,
                color: isIncome ? Colors.green.shade800 : Colors.red.shade800),
          ),
          title: Text(t.category.name),
          subtitle: Text(
              '${DateFormat('d MMM yyyy').format(t.date)}${t.note != null ? ' • ${t.note}' : ''}'),
          trailing: Text(
            '${isIncome ? '+' : '-'}฿${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
