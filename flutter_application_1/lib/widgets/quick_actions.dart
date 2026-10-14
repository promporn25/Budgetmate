import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../screens/add_income_expense_screen.dart';
import '../screens/app_theme.dart';
import '../screens/goal_saving_screen.dart';
import '../screens/income_expense_screen.dart';
import '../screens/receipt_scan_screen.dart';
import '../services/data_service.dart';
import 'pastel_artwork.dart';

/// The same four everyday actions across the dashboard, wallet and menu.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final th = service.currentLanguage != 'English';
    final actions = <(String, int, Widget)>[
      (
        th ? 'จดรายจ่าย' : 'Expense',
        6,
        const AddIncomeExpenseScreen(initialType: CategoryType.expense)
      ),
      (th ? 'สลิป / ใบเสร็จ' : 'Slip / receipt', 32, const ReceiptScanScreen()),
      (th ? 'ธุรกรรม' : 'Transactions', 21, const IncomeExpenseScreen()),
      (th ? 'ออมเงิน' : 'Savings', 17, const GoalSavingScreen()),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(26)),
      child: Row(
          children: actions
              .map((action) => Expanded(
                    child: Semantics(
                      button: true,
                      label: action.$1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                            context, noAnimationRoute(action.$3)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 2),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            ExcludeSemantics(
                                child: PastelArtwork(
                                    categoryNumber: action.$2, size: 28)),
                            const SizedBox(height: 7),
                            Text(action.$1,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                          ]),
                        ),
                      ),
                    ),
                  ))
              .toList()),
    );
  }
}
