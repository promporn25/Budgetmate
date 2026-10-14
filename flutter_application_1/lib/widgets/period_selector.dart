import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

/// ประเภทช่วงเวลาที่ใช้กรองกราฟรายรับ-รายจ่าย: วัน / เดือน / ปี
enum ChartPeriod { day, month, year }

const List<String> _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const List<String> _enMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];
const List<String> _enMonthsAbbr = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

// สัปดาห์เริ่มวันอาทิตย์ (ตามดีไซน์ปฏิทินอ้างอิงใหม่)
const List<String> _thaiWeekdaysSun = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
const List<String> _enWeekdaysSun = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// แถบเลือกช่วงเวลา (วัน/เดือน/ปี) พร้อมปุ่มเลือกวันที่/เดือน/ปีที่ต้องการดูข้อมูลจริง
class PeriodFilterBar extends StatelessWidget {
  final ChartPeriod period;
  final DateTime anchor;
  final ValueChanged<ChartPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  /// ปฏิทินเลือกวัน — การ์ดพาสเทล "เลือกวันที่" (เหมือนกับตัวเลือกเดือน/ปี)
  Future<void> _pickDay(BuildContext context) async {
    final service = context.read<DataService>();
    final isThai = service.currentLanguage != 'English';

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelCalendarDialog(
        initialDate: anchor,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  /// เลือกเดือน — การ์ดพาสเทลสไตล์เดียวกับเลือกวันที่/ปี
  Future<void> _pickMonth(BuildContext context, bool isThai) async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelMonthDialog(
        initialMonth: anchor.month,
        initialYear: anchor.year,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  /// เลือกปี — การ์ดพาสเทลสไตล์เดียวกับเลือกวันที่/เดือน
  Future<void> _pickYear(BuildContext context, bool isThai) async {
    final pickedYear = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelYearDialog(
        initialYear: anchor.year,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (pickedYear != null) onAnchorChanged(DateTime(pickedYear, anchor.month, 1));
  }

  String _label(DataService service) {
    final isThai = service.currentLanguage != 'English';
    final months = isThai ? _thaiMonthsFull : _enMonthsFull;
    switch (period) {
      case ChartPeriod.day:
        return '${anchor.day} ${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.month:
        return '${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.year:
        return '${anchor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _periodChip(service.t('period_day'), ChartPeriod.day),
            const SizedBox(width: 4),
            _periodChip(service.t('period_month'), ChartPeriod.month),
            const SizedBox(width: 4),
            _periodChip(service.t('period_year'), ChartPeriod.year),
          ],
        ),
        GestureDetector(
          onTap: () {
            switch (period) {
              case ChartPeriod.day:
                _pickDay(context);
                break;
              case ChartPeriod.month:
                _pickMonth(context, isThai);
                break;
              case ChartPeriod.year:
                _pickYear(context, isThai);
                break;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(_label(service),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _periodChip(String label, ChartPeriod value) {
    final selected = period == value;
    return GestureDetector(
      onTap: () => onPeriodChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDeep : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }
}

// ====================================================================
// กรอบการ์ดกลาง (Dialog Frame) ใช้ร่วมกันทั้ง 3 ตัวเลือก วัน/เดือน/ปี
// เพื่อให้หน้าตาเหมือนกันทุกจุด ไม่งงว่าอันไหนคืออันไหน:
// [หัวข้อ + ป้ายวันที่ไล่เฉด] -> [เนื้อหาเฉพาะของแต่ละตัวเลือก] -> [ปุ่มยืนยัน]
// ====================================================================
class _PastelDialogFrame extends StatelessWidget {
  final String title;
  final Widget badge;
  final Widget content;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  const _PastelDialogFrame({
    required this.title,
    required this.badge,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 14),
            PrimaryButton(label: confirmLabel, onPressed: onConfirm),
          ],
        ),
      ),
    );
  }
}

/// ป้าย (badge) มุมขวาบนไล่เฉดสีพาสเทลเดียวกับ Pinned Goals — ใช้ร่วมกันทั้ง
/// การ์ดเลือกวัน/เดือน/ปี เพื่อให้เห็นภาพจำเดียวกันว่ากำลังเลือก "อะไรอยู่"
class _CalendarBadge extends StatelessWidget {
  final Widget child;
  const _CalendarBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.pinnedGoalBg,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -4, left: 13, child: _ringDot()),
          Positioned(top: -4, right: 13, child: _ringDot()),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _ringDot() => Container(
        width: 6,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.pinnedGoalIcon,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// เม็ดยา (pill) ใช้เป็นตัวเลือกแบบ dropdown ร่วมกันทุกการ์ด
class _PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PillButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      ),
    );
  }
}

Widget _dropdownPillContent(String label) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
      ),
      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
    ],
  );
}

