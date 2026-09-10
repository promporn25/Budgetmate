import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/income%20expense%20overview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'wallet_screen.dart';

/// หน้า Income/Expense (3.4.9)
class IncomeExpenseScreen extends StatelessWidget {
  /// ตัวกรองเริ่มต้นตอนเปิดหน้า (ทั้งหมด / รายรับ / รายจ่าย)
  final HistoryFilter initialFilter;

  const IncomeExpenseScreen({
    super.key,
    this.initialFilter = HistoryFilter.all,
  });

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
          context, noAnimationRoute(const WalletScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: service.t('income_expense'),
            onBack: () => _handleBack(context),
          ),
          Expanded(child: IncomeExpenseOverview(initialFilter: initialFilter)),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}