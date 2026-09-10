import 'receipt_scan_screen.dart';
import '../widgets/pastel_artwork.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'income_expense_screen.dart';

const List<IconData> _customCategoryIcons = [
  Icons.category_outlined, Icons.restaurant, Icons.local_cafe, Icons.home,
  Icons.directions_car, Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer, Icons.pets,
  Icons.school, Icons.payments, Icons.trending_up, Icons.card_membership,
  Icons.savings, Icons.fastfood, Icons.local_hospital, Icons.build,
  Icons.pets_outlined, Icons.celebration, Icons.wifi, Icons.subscriptions,
];

// สีของ "ไอคอน" หมวดหมู่ (พื้นหลังกล่องไอคอนเป็นสีขาวล้วนเสมอ ใช้ชุดสีนี้แค่ทาสีตัวไอคอนเท่านั้น)
const List<Color> _categoryTintIcon = [
  Color(0xFF6FA3D6),
  Color(0xFFD9789B),
  Color(0xFFC79A3B),
  Color(0xFF8C79C9),
  Color(0xFF54A57E),
  Color(0xFFDB8A55),
  Color(0xFF4FA79C),
  Color(0xFFB1699F),
];

/// หน้า Add Income/Expense (3.4.10) — ปรับดีไซน์ให้ดูนุ่มนวล มีมิติ และน่ารักขึ้น
/// (โทนพาสเทลเดิม, ฟังก์ชันเดิมทั้งหมดไม่เปลี่ยนแปลง)
///
/// อัปเดต: `_save()` ปรับให้รองรับ `DataService.addTransaction()` เวอร์ชันใหม่
/// ที่คืนค่า `Future<String?>` (null = บันทึกสำเร็จ, มีข้อความ = บันทึกไม่สำเร็จ)
/// แทนที่จะปล่อยให้ exception หลุดออกมาอย่างเดียวเหมือนเดิม — ถ้ารายการไหนบันทึก
/// ไม่สำเร็จระหว่างลูป จะหยุดทันที ลบเฉพาะรายการที่บันทึกสำเร็จไปแล้วออกจากลิสต์
/// "รอบันทึก" (กันกดซ้ำซ้อน) ส่วนรายการที่เหลือ (รวมตัวที่ error) จะยังอยู่ให้กด
/// บันทึกใหม่ได้อีกครั้งโดยไม่ต้องกรอกซ้ำ
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key});

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  static const double _numpadHeight = 300;
  static const Duration _numpadAnim = Duration(milliseconds: 260);
  // ใช้ผูก _amountDisplay() กับ _numpadPanel() เป็นภูมิภาคเดียวกันสำหรับ TapRegion
  // เพื่อตรวจจับ "แตะข้างนอก" แล้วปิดแป้นตัวเลข โดยไม่บล็อกการเลื่อนจอ
  static const String _numpadGroupId = 'amount_numpad_group';

  CategoryType _type = CategoryType.income;
  CategoryModel? _selectedCategory;
  String _amountText = '';
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _showNumpad = false;

  String? _editingId;
  List<Map<String, dynamic>> _tempTransactions = [];
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _openNumpad() {
    FocusScope.of(context).unfocus();
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

  String _formatAmount(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _addOrUpdate() {
    final amount = double.tryParse(_amountText) ?? 0;

    final service = context.read<DataService>();
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('enter_amount'))));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('select_category'))));
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      if (_editingId != null) {
        final index = _tempTransactions.indexWhere((t) => t['id'] == _editingId);
        if (index != -1) {
          _tempTransactions[index] = {
            'amount': amount,
            'category': _selectedCategory!,
            'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
            'id': _editingId,
          };
        }
        _editingId = null;
      } else {
        _tempTransactions.add({
          'amount': amount,
          'category': _selectedCategory!,
          'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      _amountText = '';
      _noteCtrl.clear();
      _selectedCategory = null;
      _showNumpad = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startEdit(Map<String, dynamic> tx) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();

    setState(() {
      _editingId = tx['id'] as String;
      _selectedCategory = tx['category'] as CategoryModel;
      _type = _selectedCategory!.type;
      _amountText = _formatAmount(tx['amount'] as double);
      _noteCtrl.text = (tx['note'] as String?) ?? '';
      _showNumpad = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _selectedCategory = null;
      _amountText = '';
      _noteCtrl.clear();
      _showNumpad = false;
    });
  }

  void _removeTransaction(String id) {
    final index = _tempTransactions.indexWhere((t) => t['id'] == id);
    if (index == -1) return;
    final removed = _tempTransactions[index];

    HapticFeedback.lightImpact();
    setState(() {
      _tempTransactions.removeAt(index);
      if (_editingId == id) {
        _editingId = null;
        _selectedCategory = null;
        _amountText = '';
        _noteCtrl.clear();
        _showNumpad = false;
      }
    });

    // เผื่อลบผิดพลาด (เช่นปัดทิ้งพลาด) ให้กด "เลิกทำ" เพื่อดึงรายการกลับมาได้
    if (!mounted) return;
    final isThai = context.read<DataService>().currentLanguage != 'English';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isThai ? 'ลบรายการแล้ว' : 'Item removed'),
        action: SnackBarAction(
          label: isThai ? 'เลิกทำ' : 'Undo',
          onPressed: () {
            setState(() {
              final insertAt = index <= _tempTransactions.length ? index : _tempTransactions.length;
              _tempTransactions.insert(insertAt, removed);
            });
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// บันทึกทุกรายการใน "ลิสต์รอบันทึก" (_tempTransactions) ลง Firestore จริงทีละรายการ
  /// ผ่าน service.addTransaction() ซึ่งตอนนี้คืนค่า Future<String?>:
  ///   - null    = บันทึกรายการนั้นสำเร็จ
  ///   - String  = บันทึกไม่สำเร็จ (ข้อความ error ที่จะโชว์ให้ผู้ใช้เห็น)
  ///
  /// ถ้าเจอรายการที่บันทึกไม่สำเร็จระหว่างลูป จะหยุดทันที (ไม่ยิงรายการถัดไปต่อ)
  /// แล้วเอาเฉพาะรายการที่ "บันทึกสำเร็จไปแล้วก่อนหน้า" ออกจากลิสต์รอบันทึก
  /// (กันผู้ใช้กดบันทึกซ้ำแล้วรายการเดิมถูกเพิ่มซ้ำสอง) ส่วนรายการที่เหลือ (รวมตัว
  /// ที่ error) จะยังค้างอยู่ในลิสต์ให้กดปุ่มบันทึกใหม่ได้อีกครั้งโดยไม่ต้องกรอกซ้ำ
  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    if (_tempTransactions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('add_at_least_one'))));
      return;
    }

    setState(() => _saving = true);

    try {
      final savedIds = <String>{};
      for (final tx in _tempTransactions) {
        final error = await service.addTransaction(
          type: tx['category'].type,
          amount: tx['amount'],
          category: tx['category'],
          date: DateTime.now(),
          note: tx['note'],
        );

        if (error != null) {
          if (mounted) {
            setState(() {
              _tempTransactions =
                  _tempTransactions.where((t) => !savedIds.contains(t['id'])).toList();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          }
          return;
        }

        savedIds.add(tx['id'] as String);
      }

      if (!mounted) return;
      _tempTransactions.clear();
      _editingId = null;
      _selectedCategory = null;

      Navigator.pushReplacement(
          context, noAnimationRoute(const IncomeExpenseScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${service.t('save_failed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;
    final typeAccent = _type == CategoryType.income ? AppColors.income : AppColors.expense;

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                AppHeader(
                  title: service.t('income_expense'),
                  onBack: () => Navigator.pushReplacement(
                      context, noAnimationRoute(const HomeScreen())),
                  trailing: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withOpacity(0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.savings_rounded, color: AppColors.accentDeep, size: 16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _typeToggle(),
                      const Spacer(),
                      _saveButton(service),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBg,
                        foregroundColor: AppColors.ink,
                        surfaceTintColor: Colors.transparent,
                        elevation: 3,
                        shadowColor: AppColors.shadow,
                        minimumSize: const Size.fromHeight(76),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        side: BorderSide(color: AppColors.accent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _saving ? null : () async {
                        _closeNumpad();
                        final saved = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => const ReceiptScanScreen()));
                        if (saved == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(service.currentLanguage == 'English' ? 'Receipt expense saved' : 'บันทึกรายจ่ายจากใบเสร็จแล้ว')));
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(Icons.document_scanner_rounded, size: 28, color: AppColors.ink),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(service.currentLanguage == 'English' ? 'Add from receipt' : 'เพิ่มจากใบเสร็จ',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(service.currentLanguage == 'English' ? 'Take a photo or choose an image' : 'ถ่ายรูปหรือเลือกรูป เพื่อช่วยกรอกยอดเงิน',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 23, color: AppColors.ink),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(service.t('categories'), style: AppTextStyles.heading),
                              const SizedBox(width: 5),
                              Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accentPink),
                              const Spacer(),
                              Text(service.t('showing_categories'),
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text('${categories.length}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _categoryRows(service, categories),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        if (_tempTransactions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${service.t('items_added')}: ${_tempTransactions.length} ${service.t('items_unit')} · ${service.t('tap_to_edit')}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // สรุปยอดรวมรายรับ/รายจ่าย/สุทธิของรายการที่ "รอบันทึก" อยู่
                          // ให้ผู้ใช้เห็นผลลัพธ์ก่อนกด Save จริง ลดโอกาสกรอกผิดแล้วไม่รู้ตัว
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _pendingSummaryCard(),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: _tempTransactions.map((tx) => _transactionTile(tx, service)).toList(),
                            ),
                          ),
                        ] else ...[
                          // คำแนะนำสั้นๆ ตอนยังไม่มีรายการ ช่วยให้ผู้ใช้ใหม่รู้ว่าต้องทำอะไรต่อ
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  CuteMascot(
                                      kind: CuteMascotKind.income,
                                      size: 20,
                                      color: AppColors.accentDeep),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      service.currentLanguage != 'English'
                                          ? 'แตะเลือกหมวดหมู่ด้านบน แล้วกรอกจำนวนเงินเพื่อเพิ่มรายการนะ 🌱'
                                          : 'Tap a category above, then enter an amount to add an item 🌱',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _editingId != null
                            ? Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentBg,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Icon(Icons.edit_rounded, size: 12, color: AppColors.ink),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${service.t('editing')}: ${_selectedCategory != null ? service.categoryName(_selectedCategory!) : ''}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _cancelEdit,
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    child: Text(service.t('cancel_edit'), style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  if (_selectedCategory != null)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.only(right: 7),
                                      decoration: BoxDecoration(color: typeAccent, borderRadius: BorderRadius.circular(2)),
                                    ),
                                  Expanded(
                                    child: Text(
                                      _selectedCategory != null
                                          ? '${service.t('selected_category')}: ${service.categoryName(_selectedCategory!)}'
                                          : service.t('select_category_prompt'),
                                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      _addButton(),
                    ],
                  ),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    heightFactor: _showNumpad ? 0 : 1,
                    child: AnimatedOpacity(
                      duration: _numpadAnim,
                      opacity: _showNumpad ? 0 : 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: AppTextField(
                          controller: _noteCtrl,
                          hint: service.t('note_optional'),
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _amountDisplay(),
                AnimatedContainer(
                  duration: _numpadAnim,
                  curve: Curves.easeOutCubic,
                  height: _showNumpad ? panelHeight : bottomInset + 8,
                ),
              ],
            ),
          ),

          // เดิมใช้ Positioned.fill(GestureDetector) คลุมทั้งจอเพื่อปิดแป้นเมื่อแตะข้างนอก
          // แต่วิธีนั้นทำให้ "การเลื่อนหน้าจอถูกบล็อกไปด้วย" เพราะ Flutter จะหยุดทดสอบ
          // การสัมผัสที่ widget ทึบตัวแรกที่เจอใน Stack (แม้จะตั้ง translucent ก็ตาม)
          // เปลี่ยนมาใช้ TapRegion แทน ซึ่งตรวจจับ "แตะข้างนอก" ได้โดยไม่ไปขวางการลาก/เลื่อน
          // ของเนื้อหาด้านล่าง ผู้ใช้เลื่อนดูรายการ/หมวดหมู่ได้ตามปกติแม้แป้นตัวเลขเปิดอยู่

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
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  // ---------- ปุ่มบันทึก ----------
  Widget _saveButton(DataService service) {
    final disabled = _saving || _tempTransactions.isEmpty;
    return GestureDetector(
      onTap: disabled ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [AppColors.accentPink, AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: disabled ? AppColors.textMuted : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.accentPink.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: _saving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 5),
                  Text(service.t('save'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  // ---------- ปุ่มเพิ่ม/ยืนยันแก้ไข ----------
  Widget _addButton() {
    final isEditing = _editingId != null;
    return GestureDetector(
      onTap: _addOrUpdate,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEditing
                ? [AppColors.accentDeep, AppColors.accentDeep]
                : [AppColors.accentPink, AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPink.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(isEditing ? Icons.check_rounded : Icons.add_rounded,
            color: Colors.white, size: 28),
      ),
    );
  }

  // ---------- การ์ดสรุปยอดรวมรายการที่ "รอบันทึก" ----------
  Widget _pendingSummaryCard() {
    double income = 0;
    double expense = 0;
    for (final tx in _tempTransactions) {
      final amt = tx['amount'] as double;
      if ((tx['category'] as CategoryModel).type == CategoryType.income) {
        income += amt;
      } else {
        expense += amt;
      }
    }
    final net = income - expense;
    final isThai = context.read<DataService>().currentLanguage != 'English';

    Widget item(String label, double value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              context.watch<DataService>().formatMoney(value),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          item(isThai ? 'รายรับรวม' : 'Income', income, AppColors.income),
          Container(width: 1, height: 28, color: AppColors.border),
          item(isThai ? 'รายจ่ายรวม' : 'Expense', expense, AppColors.expense),
          Container(width: 1, height: 28, color: AppColors.border),
          item(isThai ? 'ยอดสุทธิ' : 'Net', net, net >= 0 ? AppColors.income : AppColors.expense),
        ],
      ),
    );
  }

  // ---------- รายการที่เพิ่มแล้ว ----------
  Widget _transactionTile(Map<String, dynamic> tx, DataService service) {
    final isEditing = tx['id'] == _editingId;
    final isIncome = tx['category'].type == CategoryType.income;
    final accent = isIncome ? AppColors.income : AppColors.expense;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // ปัดซ้ายเพื่อลบรายการได้ทันที (นอกเหนือจากปุ่ม X เดิม) — เร็วกว่าสำหรับ
      // คนที่มีหลายรายการ และยังลบผิดแล้วกด "เลิกทำ" ใน Snackbar ได้เหมือนเดิม
      child: Dismissible(
        key: ValueKey(tx['id']),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _removeTransaction(tx['id']),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        child: GestureDetector(
        onTap: () => _startEdit(tx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isEditing ? AppColors.accentBg : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isEditing ? AppColors.accentPink : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
                        ),
                        child: Center(
                          child: CategoryIcon(
                              category: tx['category'], size: 18, color: accent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.categoryName(tx['category']),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                            if (tx['note'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(tx['note'],
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      Text('${isIncome ? '+' : '-'}${context.watch<DataService>().formatMoney(tx['amount'] as double)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13.5)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeTransaction(tx['id']),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.close_rounded, size: 15, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
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

  // ---------- ช่องแสดง/กรอกจำนวนเงิน ----------
  Widget _amountDisplay() {
    final showPlaceholder = !_showNumpad && _amountText.isEmpty;

    return TapRegion(
      groupId: _numpadGroupId,
      onTapOutside: (_) => _closeNumpad(),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openNumpad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _showNumpad ? AppColors.accentPink : AppColors.border,
            width: _showNumpad ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_showNumpad ? AppColors.accentPink : Colors.black)
                  .withOpacity(_showNumpad ? 0.16 : 0.04),
              blurRadius: _showNumpad ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: showPlaceholder
            ? Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.payments_outlined, size: 14, color: AppColors.accentDeep),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กรุณาระบุจำนวนเงิน',
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (_showNumpad) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(color: AppColors.accentPink, height: 22),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        context.watch<DataService>().currencySymbol,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
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
                          borderRadius: BorderRadius.circular(AppRadius.md),
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
      ),
    );
  }

  // ---------- แผงปุ่มตัวเลข ----------
  Widget _numpadPanel(double bottomInset) {
    return TapRegion(
      groupId: _numpadGroupId,
      child: Material(
      color: AppColors.bg,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: _numpadHeight + bottomInset,
        child: Column(
          children: [
            const SizedBox(height: 10),
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
      ),
    );
  }

  // ---------- กริดหมวดหมู่ ----------
  Widget _categoryRows(DataService service, List<CategoryModel> categories) {
    final tiles = <Widget>[
      ...categories.asMap().entries.map((e) => _categoryTile(e.value, service, e.key)),
      _otherCategoryTile(service),
    ];

    // ใช้ shrinkWrap + NeverScrollableScrollPhysics แทนกล่องความสูงคงที่แบบเดิม
    // เดิม (SizedBox สูง 220 + ClampingScrollPhysics) ทำให้เกิด "สกอลล์ซ้อนสกอลล์"
    // กับหน้าจอหลักที่เลื่อนได้อยู่แล้ว ผู้ใช้ต้องเดาว่าต้องเลื่อนตรงไหนถึงจะเห็น
    // หมวดหมู่ที่ซ่อนอยู่ ให้กริดขยายตามจำนวนหมวดหมู่จริงและปล่อยให้หน้าจอหลัก
    // เป็นจุดเลื่อนเดียว ใช้งานลื่นไหลกว่าเดิมมาก
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 4,
          mainAxisExtent: _showNumpad ? 72 : 96,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }

  Widget _categoryTile(CategoryModel c, DataService service, int index) {
    final selected = _selectedCategory?.id == c.id;
    final tintIcon = _categoryTintIcon[index % _categoryTintIcon.length];
    final pastel = [AppColors.accentBg, AppColors.accentAltBg,
      const Color(0xFFEAE5FA), const Color(0xFFE1F2EC)][index % 4];
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCategory = c;
          _showNumpad = true;
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
          const SizedBox(height: 6),
          Text(
            service.categoryName(c),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _otherCategoryTile(DataService service) {
    return GestureDetector(
      onTap: () => _showAddCategoryDialog(service),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _showNumpad ? 44 : 60,
            height: _showNumpad ? 44 : 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_showNumpad ? 15 : 20),
              color: AppColors.accentAltBg,
              border: Border.all(
                color: AppColors.border,
                width: 1.4,
              ),
            ),
            child: Icon(Icons.add_rounded, color: AppColors.accentPink, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            service.t('other_category'),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(DataService service) async {
    _closeNumpad();
    final nameCtrl = TextEditingController();
    IconData selectedIcon = _customCategoryIcons.first;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        bool saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> confirm() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = service.t('please_enter_category_name'));
                return;
              }
              setDialogState(() {
                saving = true;
                errorText = null;
              });
              final created = await service.addCategory(name, _type, selectedIcon);
              if (!mounted) return;
              setState(() {
                _selectedCategory = created;
                _showNumpad = true;
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }

            return Dialog(
              backgroundColor: AppColors.bg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            gradient: LinearGradient(
                              colors: [AppColors.accentBg, AppColors.accentBg.withOpacity(0.6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: GoalArtwork(selectedIcon, size: 38),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(service.t('add_custom_category_title'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: nameCtrl,
                      hint: service.t('category_name_hint'),
                      icon: Icons.label_outline_rounded,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) setDialogState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('choose_icon'),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 140,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _customCategoryIcons.length,
                        itemBuilder: (context, i) {
                          final icon = _customCategoryIcons[i];
                          final selected = icon == selectedIcon;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setDialogState(() => selectedIcon = icon);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                gradient: selected
                                    ? LinearGradient(
                                        colors: [AppColors.accentBg, AppColors.accentAltBg])
                                    : null,
                                color: selected ? null : AppColors.surface,
                                border: Border.all(
                                  color: selected ? AppColors.accentPink : AppColors.border,
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accentDeep.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              padding: const EdgeInsets.all(5),
                              child: LayoutBuilder(
                                builder: (context, constraints) => GoalArtwork(
                                  icon, size: constraints.biggest.shortestSide),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : () => Navigator.pop(dialogContext),
                            child: Text(service.t('cancel'),
                                style:
                                    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.accentPink, AppColors.accentDeep],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPink.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                onTap: saving ? null : confirm,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  child: Center(
                                    child: saving
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white))
                                        : Text(service.t('add'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _typeToggle() {
    final service = context.watch<DataService>();
    final isIncome = _type == CategoryType.income;
    const toggleWidth = 176.0;
    const toggleHeight = 38.0;
    return Container(
      width: toggleWidth,
      height: toggleHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isIncome ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isIncome
                        ? [AppColors.income, AppColors.income.withOpacity(0.82)]
                        : [AppColors.expense, AppColors.expense.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.income;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.income,
                            color: isIncome ? Colors.white : AppColors.income,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('incomes_tab')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.expense;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.expense,
                            color: !isIncome ? Colors.white : AppColors.expense,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: !isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('expenses_tab')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                                child: _NumpadKey(
                                  label: key,
                                  bg: _keyBg(key),
                                  fg: _keyFg(key),
                                  shadow: _keyShadow(key),
                                  onTap: () => key == '⌫' ? _backspace() : _pressDigit(key),
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

  // สีคีย์แบบพาสเทลหลากสี พร้อมเงาโทนเข้มกว่านิดหน่อยให้ดูเป็นปุ่มกดมีมิติน่ารัก
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

/// เคอร์เซอร์กระพริบ ใช้แสดงต่อท้ายจำนวนเงินระหว่างพิมพ์
/// ปุ่มตัวเลขของแป้นกด — เพิ่มลูกเล่นให้ "เด้ง" นิดๆ ตอนกด (ย่อขนาดแล้วดีดกลับ)
/// ให้ความรู้สึกนุ่มนวลน่ารักขึ้นกว่าปุ่มแบนราบเดิม โดยยังใช้สี/เงาชุดเดิมทั้งหมด
/// ตอนนี้ปุ่มเป็นสี่เหลี่ยมมุมโค้ง (ห่อด้วย AspectRatio 1:1 เพื่อให้เป็นสี่เหลี่ยมจัตุรัสสมบูรณ์แม้อยู่ใน Row/Expanded)
class _NumpadKey extends StatefulWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color shadow;
  final VoidCallback onTap;

  const _NumpadKey({
    required this.label,
    required this.bg,
    required this.fg,
    required this.shadow,
    required this.onTap,
  });

  @override
  State<_NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<_NumpadKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: widget.bg,
              boxShadow: [
                BoxShadow(
                  color: widget.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: widget.label == '⌫'
                  ? Icon(Icons.backspace_rounded, size: 20, color: widget.fg)
                  : Text(widget.label,
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600, color: widget.fg)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
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