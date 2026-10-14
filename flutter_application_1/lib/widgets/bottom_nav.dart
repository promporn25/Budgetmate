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

/// Five evenly aligned tabs sized to the available screen width.
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

    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final margin = (width * 0.03).clamp(8.0, 16.0);
            final itemWidth = (width - margin * 2 - 10) / items.length;
            final iconSize = (itemWidth * 0.36).clamp(22.0, 26.0);
            final iconHeight = (itemWidth * 0.44).clamp(28.0, 32.0);
            final addWidth = (itemWidth * 0.72).clamp(40.0, 56.0);
            final fontSize = (itemWidth * 0.16).clamp(10.5, 12.0);
            final textScaler = MediaQuery.textScalerOf(context);
            final styles = List.generate(items.length, (i) => TextStyle(
              fontFamily: appFontFamily, fontSize: fontSize, height: 1.4,
              fontWeight: i == currentIndex ? FontWeight.w800 : FontWeight.w500,
              color: i == currentIndex ? AppColors.ink : AppColors.textSecondary,
            ));
            // Reserve the same label height in all five tabs, including when
            // accessibility text sizing makes a label wrap onto a second line.
            var labelHeight = 0.0;
            for (var i = 0; i < items.length; i++) {
              final painter = TextPainter(
                text: TextSpan(text: items[i].label, style: styles[i]),
                textDirection: Directionality.of(context),
                textScaler: textScaler, maxLines: 2,
              )..layout(maxWidth: itemWidth - 4);
              if (painter.height > labelHeight) labelHeight = painter.height;
              painter.dispose();
            }
            return Container(
              margin: EdgeInsets.fromLTRB(margin, 4, margin, 6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: AppColors.shadow,
                  blurRadius: 18, offset: const Offset(0, 5))],
              ),
              child: Row(children: List.generate(items.length, (i) {
                final item = items[i];
                final selected = i == currentIndex;
                return Expanded(child: Semantics(
                  selected: selected, button: true, label: item.label,
                  child: Tooltip(
                    message: item.label,
                    child: InkWell(
                      key: ValueKey('nav-$i'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _onTap(context, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(height: iconHeight,
                            child: Center(child: item.big
                              ? Container(
                                  width: addWidth, height: iconHeight,
                                  decoration: BoxDecoration(color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(iconHeight / 2)),
                                  child: Icon(Icons.add_rounded,
                                    size: iconSize, color: AppColors.accentDeep),
                                )
                              : ExcludeSemantics(child: PastelArtwork(
                                  categoryNumber: item.categoryNumber, size: iconSize)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(height: labelHeight,
                            child: Center(child: Text(item.label,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center, style: styles[i])),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(duration: const Duration(milliseconds: 180),
                            height: 3, width: selected ? 18 : 0,
                            decoration: BoxDecoration(color: AppColors.accent,
                              borderRadius: BorderRadius.circular(3))),
                        ]),
                      ),
                    ),
                  ),
                ));
              })),
            );
          }),
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