/// เซลล์กริดทรงกลม-เม็ดยาที่ใช้ร่วมกันทั้งกริดเดือนและลิสต์ปี (เลือก/ไม่เลือก/ปิดใช้งาน)
class _PastelChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _PastelChoiceTile({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: disabled ? null : onTap,
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? AppColors.textMuted
                      : selected
                          ? Colors.white
                          : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// ปุ่มลูกศรเลื่อนปีถัดไป/ก่อนหน้า (ใช้ในการ์ดเลือกเดือน)
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.accentDeep.withOpacity(onTap == null ? 0.03 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Icon(icon, size: 20, color: onTap == null ? AppColors.textMuted : AppColors.textSecondary),
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "วันที่" — ปฏิทินเต็มรูปแบบ พร้อมดรอปดาวน์เดือน/ปีด้านใน
// (แตะดรอปดาวน์เดือน/ปีจะเปิดการ์ดเดือน/ปีแบบเดียวกันนี้ซ้อนขึ้นมา)
// ====================================================================
class PastelCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelCalendarDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelCalendarDialog> createState() => _PastelCalendarDialogState();
}

class _PastelCalendarDialogState extends State<PastelCalendarDialog> {
  late DateTime _visibleMonth;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  List<String> get _months => widget.isThai ? _thaiMonthsFull : _enMonthsFull;
  List<String> get _weekdays => widget.isThai ? _thaiWeekdaysSun : _enWeekdaysSun;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openMonthPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelMonthDialog(
        initialMonth: _visibleMonth.month,
        initialYear: _visibleMonth.year,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        isThai: widget.isThai,
      ),
    );
    if (picked != null) {
      setState(() => _visibleMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _openYearPicker() async {
    final pickedYear = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelYearDialog(
        initialYear: _visibleMonth.year,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        isThai: widget.isThai,
      ),
    );
    if (pickedYear != null) {
      setState(() => _visibleMonth = DateTime(pickedYear, _visibleMonth.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Sunday-first: DateTime.weekday คือ Mon=1..Sun=7 -> % 7 ทำให้ Sun=0
    final leadingEmptyDays = firstDayOfMonth.weekday % 7;
    final prevMonthLastDay = DateTime(_visibleMonth.year, _visibleMonth.month, 0).day;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกวันที่' : 'Select Date',
      badge: _CalendarBadge(
        child: Text(_selected.day.toString().padLeft(2, '0'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, _selected),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  onTap: _openMonthPicker,
                  child: _dropdownPillContent(_months[_visibleMonth.month - 1]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PillButton(
                  onTap: _openYearPicker,
                  child: _dropdownPillContent('${_visibleMonth.year}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_weekdays.length, (i) {
              return Expanded(
                child: Center(
                  child: Text(_weekdays[i],
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? AppColors.accentDeep : AppColors.textSecondary)),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          ...List.generate(rows, (rowIndex) {
            return Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                int dayNumber;
                bool isCurrentMonth;
                DateTime cellDate;

                if (cellIndex < leadingEmptyDays) {
                  dayNumber = prevMonthLastDay - (leadingEmptyDays - cellIndex - 1);
                  final prevMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  cellDate = DateTime(prevMonth.year, prevMonth.month, dayNumber);
                  isCurrentMonth = false;
                } else if (cellIndex < leadingEmptyDays + daysInMonth) {
                  dayNumber = cellIndex - leadingEmptyDays + 1;
                  cellDate = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
                  isCurrentMonth = true;
                } else {
                  dayNumber = cellIndex - leadingEmptyDays - daysInMonth + 1;
                  final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  cellDate = DateTime(nextMonth.year, nextMonth.month, dayNumber);
                  isCurrentMonth = false;
                }

                final isSelected = _sameDay(cellDate, _selected);
                final isToday = _sameDay(cellDate, today);
                final disabled =
                    cellDate.isBefore(widget.firstDate) || cellDate.isAfter(widget.lastDate);

                return Expanded(
                  child: GestureDetector(
                    onTap: disabled
                        ? null
                        : () {
                            setState(() {
                              _selected = cellDate;
                              if (!isCurrentMonth) {
                                _visibleMonth = DateTime(cellDate.year, cellDate.month);
                              }
                            });
                          },
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentDeep : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (!isCurrentMonth || disabled)
                                    ? AppColors.textMuted
                                    : isToday
                                        ? AppColors.accentDeep
                                        : AppColors.textPrimary,
                            decoration: (isToday && !isSelected) ? TextDecoration.underline : null,
                            decorationColor: AppColors.accentDeep,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "เดือน" — หน้าตาเดียวกับเลือกวันที่/ปี: หัวข้อ+ป้าย, ตัวเลือก
// ปีด้วยลูกศรซ้าย-ขวา, กริดเดือน 12 ช่อง, ปุ่มยืนยัน
// ====================================================================
class PastelMonthDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelMonthDialog({
    super.key,
    required this.initialMonth,
    required this.initialYear,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelMonthDialog> createState() => _PastelMonthDialogState();
}

class _PastelMonthDialogState extends State<PastelMonthDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  List<String> get _monthsFull => widget.isThai ? _thaiMonthsFull : _enMonthsFull;
  List<String> get _monthsAbbr => widget.isThai ? _thaiMonthsAbbr : _enMonthsAbbr;

  @override
  Widget build(BuildContext context) {
    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกเดือน' : 'Select Month',
      badge: _CalendarBadge(
        child: Text(_monthsAbbr[_month - 1],
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, DateTime(_year, _month, 1)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _year--),
              ),
              Expanded(
                child: Center(
                  child: Text('$_year',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: _year >= widget.lastDate.year ? null : () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final m = i + 1;
              final disabled = DateTime(_year, m, 1).isAfter(widget.lastDate) ||
                  DateTime(_year, m, 1).isBefore(DateTime(widget.firstDate.year, widget.firstDate.month));
              return _PastelChoiceTile(
                label: _monthsFull[i],
                selected: m == _month,
                disabled: disabled,
                onTap: () => setState(() => _month = m),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "ปี" — หน้าตาเดียวกับเลือกวันที่/เดือน: หัวข้อ+ป้าย, ลิสต์ปี,
// ปุ่มยืนยัน
// ====================================================================
class PastelYearDialog extends StatefulWidget {
  final int initialYear;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelYearDialog({
    super.key,
    required this.initialYear,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelYearDialog> createState() => _PastelYearDialogState();
}

class _PastelYearDialogState extends State<PastelYearDialog> {
  late int _year;
  late final ScrollController _scrollController;
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (i) => widget.lastDate.year - i,
    );
    final initialIndex = _years.indexOf(_year).clamp(0, _years.length - 1);
    _scrollController =
        ScrollController(initialScrollOffset: (initialIndex - 2).clamp(0, _years.length).toDouble() * 48.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกปี' : 'Select Year',
      badge: _CalendarBadge(
        child: Text(_year.toString().substring(2),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, _year),
      content: SizedBox(
        height: 280,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _years.length,
          itemBuilder: (context, i) {
            final y = _years[i];
            final selected = y == _year;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _PastelChoiceTile(
                label: '$y',
                selected: selected,
                disabled: false,
                onTap: () => setState(() => _year = y),
              ),
            );
          },
        ),
      ),
    );
  }
}