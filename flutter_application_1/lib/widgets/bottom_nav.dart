import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/add_income_expense_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/account_setting_screen.dart';

/// แถบเมนูนำทางด้านล่าง ปรากฏในหน้า Home, Wallet, Income/Expense, Statistic
/// ไอคอนกลาง (+) ใช้สำหรับเพิ่มรายการรายรับ-รายจ่ายอย่างรวดเร็ว
class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget page;
    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const WalletScreen();
        break;
      case 2:
        page = const AddIncomeExpenseScreen();
        break;
      case 3:
        page = const StatisticScreen();
        break;
      default:
        page = const AccountSettingScreen();
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      onTap: (i) => _onTap(context, i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าหลัก'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet), label: 'กระเป๋าเงิน'),
        BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 32), label: 'เพิ่มรายการ'),
        BottomNavigationBarItem(
            icon: Icon(Icons.show_chart), label: 'สถิติ'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'เมนู'),
      ],
    );
  }
}
