import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../screens/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/add_income_expense_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/account_setting_screen.dart';
import 'pastel_artwork.dart';

/// แถบเมนูนำทางด้านล่าง — v2 "Cute Fintech"
/// โครงสร้าง/ลำดับ/พฤติกรรมการนำทางเหมือนเดิมทุกประการ (5 แท็บ, index เดิม)
/// ปรับเฉพาะภาพ: ไอเทมที่ถูกเลือกจะมี pill พื้นหลังพาสเทล lavender
/// ล้อมไอคอนไว้ พร้อมทรานซิชันนุ่มๆ แทน selectedItemColor ธรรมดา
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
    Navigator.pushReplacement(context, _noAnimationRoute(page));
  }

  PageRoute _noAnimationRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    final items = <_NavItemData>[
      _NavItemData(3, service.t('nav_home')),
      _NavItemData(14, service.t('nav_wallet')),
      _NavItemData(5, service.t('nav_add'), big: true),
      _NavItemData(20, service.t('nav_stat')),
      _NavItemData(13, service.t('nav_menu')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTap(context, i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentBg
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: Stack(clipBehavior: Clip.none, children: [
                            ExcludeSemantics(
                                child: PastelArtwork(
                                    categoryNumber: item.categoryNumber,
                                    size: 38)),
                            if (item.big)
                              Positioned(
                                  right: -3,
                                  bottom: -1,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: AppColors.accentDeep,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.card, width: 1.5)),
                                    child: const Icon(Icons.add_rounded,
                                        size: 14, color: Colors.white),
                                  )),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.ink
                              : AppColors.textSecondary,
                        ),
                        child: Text(item.label,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final int categoryNumber;
  final String label;
  final bool big;
  const _NavItemData(this.categoryNumber, this.label, {this.big = false});
}
