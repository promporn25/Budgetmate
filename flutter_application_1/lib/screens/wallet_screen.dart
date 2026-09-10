import '../models/goal_model.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'income_expense_screen.dart';
import 'package:budgetmate/screens/income%20expense%20overview.dart' show HistoryFilter;
import 'goal_saving_screen.dart';

/// หน้า Wallet - ภาพรวมกระเป๋าเงิน, รายรับ-รายจ่าย และเป้าหมายการออม
///
/// ดีไซน์ "Pastel Piggy" — ยังคุมโทนสีพาสเทลเดิมของแอปทั้งหมด (AppColors)
/// แต่เพิ่มความน่ารักผ่าน:
/// - การ์ดยอดคงเหลือไล่เฉดสี + ฟองสบู่ตกแต่ง + มาสคอตกระปุกออมสินยิ้ม
/// - หัวข้อมีไอคอน/อิโมจิเล็กๆ ประกอบ ให้ดูอบอุ่นเป็นกันเอง
/// - การ์ดเป้าหมายออมเงินพาสเทล พร้อมป้าย "จำนวนเป้าหมาย" ทรงเม็ดยา
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('wallet_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
          _BalanceCard(service: service),
          const SizedBox(height: 22),
          Row(
            children: [
              CuteMascot(kind: CuteMascotKind.coin, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(service.t('income_expense'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, noAnimationRoute(const IncomeExpenseScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(service.t('history'),
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accentDeep),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context: context,
                  label: service.t('income'),
                  value: service.totalIncome,
                  color: AppColors.income,
                  isIncome: true,
                  filter: HistoryFilter.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  context: context,
                  label: service.t('expense'),
                  value: service.totalExpense,
                  color: AppColors.expense,
                  isIncome: false,
                  filter: HistoryFilter.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GoalPreviewCard(service: service),
          const SizedBox(height: 80),
        ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  /// กล่องสีรายรับ/รายจ่าย แตะเพื่อไปหน้าประวัติ (IncomeExpenseScreen)
  /// ดีไซน์น่ารัก: พื้นพาสเทลนวล + ฟองสบู่ตกแต่งมุม + มาสคอตตัวโตในวงกลมยิ้ม
  /// + ชิปตัวเลขปุ่มมนแยกชั้นจากพื้นหลัง ให้ความรู้สึกนุ่มนวลเหมือนขนม
  Widget _statBox({
    required BuildContext context,
    required String label,
    required double value,
    required Color color,
    required bool isIncome,
    required HistoryFilter filter,
  }) {
    // โทนพาสเทลนวลๆ แบบขนมหวาน: มินต์ครีมสำหรับรายรับ / พีชโคชั่นสำหรับรายจ่าย
    final Color soft = isIncome ? const Color(0xFFDFF6E8) : const Color(0xFFFFE9E4);
    final Color mid = isIncome ? const Color(0xFF8FD6AE) : const Color(0xFFF3AA9C);
    final Color dark = isIncome ? const Color(0xFF3E9468) : const Color(0xFFD8695A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context,
            noAnimationRoute(IncomeExpenseScreen(initialFilter: filter))),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: mid.withOpacity(0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: mid.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // ฟองสบู่ตกแต่งมุมขวาบน-ล่าง ให้ความรู้สึกน่ารักฟรุ้งฟริ้ง
                Positioned(
                  right: -18,
                  top: -18,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: mid.withOpacity(0.25), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: -22,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: mid.withOpacity(0.20), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 8,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 11, color: mid.withOpacity(0.55)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: mid.withOpacity(0.5), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: mid.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CuteMascot(
                                kind: isIncome
                                    ? CuteMascotKind.income
                                    : CuteMascotKind.expense,
                                color: mid,
                                size: 22),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    color: dark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ชิปตัวเลขพื้นขาวมนๆ แยกชั้นจากพื้นหลัง ดูเหมือนป้ายราคาขนม
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isIncome
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: dark,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(context.watch<DataService>().formatMoney(value),
                                  style: TextStyle(
                                      color: dark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: -0.2),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดยอดคงเหลือ — ไล่เฉดพาสเทล (accentDeep -> accent) แทนพื้นทึบเดิม
/// พร้อมฟองสบู่ตกแต่งและมาสคอตกระปุกออมสินยิ้มมุมขวาบน ให้รู้สึกอบอุ่นน่ารัก
/// มากกว่าการ์ดข้อมูลธนาคารทั่วไป แต่ยังอ่านตัวเลขยอดคงเหลือได้ชัดเจนเป็นจุดเด่น
class _BalanceCard extends StatelessWidget {
  final DataService service;
  const _BalanceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.86), AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ฟองสบู่ตกแต่งพาสเทลจางๆ
            Positioned(
              right: -26,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 46,
              top: -6,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 96,
              bottom: -18,
              child: Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Colors.white.withOpacity(0.55)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(service.t('wallet_header'),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1)),
                    ),
                    // มาสคอตกระปุกออมสินยิ้ม ในวงกลมขาวมุมขวาบน
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CuteMascot(
                          kind: CuteMascotKind.coin, color: AppColors.accentDeep, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(service.t('total_balance'), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(service.formatMoney(service.balance),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// การ์ดพรีวิวเป้าหมายการออม — พาสเทลอ่อนกว่าเดิม พร้อมป้ายทรงเม็ดยาบอกจำนวน
/// เป้าหมายที่กำลังดำเนินอยู่ และไอคอนกระปุกในวงกลมพื้นขาว ให้เข้าชุดกับ
/// การ์ดยอดคงเหลือ/สถิติรายรับ-รายจ่ายด้านบน
class _GoalPreviewCard extends StatelessWidget {
  final DataService service;
  const _GoalPreviewCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.accentAltBg,
      onTap: () => Navigator.push(
          context, noAnimationRoute(const GoalSavingScreen())),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -14,
            child: Icon(Icons.favorite_rounded,
                size: 20, color: AppColors.accentPink.withOpacity(0.35)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.savings_rounded, color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.t('goal_saving'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brightness == Brightness.dark
                            ? AppColors.surface : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('${service.goals.where((goal) => goal.status == GoalStatus.inProgress).length} ${service.t('goals_in_progress')}',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.accentDeep, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}