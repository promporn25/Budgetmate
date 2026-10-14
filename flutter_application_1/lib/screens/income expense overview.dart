import 'transaction_details_sheet.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;

const _palette = [
  Color(0xFF80A1D4),
  Color(0xFFC08B9D),
  Color(0xFFC1E4F3),
  Color(0xFFFFE698),
  Color(0xFF3D568F),
  Color(0xFFE3B8C4),
  Color(0xFF9BC4E0),
  Color(0xFFEAD9A0),
];

/// วิดเจ็ตแสดง
/// 1. Pie Chart สัดส่วนรายจ่าย
/// 2. ประวัติรายการ
/// 3. ตัวกรอง ทั้งหมด / รายรับ / รายจ่าย
/// 4. ปฏิทินสำหรับดูรายการรายรับ/รายจ่ายในแต่ละวัน
class IncomeExpenseOverview extends StatefulWidget {
  /// ตัวกรองเริ่มต้นตอนเปิดหน้า (ใช้ตอนกดมาจากกล่องรายรับ/รายจ่ายในหน้า Wallet)
  final HistoryFilter initialFilter;

  const IncomeExpenseOverview({
    super.key,
    this.initialFilter = HistoryFilter.all,
  });

  @override
  State<IncomeExpenseOverview> createState() =>
      _IncomeExpenseOverviewState();
}

