import '../models/goal_model.dart';
import 'add_goal_saving_screen.dart';
import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'history_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// จุดข้อมูลสำหรับกราฟแท่งคู่ (รายรับ vs รายจ่าย) ต่อหนึ่งช่วงเวลา (วัน/เดือน/ปี)
class _IncomeExpensePoint {
  final String label;
  final double income;
  final double expense;
  const _IncomeExpensePoint(this.label, this.income, this.expense);
}

/// หน้า Home (3.4.6) - แสดงภาพรวมทางการเงินของผู้ใช้งาน
/// ดีไซน์ v3 "Sky Fintech": ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมน + Avatar/กระดิ่งแจ้งเตือน
/// และเพิ่มส่วน "Pinned Goals" แสดงเป้าหมายการออมล่าสุดแบบการ์ดสีพาสเทล
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  // สีของแท่งกราฟ "รายรับ" / "รายจ่าย" — ใช้สีจาก AppColors.income / AppColors.expense
  // ที่มีอยู่แล้วในธีม (app_theme.dart) ตรงกับสีที่ใช้แสดงรายรับ/รายจ่ายในหน้าอื่นๆ
  // ของแอปอยู่แล้ว (เช่นหน้า History/Statistic) ทำให้สีสื่อความหมายตรงกันทั้งแอป
  static Color get _incomeColorDeep => AppColors.income;
  static Color get _incomeColorLight => AppColors.income.withOpacity(0.55);
  static Color get _expenseColorDeep => AppColors.expense;
  static Color get _expenseColorLight => AppColors.expense.withOpacity(0.55);

  /// ดึงข้อมูลรายรับ-รายจ่ายตามช่วงเวลาที่เลือก (วัน/เดือน/ปี) สำหรับกราฟแท่งคู่
  List<_IncomeExpensePoint> _incomeExpenseSeries(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data
            .map((e) => _IncomeExpensePoint(
                  '${e.key.day}/${e.key.month}',
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data
            .map((e) => _IncomeExpensePoint(
                  months[e.key.month - 1],
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data
            .map((e) => _IncomeExpensePoint(
                  '${e.key}',
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final homeGoals = service.pinnedGoals;
    final series = _incomeExpenseSeries(service);
    final maxVal = series
        .expand((e) => [e.income, e.expense])
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      // _SkyHeader อยู่นอก RefreshIndicator/SingleChildScrollView โดยตั้งใจ เพื่อให้
      // Header ตรึงอยู่บนสุดเสมอ (เหมือนหน้า Statistic/History) — ถ้าเอา Header ไปไว้
      // เป็นลูกของเนื้อหาที่เลื่อนได้ ตอนดึงลงมารีเฟรชเนื้อหาทั้งหมด (รวม Header) จะถูก
      // ดันลงมาด้วย จะเห็นพื้นหลังเปล่าของ Scaffold (สีขาวอมฟ้าอ่อน) โผล่มาด้านบนแทน
      body: Column(
        children: [
          _SkyHeader(service: service),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                // ต้องใช้ AlwaysScrollableScrollPhysics ไม่งั้นถ้าเนื้อหาสั้นกว่าจอ
                // จะดึงเพื่อรีเฟรชไม่ได้เลย
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: EdgeInsets.zero,
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppLayout.pageInset(context), 12, AppLayout.pageInset(context), 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(service.t('expense_trend'), style: AppTextStyles.heading),
                      const SizedBox(width: 6),
                      Icon(Icons.show_chart_rounded, size: 15, color: AppColors.accentDeep),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PeriodFilterBar(
                    period: _period,
                    anchor: _anchor,
                    onPeriodChanged: (p) => setState(() => _period = p),
                    onAnchorChanged: (d) => setState(() => _anchor = d),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (maxVal != 0) ...[
                          Row(
                            children: [
                              const Spacer(),
                              _LegendDot(
                                color: _incomeColorDeep,
                                label: service.currentLanguage != 'English'
                                    ? 'รายรับ'
                                    : 'Income',
                              ),
                              const SizedBox(width: 14),
                              _LegendDot(
                                color: _expenseColorDeep,
                                label: service.currentLanguage != 'English'
                                    ? 'รายจ่าย'
                                    : 'Expense',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          height: AppLayout.chartHeight(context),
                          child: maxVal == 0
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CuteMascot(
                                          kind: CuteMascotKind.income,
                                          size: 30,
                                          color: AppColors.accent),
                                      const SizedBox(height: 10),
                                      Text(
                                        service.t('no_expense_data'),
                                        style: TextStyle(
                                            color: AppColors.textSecondary, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                )
                              : BarChart(
                            BarChartData(
                              maxY: maxVal == 0 ? 100 : maxVal * 1.2,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              groupsSpace: 18,
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= series.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(series[idx].label,
                                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(series.length, (i) {
                                final p = series[i];
                                return BarChartGroupData(
                                  x: i,
                                  barsSpace: 4,
                                  barRods: [
                                    BarChartRodData(
                                      toY: p.income,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [_incomeColorDeep, _incomeColorLight],
                                      ),
                                      width: 12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    BarChartRodData(
                                      toY: p.expense,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [_expenseColorDeep, _expenseColorLight],
                                      ),
                                      width: 12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== ปุ่มกระเป๋าตัง / กระปุกออมสิน =====
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.account_balance_wallet_rounded,
                          artwork: const PastelArtwork(categoryNumber: 14, size: 26),
                          label: service.t('wallet_title'),
                          iconBg: AppColors.accentDeep,
                          cardBg: AppColors.accentBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const WalletScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.savings_rounded,
                          artwork: const PastelArtwork(categoryNumber: 17, size: 26),
                          label: service.t('goal_saving'),
                          iconBg: AppColors.accentPink,
                          cardBg: AppColors.accentAltBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const GoalSavingScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  ...[
                    Row(
                      children: [
                        Expanded(
                          child: Row(children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(service.t('goal_saving'),
                                    style: AppTextStyles.heading, maxLines: 1, softWrap: false),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.push_pin_rounded, size: 15, color: AppColors.accentPink),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context, noAnimationRoute(const GoalSavingScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  service.currentLanguage != 'English' ? 'ดูทั้งหมด' : 'See all',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 15, color: AppColors.accentDeep),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (homeGoals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.push_pin_outlined,
                                size: 23, color: AppColors.ink),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  key: Key(service.goals.isEmpty
                                    ? 'home-add-goal' : 'home-pin-goal'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.ink,
                                    backgroundColor: AppColors.accentBg,
                                    side: BorderSide.none,
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    textStyle: AppTextStyles.label,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  ),
                                  onPressed: () => Navigator.push(context,
                                    noAnimationRoute(service.goals.isEmpty
                                      ? const AddGoalSavingScreen()
                                      : const GoalSavingScreen())),
                                  icon: Icon(service.goals.isEmpty
                                    ? Icons.add_rounded : Icons.push_pin_outlined, size: 17),
                                  label: Text(service.currentLanguage != 'English'
                                    ? (service.goals.isEmpty ? 'สร้างเป้าหมาย' : 'เลือกเป้าหมาย')
                                    : (service.goals.isEmpty ? 'Create a goal' : 'Choose a goal')),
                                ),
                              ],
                            )),
                          ],
                        ),
                      )
                    else Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(homeGoals.length, (i) => SizedBox(
                        width: (MediaQuery.sizeOf(context).width - AppLayout.pageInset(context) * 2 - 12) / 2,
                        child: _PinnedGoalCard(
                          goal: homeGoals[i],
                          bg: AppColors.pinnedGoalBg[i % AppColors.pinnedGoalBg.length],
                          onTap: () => Navigator.push(context, noAnimationRoute(const GoalSavingScreen())),
                        ),
                      )),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),



                ],
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }
}

/// จุดสีเล็กๆ พร้อม label ใช้เป็น legend อธิบายสีแท่งกราฟรายรับ/รายจ่าย
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมนด้านล่าง: รูปโปรไฟล์ + คำทักทาย + กระดิ่งแจ้งเตือน (ไปหน้า History)
///
/// อัปเดต: รูปโปรไฟล์ตอนนี้ลอง decode จาก `service.currentUser.avatarBase64`
/// (Base64 string ที่เก็บอยู่ใน Firestore) ก่อนเป็นอันดับแรก เพราะเป็นแหล่งข้อมูลจริง
/// ที่ผูกกับบัญชีและตามไปทุกเครื่องที่ล็อกอิน ถ้ายังไม่มี (เช่นยังไม่เคยตั้งรูป) จะ
/// fallback ไปที่ไฟล์แคชในเครื่อง (avatarPath) แล้วค่อย fallback สุดท้ายเป็นไอคอนคน
/// default — เดิมโค้ดจุดนี้ดูแค่ avatarPath (ไฟล์ในเครื่อง) อย่างเดียว ทำให้เปลี่ยน
/// มือถือเครื่องใหม่แล้วเห็นแต่ไอคอน default เสมอ
class _SkyHeader extends StatelessWidget {
  final DataService service;
  const _SkyHeader({required this.service});

  @override
  Widget build(BuildContext context) {
    final avatarBase64 = service.currentUser?.avatarBase64;
    final avatarPath = service.avatarPath;
    final hasLocalImage = avatarPath != null && File(avatarPath).existsSync();

    ImageProvider? avatarImage;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarBase64));
      } catch (_) {
        avatarImage = null;
      }
    }
    if (avatarImage == null && hasLocalImage) {
      avatarImage = FileImage(File(avatarPath));
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 4, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentDeep.withOpacity(0.9), AppColors.accent, AppColors.bg],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ประกายดาวเล็กๆ ตกแต่งมุมบน ให้ดูสดใสมีชีวิตชีวาแบบภาพอ้างอิง
          Positioned(
            right: 70,
            top: 2,
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white.withOpacity(0.85)),
          ),
          Positioned(
            right: 96,
            top: 22,
            child: Icon(Icons.auto_awesome_rounded,
                size: 9, color: Colors.white.withOpacity(0.6)),
          ),
          // ไอคอนพระอาทิตย์ (กลางวัน) / พระจันทร์ (กลางคืน) เปลี่ยนตามเวลาจริงของเครื่อง
          // ให้ธีม "ท้องฟ้า" ของ Header มีความหมายจริงๆ ไม่ใช่แค่ไล่เฉดสีเฉยๆ
          const Positioned(
            right: 46,
            top: 4,
            child: _SkyTimeIcon(),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(Icons.person, color: AppColors.accentDeep, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${service.t('greeting')}, ${service.currentUser?.name ?? service.t('default_user')} 👋',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF3D568F)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Reserve room for the sky decoration instead of painting over names.
              const SizedBox(width: 42),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, noAnimationRoute(const HistoryScreen())),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.notifications_rounded, color: AppColors.accentDeep, size: 21),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ไอคอนพระอาทิตย์ (กลางวัน) หรือพระจันทร์ (กลางคืน) เปลี่ยนตามเวลาจริงของเครื่อง
/// เป็นรายละเอียดเล็กๆ ที่ทำให้ธีม "ท้องฟ้า" ของ Header มีความหมายจริงมากกว่า
/// แค่ไล่เฉดสีเฉยๆ — กลางวัน (06:00-18:00) โชว์พระอาทิตย์โทนเหลืองพาสเทล
/// นอกเวลานั้นโชว์พระจันทร์โทนม่วงลาเวนเดอร์พาสเทล
class _SkyTimeIcon extends StatelessWidget {
  const _SkyTimeIcon();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;
    final Color glow = isDay ? const Color(0xFFFFE698) : const Color(0xFFEFE7FA);
    final Color iconColor = isDay ? const Color(0xFFC79A3B) : const Color(0xFF8B6FC4);

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: glow.withOpacity(0.55), shape: BoxShape.circle),
          ),
          Icon(isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 18, color: iconColor),
        ],
      ),
    );
  }
}


class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Widget? artwork;
  final String label;
  final Color iconBg;
  final Color cardBg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.artwork,
    required this.label,
    required this.iconBg,
    required this.cardBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: iconBg.withOpacity(0.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ฟองสบู่ตกแต่งมุมขวาบน ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
                Positioned(
                  right: -14,
                  top: -16,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(color: iconBg.withOpacity(0.14), shape: BoxShape.circle),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      artwork ?? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(icon, size: 20, color: iconBg),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                    ),
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

/// การ์ดเป้าหมายการออมแบบพาสเทล ใช้กับส่วน "Pinned Goals" ในหน้า Home
class _PinnedGoalCard extends StatelessWidget {
  final GoalModel goal;
  final Color bg;
  final VoidCallback onTap;
  const _PinnedGoalCard({required this.goal, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final bool near = goal.isNearTarget;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: GoalArtwork(goal.icon, artworkNumber: goal.artworkNumber, size: 14, color: AppColors.pinnedGoalIcon),
                ),
                const Spacer(),
                if (near)
                  Icon(Icons.star_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              ],
            ),
            const SizedBox(height: 6),
            Text(goal.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3D568F)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(service.formatMoney(goal.targetAmount),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6E7FA3))),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.6),
                color: AppColors.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}