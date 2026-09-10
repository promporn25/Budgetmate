import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_goal_saving_screen.dart';

// ชุดสีพาสเทลสลับให้การ์ดเป้าหมายแต่ละใบมีโทนต่างกัน (ไม่จืดซ้ำสีเดียวทั้งกริด)
const List<Color> _goalTint = [
  Color(0xFFDCEEF7), // ฟ้าอ่อน
  Color(0xFFFBEED0), // เหลืองพีชอ่อน
  Color(0xFFF6E1E7), // ชมพูอ่อน
  Color(0xFFE1EFF8), // ฟ้ากลางอ่อน
  Color(0xFFE8F3E3), // มินต์อ่อน
  Color(0xFFEFE7FA), // ม่วงลาเวนเดอร์อ่อน
];
const List<Color> _goalTintDeep = [
  Color(0xFF3D568F),
  Color(0xFFC79A3B),
  Color(0xFFC08B9D),
  Color(0xFF5C86C4),
  Color(0xFF4E9B6E),
  Color(0xFF8B6FC4),
];

/// หน้า Goal Saving (3.4.11) - กำหนดและติดตามเป้าหมายการออมเงิน
class GoalSavingScreen extends StatelessWidget {
  const GoalSavingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(service.t('goal_saving'),
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            const Text('', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      // ห่อด้วย RefreshIndicator กันไม่ให้ดึงหน้าจอเกินขอบบนแล้วเห็นพื้นที่ว่างสีขาว
      body: RefreshIndicator(
        color: AppColors.accentDeep,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await refreshAppData(context);
        },
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentDeep, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDeep.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -20,
                    top: -26,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                    ),
                  ),
                  Positioned(
                    right: 30,
                    bottom: -30,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.account_balance_wallet_rounded,
                                color: AppColors.accentDeep, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(service.t('ledger_balance'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(service.formatMoney(service.balance),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (service.goals.isEmpty)
            EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
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
                  confirmDismiss: (_) async {
                    try {
                      await service.deleteGoal(g.id);
                      return true;
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${service.t('save_failed')}: $e')));
                      return false;
                    }
                  },
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  child: _GoalCard(
                    goal: g,
                    tint: _goalTint[i % _goalTint.length],
                    tintDeep: _goalTintDeep[i % _goalTintDeep.length],
                    onTap: () => _showDepositDialog(context, g),
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentDeep,
        elevation: 0,
        onPressed: () => Navigator.push(context,
            noAnimationRoute(const AddGoalSavingScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}

/// การ์ดเป้าหมายการออมแบบพาสเทลน่ารัก
class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final Color tint;
  final Color tintDeep;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.tint,
    required this.tintDeep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = goal.status == GoalStatus.completed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: tintDeep.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -14,
                top: -18,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: tintDeep.withOpacity(0.10), shape: BoxShape.circle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: GoalArtwork(goal.icon, color: tintDeep, size: 17),
                        ),
                        const Spacer(),
                        if (completed)
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                        else if (goal.isNearTarget)
                          Icon(Icons.star_rounded, color: tintDeep.withOpacity(0.8), size: 18)
                        else
                          Icon(Icons.add_circle_outline_rounded, color: tintDeep, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(goal.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('${context.watch<DataService>().formatMoney(goal.savedAmount)} / ${context.watch<DataService>().formatMoney(goal.targetAmount)}',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 7,
                        backgroundColor: Colors.white.withOpacity(0.7),
                        color: goal.progress >= 1 ? AppColors.success : tintDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// เปิด dialog ให้ผู้ใช้กรอกจำนวนเงินที่ต้องการ "โอนเงินจริง" เข้าเป้าหมาย [goal]
Future<void> _showDepositDialog(BuildContext context, GoalModel goal) async {
  final service = context.read<DataService>();
  final controller = TextEditingController();
  final remaining = (goal.targetAmount - goal.savedAmount).clamp(0, goal.targetAmount).toDouble();
  final maxTransferable = remaining < service.balance ? remaining : service.balance;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (dialogContext) {
      bool submitting = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void applyQuickAmount(double value) {
            if (value <= 0) return;
            controller.text = value == value.roundToDouble()
                ? value.toStringAsFixed(0)
                : value.toStringAsFixed(2);
            controller.selection =
                TextSelection.collapsed(offset: controller.text.length);
            setState(() => errorText = null);
          }

          Future<void> submit() async {
            final amount = double.tryParse(controller.text.trim()) ?? 0;
            if (amount <= 0) {
              setState(() => errorText = service.t('enter_valid_amount'));
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
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDeep.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentDeep, AppColors.accent],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: GoalArtwork(goal.icon, color: AppColors.accentDeep, size: 25),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(service.t('deposit_title'),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(goal.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: submitting ? null : () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: goal.progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.35),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${context.watch<DataService>().formatMoney(goal.savedAmount)} / ${context.watch<DataService>().formatMoney(goal.targetAmount)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _InfoStat(
                                icon: Icons.account_balance_wallet_rounded,
                                label: service.t('ledger_remaining'),
                                value: service.formatMoney(service.balance),
                                bg: AppColors.accentBg,
                                iconColor: AppColors.accentDeep,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoStat(
                                icon: Icons.flag_rounded,
                                label: service.t('needed_more'),
                                value: service.formatMoney(remaining),
                                bg: AppColors.accentAltBg,
                                iconColor: const Color(0xFFC79A3B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(service.t('deposit_title'),
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: controller,
                          hint: '0.00',
                          autofocus: true,
                          prefixText: '${service.currentCurrency} ',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          errorText: errorText,
                          onChanged: (_) {
                            if (errorText != null) setState(() => errorText = null);
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (maxTransferable > 0) ...[
                              _QuickAmountChip(
                                label: service.t('quarter'),
                                onTap: () => applyQuickAmount(maxTransferable * 0.25),
                              ),
                              _QuickAmountChip(
                                label: service.t('half'),
                                onTap: () => applyQuickAmount(maxTransferable * 0.5),
                              ),
                              _QuickAmountChip(
                                label: service.t('full_remaining'),
                                icon: Icons.bolt_rounded,
                                onTap: () => applyQuickAmount(maxTransferable.toDouble()),
                                emphasized: true,
                              ),
                            ] else
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 15, color: AppColors.danger),
                                  const SizedBox(width: 6),
                                  Text(service.t('insufficient_balance'),
                                      style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: AppColors.border, width: 1.3),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                                ),
                                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                                child: Text(service.t('cancel'),
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  gradient: LinearGradient(
                                    colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.82)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentDeep.withOpacity(0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                                  ),
                                  onPressed: submitting ? null : submit,
                                  child: submitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.savings_rounded, size: 18, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text(service.t('transfer'),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// การ์ดข้อมูลเล็กๆ (Ledger คงเหลือ / ต้องการอีก)
class _InfoStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color iconColor;

  const _InfoStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// ชิปเลือกจำนวนเงินด่วน (25% / 50% / เต็มจำนวนที่ขาด)
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final IconData? icon;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.accentDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: emphasized ? Colors.white : AppColors.accentDeep),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: emphasized ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}