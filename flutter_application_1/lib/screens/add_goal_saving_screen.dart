import '../models/category_model.dart';
import '../widgets/pastel_artwork.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;


const List<IconData> _goalIcons = [
  Icons.restaurant, Icons.local_cafe, Icons.home, Icons.directions_car,
  Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer,
  Icons.pets, Icons.school,
];

// ชุดสีพาสเทลของไอคอนเป้าหมาย (โทนเดียวกับหน้า Add Income/Expense)
const List<Color> _goalTint = [
  Color(0xFFDCEEF7), Color(0xFFFBE1E9), Color(0xFFFFF3D2), Color(0xFFE7E3F7),
  Color(0xFFDFF3E7), Color(0xFFFFE8D9), Color(0xFFDCF3F1), Color(0xFFF3E4EF),
];
const List<Color> _goalTintIcon = [
  Color(0xFF6FA3D6), Color(0xFFD9789B), Color(0xFFC79A3B), Color(0xFF8C79C9),
  Color(0xFF54A57E), Color(0xFFDB8A55), Color(0xFF4FA79C), Color(0xFFB1699F),
];

/// หน้า Add Goal Saving (3.4.12) - เพิ่มเป้าหมายการออมเงินใหม่ลง SQLite
/// ปรับดีไซน์ให้นุ่มนวล มีมิติ และเพิ่มช่องหมายเหตุ (optional) ให้เหมือนหน้า Add Income/Expense
class AddGoalSavingScreen extends StatefulWidget {
  const AddGoalSavingScreen({super.key});

  @override
  State<AddGoalSavingScreen> createState() => _AddGoalSavingScreenState();
}

class _AddGoalSavingScreenState extends State<AddGoalSavingScreen> {
  // ความสูงคงที่ของแผงปุ่มตัวเลขที่จะเลื่อนขึ้นมาจากด้านล่าง
  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
  static const double _numpadHeight = 300;
  static const Duration _numpadAnim = Duration(milliseconds: 260);

