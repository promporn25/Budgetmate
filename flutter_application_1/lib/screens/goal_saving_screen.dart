import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Goal Saving', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.orange.shade700, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('BUDGETMATE\nLedger Balance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('฿${service.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (service.goals.isEmpty)
            const EmptyState(icon: Icons.savings_outlined, text: 'ยังไม่มีเป้าหมายการออม')
          else
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
                  onDismissed: (_) async => service.deleteGoal(g.id),
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  child: GestureDetector(
                    onTap: () => _showDepositDialog(context, g),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(g.icon, color: Colors.deepPurple, size: 18),
                              ),
                              const Spacer(),
                              if (g.status == GoalStatus.completed)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 18)
                              else
                                Icon(Icons.add_circle_outline_rounded,
                                    color: Colors.deepPurple, size: 18),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(g.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text('฿${g.savedAmount.toStringAsFixed(0)} / ฿${g.targetAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 7,
                              backgroundColor: Colors.grey.shade300,
                              color: g.progress >= 1 ? AppColors.success : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        elevation: 0,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddGoalSavingScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}

/// เปิด dialog ให้ผู้ใช้กรอกจำนวนเงินที่ต้องการ "โอนเงินจริง" เข้าเป้าหมาย [goal]
/// เมื่อกดยืนยัน จะเรียก [DataService.transferToGoal] ซึ่งหักยอดจาก Ledger Balance
/// (บันทึกเป็นรายจ่ายอัตโนมัติ) และเพิ่มยอดออมสะสมของเป้าหมายพร้อมกัน
Future<void> _showDepositDialog(BuildContext context, GoalModel goal) async {
  final service = context.read<DataService>();
  final controller = TextEditingController();
  final remaining = (goal.targetAmount - goal.savedAmount).clamp(0, goal.targetAmount);

  await showDialog(
    context: context,
    builder: (dialogContext) {
      bool submitting = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text('เติมเงินเข้า "${goal.name}"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ledger Balance คงเหลือ: ฿${service.balance.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                Text('ต้องการอีก: ฿${remaining.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '฿ ',
                    labelText: 'จำนวนเงินที่จะโอน',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        final amount = double.tryParse(controller.text.trim()) ?? 0;
                        if (amount <= 0) {
                          setState(() => errorText = 'กรุณากรอกจำนวนเงินให้ถูกต้อง');
                          return;
                        }
                        setState(() {
                          submitting = true;
                          errorText = null;
                        });
                        final error = await service.transferToGoal(goal.id, amount);
                        if (error != null) {
                          setState(() {
                            submitting = false;
                            errorText = error;
                          });
                          return;
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                child: submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('โอนเงิน'),
              ),
            ],
          );
        },
      );
    },
  );
}