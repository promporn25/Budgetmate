import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'income_expense_screen.dart';
import 'goal_saving_screen.dart';

/// หน้า Wallet - ภาพรวมกระเป๋าเงิน, รายรับ-รายจ่าย และเป้าหมายการออม
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('BUDGETMATE WALLET',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ยอดคงเหลือรวม', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('฿${service.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const IncomeExpenseScreen())),
            child: _sectionCard(
              title: 'Income/Expense',
              child: Row(
                children: [
                  Expanded(
                      child: _miniStat('รายรับ', service.totalIncome, Colors.green)),
                  Expanded(
                      child: _miniStat('รายจ่าย', service.totalExpense, Colors.red)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const GoalSavingScreen())),
            child: _sectionCard(
              title: 'Goal Saving',
              child: Text('${service.goals.length} เป้าหมายที่กำลังดำเนินการ'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        Text('฿${value.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
