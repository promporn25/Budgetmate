import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'home_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// ชุดสีพาสเทลสลับให้ไอคอนเป้าหมายแต่ละใบมีโทนต่างกัน (เทียบ _goalTint ใน
// goal_saving_screen.dart) เพื่อให้ลิสต์เป้าหมายในหน้าสถิติดูมีสีสันน่ารักขึ้น
// แทนที่จะเป็นวงกลมสีเดียวซ้ำๆ ทุกใบ
const List<Color> _statGoalTint = [
  Color(0xFFDCEEF7), // ฟ้าอ่อน
  Color(0xFFFBEED0), // เหลืองพีชอ่อน
  Color(0xFFF6E1E7), // ชมพูอ่อน
  Color(0xFFE1EFF8), // ฟ้ากลางอ่อน
  Color(0xFFE8F3E3), // มินต์อ่อน
  Color(0xFFEFE7FA), // ม่วงลาเวนเดอร์อ่อน
];
const List<Color> _statGoalTintIcon = [
  Color(0xFF3D568F),
  Color(0xFFC79A3B),
  Color(0xFFC08B9D),
  Color(0xFF5C86C4),
  Color(0xFF4E9B6E),
  Color(0xFF8B6FC4),
];

/// หน้า Statistic (3.4.8) - วิเคราะห์แนวโน้มรายรับ/รายจ่าย และความคืบหน้าการออม
class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  List<MapEntry<String, Map<String, double>>> _series(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data.map((e) => MapEntry('${e.key.day}/${e.key.month}', e.value)).toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data.map((e) => MapEntry(months[e.key.month - 1], e.value)).toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data.map((e) => MapEntry('${e.key}', e.value)).toList();
    }
  }

  dynamic _topGoal(DataService service) {
    if (service.goals.isEmpty) return null;
    final sorted = [...service.goals]..sort((a, b) => b.progress.compareTo(a.progress));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final series = _series(service);
    final mostSpent = service.mostSpentCategory;
    final pct = service.incomeExpensePercentage;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: service.t('statistic_title'),
            onBack: () => Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            ),
          ),
          Expanded(
            // ห่อด้วย RefreshIndicator กันไม่ให้ดึงหน้าจอเกินขอบบนแล้วเห็นพื้นที่ว่างสีขาว
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                Text(service.t('income_expense'), style: AppTextStyles.heading),
                const SizedBox(width: 6),
                Icon(Icons.insights_rounded, size: 15, color: AppColors.accentDeep),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
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
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value != value.roundToDouble()) return const SizedBox.shrink();
                                final idx = value.toInt();
                                if (idx < 0 || idx >= series.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(series[idx].key,
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
            preventCurveOverShooting: true,
                            color: AppColors.accentDeep,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.accentDeep.withOpacity(0.16),
                                  AppColors.accentDeep.withOpacity(0.0),
                                ],
                              ),
                            ),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['income'] ?? 0)),
                          ),
                          LineChartBarData(
                            isCurved: true,
            preventCurveOverShooting: true,
                            color: AppColors.accentPink,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.accentPink.withOpacity(0.14),
                                  AppColors.accentPink.withOpacity(0.0),
                                ],
                              ),
                            ),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['expense'] ?? 0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendChip(AppColors.income, AppColors.incomeBg,
                          '${service.t('income')} ${pct['income']!.toStringAsFixed(0)}%', true),
                      const SizedBox(width: 8),
                      _legendChip(AppColors.expense, AppColors.expenseBg,
                          '${service.t('expense')} ${pct['expense']!.toStringAsFixed(0)}%', false),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (mostSpent != null)
              AppCard(
                color: AppColors.accentAltBg,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ฟองสบู่ตกแต่งมุมขวาบน ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
                      Positioned(
                        right: -14,
                        top: -18,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: const Color(0xFFC79A3B).withOpacity(0.14), shape: BoxShape.circle),
                        ),
                      ),
                      LayoutBuilder(builder: (context, constraints) => Wrap(
                        spacing: 10, runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CategoryIcon(category: mostSpent.key, size: 22, color: AppColors.accentDeep),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 44).clamp(0.0, double.infinity),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(service.t('most_spent_category'),
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                    const SizedBox(width: 4),
                                    const Text('🏆', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(service.categoryName(mostSpent.key),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(service.formatMoney(mostSpent.value),
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(service.t('goal_saving'), style: AppTextStyles.heading),
                const SizedBox(width: 6),
                const Text('🐷', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            if (service.goals.isNotEmpty) _FeaturedGoalCard(goal: _topGoal(service)!, service: service),
            if (service.goals.isNotEmpty) const SizedBox(height: 12),
            if (service.goals.isEmpty)
              EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
            else
              ...service.goals.asMap().entries.map((entry) {
                final i = entry.key;
                final g = entry.value;
                final tint = _statGoalTint[i % _statGoalTint.length];
                final tintIcon = _statGoalTintIcon[i % _statGoalTintIcon.length];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: GoalArtwork(g.icon, artworkNumber: g.artworkNumber, color: tintIcon, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(g.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ),
                              Text('${(g.progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              color: g.progress >= 1 ? AppColors.success : tintIcon,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '${service.formatMoney(g.savedAmount)} / ${service.formatMoney(g.targetAmount)}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (g.isNearTarget)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CuteMascot(kind: CuteMascotKind.bell, color: AppColors.ink, size: 16),
                                  const SizedBox(width: 4),
                                  Text(service.t('near_target'),
                                      style: TextStyle(color: AppColors.ink, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
              }),
            const SizedBox(height: 80),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }

  Widget _legendChip(Color color, Color bg, String label, bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CuteMascot(
              kind: isIncome ? CuteMascotKind.income : CuteMascotKind.expense, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// การ์ดไฮไลต์เป้าหมายที่คืบหน้ามากที่สุด (โทนมินต์) แทนที่จะแสดงแค่ในลิสต์ปกติ
/// ให้ผู้ใช้เห็นเป้าหมายที่ใกล้สำเร็จที่สุดเด่นชัดตั้งแต่แรก ตามดีไซน์อ้างอิง
class _FeaturedGoalCard extends StatelessWidget {
  final dynamic goal; // GoalModel
  final DataService service;
  const _FeaturedGoalCard({required this.goal, required this.service});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final near = goal.isNearTarget as bool;
    return Container(
      // Clip decorations at the card edge, not at the padded text bounds.
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ฟองสบู่ตกแต่งมุมล่างซ้าย ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
            Positioned(
              left: -18,
              bottom: -22,
              child: Container(
                width: 60,
                height: 60,
                decoration:
                    BoxDecoration(color: AppColors.success.withOpacity(0.10), shape: BoxShape.circle),
              ),
            ),
          // มาสคอตตกแต่งมุมขวา (placeholder จนกว่าจะมี asset จริง) ไม่บังข้อความ/progress bar
          Positioned(
            right: 0,
            top: 4,
            child: Opacity(
              opacity: 0.9,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, color: AppColors.accentPink, size: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Goal Progress',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Text('🌸', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  near ? service.t('near_target') : goal.name,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$pct%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
    );
  }
}