class _IncomeExpenseOverviewState
    extends State<IncomeExpenseOverview> {
  // ============================================================
  // ประเภทของ History
  // ============================================================

  late HistoryFilter _historyFilter;

  // วันที่เลือกในปฏิทิน
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _historyFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    // ============================================================
    // PIE CHART
    // ============================================================

    // Aggregate exactly the transactions shown by the active type/date filter.
    final historyList = _getHistoryList(service.transactions);
    final byCategory = <String, MapEntry<CategoryModel, double>>{};
    for (final transaction in historyList) {
      final key = '${transaction.type.name}:${transaction.category.id}';
      final previous = byCategory[key]?.value ?? 0;
      byCategory[key] = MapEntry(transaction.category, previous + transaction.amount);
    }
    final entries = byCategory.values.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final isThai = service.currentLanguage != 'English';
    final chartTitle = switch (_historyFilter) {
      HistoryFilter.all => isThai ? 'สัดส่วนรายรับและรายจ่าย · ทุกวัน' : 'Income and expenses · All dates',
      HistoryFilter.income => isThai ? 'สัดส่วนรายรับ' : 'Income breakdown',
      HistoryFilter.expense => isThai ? 'สัดส่วนรายจ่าย' : 'Expense breakdown',
    };

    return Column(
      children: [
        // ========================================================
        // PIE CHART
        // ========================================================

        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              0,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chartTitle, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text('${isThai ? 'ยอดรวม' : 'Total'} ${service.formatMoney(total)}',
                  key: const Key('overview-chart-total'), style: AppTextStyles.caption),
                const SizedBox(height: 8),
                SizedBox(
                height: 128,
                child: Row(
                  children: [
                    // ==================================================
                    // PIE
                    // ==================================================

                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 22,

                          sections: List.generate(
                            entries.length,
                            (i) {
                              final e = entries[i];

                              final pct = total == 0
                                  ? 0.0
                                  : (e.value / total) * 100;

                              return PieChartSectionData(
                                color: _palette[
                                    i % _palette.length],

                                value: e.value,

                                title: pct < 3 ? '' : _percentage(pct),

                                radius: 44,

                                titleStyle:
                                    const TextStyle(
                                  color: Color(0xFF283350),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // LEGEND
                    // ==================================================

                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,

                        itemBuilder: (context, i) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _palette[
                                        i % _palette.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),

                                const SizedBox(width: 6),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(service.categoryName(entries[i].key),
                                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text('${entries[i].key.type == CategoryType.income ? '+' : '-'}${service.formatMoney(entries[i].value)}',
                                            style: AppTextStyles.caption),
                                          const SizedBox(width: 6),
                                          Text(_percentage(entries[i].value / total * 100),
                                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ]),
            ),
          )
        else
          EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            text: _historyFilter == HistoryFilter.all
              ? (isThai ? 'ยังไม่มีรายการ' : 'No transactions yet')
              : service.t(_historyFilter == HistoryFilter.income ? 'no_income_data' : 'no_expense_data'),
          ),

        const SizedBox(height: 10),

        // ========================================================
        // HISTORY HEADER + MENU
        // ========================================================

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.t('history'), style: AppTextStyles.heading),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: _historyMenu(service))),
          ]),
        ),

        const SizedBox(height: 10),

        // ========================================================
        // CONTENT
        // ========================================================

        Expanded(
          child: _historyFilter == HistoryFilter.all
              ? _buildAllHistory(
                  historyList,
                )
              : _buildFilteredHistory(
                  historyList,
                  service,
                ),
        ),
      ],
    );
  }

  // ==============================================================
  // HISTORY MENU
  // ==============================================================

  String _percentage(double value) => value < 0.1 ? '<0.1%' : '${value.toStringAsFixed(1)}%';

  Widget _historyMenu(DataService service) {
    return Container(
      padding: const EdgeInsets.all(3),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius: BorderRadius.circular(
          AppRadius.pill,
        ),

        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _historyMenuItem(
            label: service.t('all'),
            selected: _historyFilter == HistoryFilter.all,
            onTap: () {
              setState(() {
                _historyFilter = HistoryFilter.all;
              });
            },
          ),

          _historyMenuItem(
            label: service.t('income'),
            selected:
                _historyFilter == HistoryFilter.income,
            onTap: () {
              setState(() {
                _historyFilter =
                    HistoryFilter.income;

                // เมื่อเข้าเมนูรายรับ
                // ให้ใช้วันที่วันนี้เป็นค่าเริ่มต้น
                _selectedDate = DateTime.now();
              });
            },
          ),

          _historyMenuItem(
            label: service.t('expense'),
            selected:
                _historyFilter == HistoryFilter.expense,
            onTap: () {
              setState(() {
                _historyFilter =
                    HistoryFilter.expense;

                // เมื่อเข้าเมนูรายจ่าย
                // ให้ใช้วันที่วันนี้เป็นค่าเริ่มต้น
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // HISTORY MENU ITEM
  // ==============================================================

  Widget _historyMenuItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentDeep
              : Colors.transparent,

          borderRadius: BorderRadius.circular(
            AppRadius.pill,
          ),
        ),

        child: Text(
          label,

          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.textPrimary,

            fontWeight: FontWeight.w600,

            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // GET HISTORY LIST
  // ==============================================================

  List<TransactionModel> _getHistoryList(
    List<TransactionModel> transactions,
  ) {
    switch (_historyFilter) {
      case HistoryFilter.all:
        return transactions;

      case HistoryFilter.income:
        return transactions
            .where(
              (t) =>
                  t.type == CategoryType.income && _isSameDay(t.date, _selectedDate),
            )
            .toList();

      case HistoryFilter.expense:
        return transactions
            .where(
              (t) =>
                  t.type == CategoryType.expense && _isSameDay(t.date, _selectedDate),
            )
            .toList();
    }
  }

  // ==============================================================
  // ALL HISTORY
  // ==============================================================

  Widget _buildAllHistory(
    List<TransactionModel> list,
  ) {
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'ยังไม่มีรายการ',
      );
    }

    return RefreshIndicator(
      color: AppColors.accentDeep,
      backgroundColor: AppColors.card,
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),

        children: _buildGroupedHistory(
          list,
        ),
      ),
    );
  }

  // ==============================================================
  // FILTERED HISTORY
  //
  // รายรับ / รายจ่าย
  // แสดง Calendar + รายการของวันที่เลือก
  // ==============================================================

  Widget _buildFilteredHistory(
    List<TransactionModel> list,
    DataService service,
  ) {

    return RefreshIndicator(
      color: AppColors.accentDeep,
      backgroundColor: AppColors.card,
      onRefresh: _onRefresh,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),

      children: [
        // ====================================================
        // ปุ่มเลือกวันที่ (เม็ดยา) — กดแล้วเปิดปฏิทินป๊อปอัพ
        // สไตล์เดียวกับหน้าแรก/หน้าสถิติ (PeriodFilterBar._pickDay)
        // ====================================================

        _dateSelectorPill(service),

        const SizedBox(height: 10),

        if (list.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            text: 'ไม่มีรายการในวันนี้',
          )
        else
          ...list.map(
            (t) => Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: _historyTile(t),
            ),
          ),
      ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }

  // ==============================================================
  // ปุ่มเม็ดยาแสดงวันที่ที่เลือก (เหมือนหน้าแรก/หน้าสถิติ)
  // ==============================================================

  Widget _dateSelectorPill(DataService service) {
    final dateText = DateFormat(
      'd MMM yyyy',
      'th',
    ).format(_selectedDate);

    return GestureDetector(
      onTap: () => _pickDate(context, service),

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(
            AppRadius.pill,
          ),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),

            const SizedBox(width: 8),

            Text(
              dateText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(width: 6),

            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // ปฏิทินป๊อปอัพ — ใช้การ์ดพาสเทล "เลือกวันที่" ชุดเดียวกับหน้าแรก/สถิติ
  // (PastelCalendarDialog จาก widgets/period_selector.dart) เพื่อให้หน้าตา
  // เหมือนกันทุกจุดในแอป ไม่มีปฏิทินคนละแบบให้สับสน
  // ==============================================================

  Future<void> _pickDate(BuildContext context, DataService service) async {
    final isThai = service.currentLanguage != 'English';

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelCalendarDialog(
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ==============================================================
  // GROUPED HISTORY
  //
  // ใช้เฉพาะเมนู "ทั้งหมด"
  // ==============================================================

  List<Widget> _buildGroupedHistory(
    List<TransactionModel> list,
  ) {
    final widgets = <Widget>[];

    DateTime? currentDay;

    for (final t in list) {
      final day = DateTime(
        t.date.year,
        t.date.month,
        t.date.day,
      );

      if (currentDay == null ||
          day != currentDay) {
        if (currentDay != null) {
          widgets.add(
            const SizedBox(height: 8),
          );
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              top: 4,
            ),

            child: Text(
              _dayLabel(day),

              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );

        currentDay = day;
      }

      widgets.add(
        _historyTile(t),
      );

      widgets.add(
        const SizedBox(height: 8),
      );
    }

    return widgets;
  }

  // ==============================================================
  // DAY LABEL
  // ==============================================================

  String _dayLabel(
    DateTime day,
  ) {
    final service =
        context.read<DataService>();

    final today = DateTime.now();

    final todayDay = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final yesterday =
        todayDay.subtract(
      const Duration(days: 1),
    );

    if (_isSameDay(day, todayDay)) {
      return service.t('today');
    }

    if (_isSameDay(day, yesterday)) {
      return service.t('yesterday');
    }

    return DateFormat(
      'd MMM yyyy',
    ).format(day).toUpperCase();
  }

  // ==============================================================
  // HISTORY TILE
  // ==============================================================

  Widget _historyTile(
    TransactionModel t,
  ) {
    final service =
        context.read<DataService>();

    final isIncome =
        t.type == CategoryType.income;

    // ============================================================
    // รายรับ = เขียว
    // รายจ่าย = แดง
    // ============================================================

    final accent = isIncome
        ? AppColors.income
        : AppColors.expense;

    final accentBg = isIncome
        ? AppColors.incomeBg
        : AppColors.expenseBg;

    return GestureDetector(
      onTap: () => showTransactionDetails(context, t),
      child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius: BorderRadius.circular(
          AppRadius.lg,
        ),

        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          // ======================================================
          // ICON
          // ======================================================

          CircleAvatar(
            radius: 15,

            backgroundColor: accentBg,

            child: CategoryIcon(
              category: t.category,
              color: accent,
              size: 15,
            ),
          ),

          const SizedBox(width: 10),

          // ======================================================
          // NAME + TIME
          // ======================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  service.categoryName(
                    t.category,
                  ),

                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),

                if (t.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(t.note!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 2),

                Text(
                  DateFormat(
                    'HH:mm',
                  ).format(t.date),

                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // AMOUNT
          // ======================================================

          Text(
            '${isIncome ? '+' : '-'}${context.watch<DataService>().formatMoney(t.amount)}',

            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: accent,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: service.currentLanguage == 'English' ? 'Manage transaction' : 'จัดการรายการ',
            onPressed: () => showTransactionDetails(context, t),
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.ink, size: 18),
          ),
        ],
      ),
    ));
  }

  // ==============================================================
  // SAME DAY
  // ==============================================================

  bool _isSameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

// ==================================================================
// HISTORY FILTER
// ==================================================================

enum HistoryFilter {
  all,
  income,
  expense,
}