  IconData _selectedIcon = _goalIcons.first;
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _amountText = '';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 180));
  bool _saving = false;

  // true เมื่อผู้ใช้กำลังจะพิมพ์จำนวนเงิน -> โชว์แป้นตัวเลข + เคอร์เซอร์กระพริบ
  bool _showNumpad = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _openNumpad() {
    // เอา focus ออกจากช่องชื่อเป้าหมาย/หมายเหตุ
    FocusScope.of(context).unfocus();

    // ซ่อน keyboard ของมือถือ
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();

    setState(() {
      _showNumpad = true;
    });
  }

  void _closeNumpad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    if (_showNumpad) {
      setState(() {
        _showNumpad = false;
      });
    }
  }

  void _finishAmountInput() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.lightImpact();

    setState(() {
      _showNumpad = false;
    });
  }

  void _pressDigit(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      if (d == '.' && _amountText.contains('.')) return;
      _amountText += d;
    });
  }

  void _backspace() {
    if (_amountText.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _amountText = _amountText.substring(0, _amountText.length - 1));
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountText) ?? 0;
    final service = context.read<DataService>();
    if (_nameCtrl.text.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('fill_name_and_amount'))));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final error = await service.addGoal(
          name: _nameCtrl.text,
          targetAmount: amount,
          targetDate: _targetDate,
          icon: _selectedIcon,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        );

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('goal_saving'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _saveButton(service)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ----- เนื้อหาหลักของหน้า -----
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ----- 1. ชื่อเป้าหมาย -----
                          AppTextField(
                            controller: _nameCtrl,
                            hint: service.t('goal_name_hint'),
                            icon: Icons.flag_outlined,
                          ),
                          const SizedBox(height: 20),
                          // ----- 2. หมวดหมู่ (เลือกไอคอนเป้าหมาย) -----
                          Row(
                            children: [
                              Text(service.t('categories'), style: AppTextStyles.heading),
                              const Spacer(),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      _goalTint[_goalIcons.indexOf(_selectedIcon) % _goalTint.length],
                                      Colors.white,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _goalTintIcon[_goalIcons.indexOf(_selectedIcon) % _goalTintIcon.length]
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: GoalArtwork(_selectedIcon,
                                    size: 16,
                                    color: _goalTintIcon[_goalIcons.indexOf(_selectedIcon) % _goalTintIcon.length]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 4,
                              mainAxisExtent: _showNumpad ? 72 : 96,
                            ),
                            itemCount: _goalIcons.length,
                            itemBuilder: (context, index) => _goalCategoryTile(
                              defaultCategories[index], service, index),
                          ),
                          const SizedBox(height: 20),
                          // ----- 3. วันที่เป้าหมาย -----
                          _dateCard(service),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // ----- 4. ช่องหมายเหตุ (ไม่บังคับ) -----
                  // ย้ายออกจากพื้นที่ scroll มาไว้ในโซนคงที่ด้านล่าง ให้ติดกันพอดี
                  // กับกล่อง "กรุณากรอกจำนวนเงิน" ด้านล่าง (ไม่มีช่องว่างมาคั่น)
                  // และจะเลื่อนขึ้น/ซ่อนตอนแป้นตัวเลขเปิดอยู่ กันไม่ให้แป้นบัง
                  ClipRect(
                    child: AnimatedAlign(
                      duration: _numpadAnim,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      heightFactor: _showNumpad ? 0 : 1,
                      child: AnimatedOpacity(
                        duration: _numpadAnim,
                        opacity: _showNumpad ? 0 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppTextField(
                            controller: _noteCtrl,
                            hint: service.t('note_optional'),
                            icon: Icons.edit_note_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // แถบจำนวนเงิน: แตะเพื่อเปิดแป้นตัวเลข พร้อมเคอร์เซอร์กระพริบระหว่างพิมพ์
                  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
                  _amountDisplay(),
                  // จองพื้นที่ด้านล่างเท่ากับความสูงแป้นตัวเลข เมื่อแป้นถูกเปิดอยู่
                  AnimatedContainer(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    height: _showNumpad ? panelHeight : bottomInset + 8,
                  ),
                ],
              ),
            ),
          ),

          // ----- ฉากทึบใส สำหรับแตะนอกพื้นที่แป้นตัวเลขเพื่อปิดแป้น -----
          if (_showNumpad)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeNumpad,
                child: Container(color: Colors.transparent),
              ),
            ),

          // ----- แผงปุ่มตัวเลข เลื่อนขึ้นจากด้านล่าง เฉพาะตอนต้องการพิมพ์จำนวนเงิน -----
          AnimatedPositioned(
            duration: _numpadAnim,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showNumpad ? 0 : -panelHeight,
            child: _numpadPanel(bottomInset),
          ),
        ],
      ),
    );
  }

  // ---------- ปุ่มบันทึกบน AppBar ----------
  Widget _saveButton(DataService service) {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentPink, AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPink.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _saving
            ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(service.t('save'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  // ---------- การ์ดเลือกวันที่เป้าหมาย ----------
  Widget _goalCategoryTile(CategoryModel c, DataService service, int index) {
    final selected = _selectedIcon == c.icon;
    final tintIcon = _goalTintIcon[index % _goalTintIcon.length];
    final pastel = [AppColors.accentBg, AppColors.accentAltBg,
      const Color(0xFFEAE5FA), const Color(0xFFE1F2EC)][index % 4];
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        HapticFeedback.selectionClick();
        setState(() {
          _selectedIcon = c.icon;

        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // เพิ่มเอฟเฟกต์ "เด้งเล็กน้อย" ตอนถูกเลือก ให้ดูมีชีวิตชีวาน่ารักขึ้น
          AnimatedScale(
            scale: selected ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOut,
            width: _showNumpad ? 44 : 60,
            height: _showNumpad ? 44 : 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_showNumpad ? 15 : 20),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.surfaceAlt, Color.lerp(AppColors.card, pastel, 0.7)!],
              ),
              border: Border.all(
                color: selected ? AppColors.accentPink : Color.lerp(AppColors.border, pastel, 0.6)!,
                width: selected ? 2 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? AppColors.accentPink.withOpacity(0.23)
                      : AppColors.accentDeep.withOpacity(0.09),
                  blurRadius: selected ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // ไอคอนขยายใหญ่ขึ้นให้ใช้พื้นที่ ~85% ของกล่อง (เหลือ margin ~8-12%)
            // ใช้ fill+zoom เพื่อ "ตัด" พื้นที่โปร่งใส/ขอบว่างรอบไฟล์ไอคอนต้นฉบับออกไปก่อน
            // แล้วจึงขยาย artwork จริงให้เต็มกรอบมากขึ้น โดยไม่ยืด/บิดสัดส่วน และไม่ทำให้กรอบ
            // (คอนเทนเนอร์ 60x60 ด้านนอก) ขยายขนาดตามไปด้วย
            child: Center(
              child: SizedBox(
                width: _showNumpad ? 38 : 52,
                height: _showNumpad ? 38 : 52,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.86, 0.08, 0.06, 0, 5,
                    0.04, 0.91, 0.05, 0, 3,
                    0.04, 0.09, 0.87, 0, 7,
                    0, 0, 0, 1, 0,
                  ]),
                  child: CategoryIcon(
                  category: c,
                  color: selected ? AppColors.accentDeep : tintIcon,
                  size: _showNumpad ? 38 : 52,
                  fill: true,
                  zoom: 1.12,
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard(DataService service) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            _closeNumpad();
            final isThai = service.currentLanguage != 'English';
            final picked = await showDialog<DateTime>(
              context: context,
              barrierColor: Colors.black.withOpacity(0.45),
              builder: (_) => PastelCalendarDialog(
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                isThai: isThai,
              ),
            );
            if (picked != null) setState(() => _targetDate = picked);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_rounded, color: AppColors.accentDeep, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.t('target_date_label'),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // กล่องแสดง/กรอกจำนวนเงิน: มีกรอบสีเดียวกับช่องอื่นๆ, มีลายน้ำตอนยังไม่กรอก,
  // และเคอร์เซอร์กระพริบอยู่ "หน้า" สัญลักษณ์ ฿ ระหว่างที่กำลังพิมพ์
  Widget _amountDisplay() {
    final service = context.read<DataService>();
    final showPlaceholder = !_showNumpad && _amountText.isEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openNumpad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _showNumpad ? AppColors.accentDeep : AppColors.border,
            width: _showNumpad ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_showNumpad ? AppColors.accentDeep : Colors.black)
                  .withOpacity(_showNumpad ? 0.16 : 0.04),
              blurRadius: _showNumpad ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: showPlaceholder
            ? Row(
                children: [
                  Icon(Icons.savings_outlined, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.t('enter_valid_amount'),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _amountText,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      if (_showNumpad) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(color: AppColors.accentDeep, height: 24),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        context.watch<DataService>().currencySymbol,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ],
                  ),
                  if (_showNumpad) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _finishAmountInput,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentDeep.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 23),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // แผงปุ่มตัวเลขทั้งชุด (ความสูงคงที่ ลอยขึ้นมาจากขอบล่างจอ)
  Widget _numpadPanel(double bottomInset) {
    return Material(
      color: AppColors.bg,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: _numpadHeight + bottomInset,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // แถบจับเล็กๆ ด้านบน ให้ดูเหมือนแผ่นเลื่อนขึ้นมา (bottom sheet)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _numPad()),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _numPad() {
    const rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: rows
            .map((row) => Expanded(
                  child: Row(
                    children: row
                        .map((key) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _keyBg(key),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _keyShadow(key),
                                        offset: const Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(22),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => key == '⌫' ? _backspace() : _pressDigit(key),
                                      child: Center(
                                        child: key == '⌫'
                                            ? Icon(Icons.backspace_rounded, size: 20, color: _keyFg(key))
                                            : Text(key,
                                                style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    color: _keyFg(key))),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Color _keyBg(String key) {
    switch (key) {
      case '⌫':
        return const Color(0xFFDCEEF7);
      case '.':
        return const Color(0xFFFFF3D2);
      default:
        return AppColors.surface;
    }
  }

  Color _keyFg(String key) {
    switch (key) {
      case '⌫':
        return const Color(0xFF6FA3D6);
      case '.':
        return const Color(0xFFC79A3B);
      default:
        return AppColors.textPrimary;
    }
  }

  Color _keyShadow(String key) {
    switch (key) {
      case '⌫':
        return const Color(0xFFC3E0F0);
      case '.':
        return const Color(0xFFF0DFA8);
      default:
        return AppColors.border.withOpacity(0.8);
    }
  }
}

/// เคอร์เซอร์กระพริบ (เหมือนเคอร์เซอร์พิมพ์ข้อความ) ใช้แสดงต่อท้ายจำนวนเงิน
/// ระหว่างที่แป้นตัวเลขเปิดอยู่ ให้ผู้ใช้รู้ว่ากำลังอยู่ในโหมดพิมพ์
/// (คลาสเดียวกับที่ใช้ในหน้า Add Income/Expense)
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}