import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'Income expense overview.dart';
import 'home_screen.dart';

/// หน้า Add Income/Expense (3.4.10) - บันทึกรายการรายรับ-รายจ่ายใหม่ลง SQLite
/// - แท็บ "Incomes": ฟอร์มเลือกหมวดหมู่ (รวมทุกหมวด ทั้งรายรับ-รายจ่าย) + numpad + SAVE
///   ประเภทของรายการที่บันทึก จะอิงตามหมวดหมู่ที่เลือก (ไม่ได้ล็อกเป็น "income" เสมอไป)
/// - แท็บ "Expenses": แสดงภาพรวม pie chart + ประวัติ (widget เดียวกับหน้า Income/Expense)
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key});

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  CategoryType _type = CategoryType.income;
  CategoryModel? _selectedCategory;
  String _amountText = '';
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  void _pressDigit(String d) {
    setState(() {
      if (d == '.' && _amountText.contains('.')) return;
      _amountText += d;
    });
  }

  void _backspace() {
    if (_amountText.isEmpty) return;
    setState(() => _amountText = _amountText.substring(0, _amountText.length - 1));
  }

  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาระบุจำนวนเงิน')));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกหมวดหมู่')));
      return;
    }

    setState(() => _saving = true);

    await service.addTransaction(
      // ใช้ประเภทของ "หมวดหมู่ที่เลือก" เป็นตัวกำหนดว่ารายการนี้เป็นรายรับหรือรายจ่าย
      // เพราะฟอร์มนี้รวมหมวดหมู่ทั้งสองประเภทไว้ให้เลือกในที่เดียว
      type: _selectedCategory!.type,
      amount: amount,
      category: _selectedCategory!,
      date: DateTime.now(),
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    // แท็บ Incomes: รวมหมวดหมู่ทุกประเภท (รายรับ + รายจ่าย) ให้เลือกในที่เดียว
    final categories = service.categories;
    final showOverview = _type == CategoryType.expense;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Income/Expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _typePill(
                  label: 'Incomes',
                  selected: _type == CategoryType.income,
                  onTap: () => setState(() {
                    _type = CategoryType.income;
                    _selectedCategory = null;
                  }),
                ),
                const SizedBox(width: 10),
                _typePill(
                  label: 'Expenses',
                  selected: _type == CategoryType.expense,
                  onTap: () => setState(() {
                    _type = CategoryType.expense;
                    _selectedCategory = null;
                  }),
                ),
                const Spacer(),
                // ปุ่ม SAVE มีไว้สำหรับบันทึกรายการใหม่เท่านั้น
                // ตอนแท็บ "Expenses" หน้าจะสลับไปแสดงภาพรวม/ประวัติแทนฟอร์มกรอกเงิน จึงไม่ต้องมีปุ่มนี้
                if (!showOverview)
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('SAVE',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (showOverview)
            // แท็บ "Expenses": แสดงภาพรวม pie chart + ประวัติ (widget เดียวกับหน้า Income/Expense)
            const Expanded(child: IncomeExpenseOverview())
          else ...[
            // แท็บ "Incomes": ฟอร์มกรอกรายการใหม่ - เลือกได้จากหมวดหมู่ทั้งหมด
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('แสดงรายการทั้งหมด: ${categories.length} รายการ',
                    style: AppTextStyles.caption),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Categories', style: AppTextStyles.heading),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              // สูงพอสำหรับ 2 แถว
              height: 184,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  // ตอน scrollDirection เป็น horizontal, crossAxisCount = จำนวนแถว
                  crossAxisCount: 2,
                  mainAxisExtent: 76,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final c = categories[i];
                  final selected = _selectedCategory?.id == c.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: selected ? Colors.orange : AppColors.surface,
                          child: Icon(c.icon,
                              color: selected ? Colors.white : Colors.black54, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c.name,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppTextField(
                controller: _noteCtrl,
                hint: 'หมายเหตุ (ไม่บังคับ)',
                icon: Icons.edit_note_rounded,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('฿ $_amountText',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(child: _numPad()),
          ],
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  Widget _typePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _numPad() {
    final keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫'];
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.7,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => key == '⌫' ? _backspace() : _pressDigit(key),
              child: Center(
                child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
      },
    );
  }
}