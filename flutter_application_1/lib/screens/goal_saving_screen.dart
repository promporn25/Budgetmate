import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_goal_saving_screen.dart';

/// หน้า Goal Saving (3.4.11) - กำหนดและติดตามเป้าหมายการออมเงิน
class GoalSavingScreen extends StatelessWidget {
  const GoalSavingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Goal Saving')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet),
                    SizedBox(width: 8),
                    Text('BUDGETMATE\nLedger Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('฿${service.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: service.goals.length,
            itemBuilder: (context, i) {
              final g = service.goals[i];
              return Dismissible(
                key: ValueKey(g.id),
                onDismissed: (_) => service.deleteGoal(g.id),
                background: Container(color: Colors.red),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(g.icon, color: Colors.deepPurple),
                      const SizedBox(height: 6),
                      Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text('฿${g.targetAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: g.progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade300,
                          color: g.progress >= 1 ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddGoalSavingScreen())),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
