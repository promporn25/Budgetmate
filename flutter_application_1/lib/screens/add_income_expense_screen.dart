import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';

/// หน้า Add Income/Expense (3.4.10) - บันทึกรายการรายรับ-รายจ่ายใหม่
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key});

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  CategoryType _type = CategoryType.expense;
  CategoryModel? _selectedCategory;
  String _amountText = '';
  final _noteCtrl = TextEditingController();

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

  void _save() {
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
    service.addTransaction(
      type: _type,
      amount: amount,
      category: _selectedCategory!,
      date: DateTime.now(),
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income/Expense'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ToggleButtons(
              isSelected: [_type == CategoryType.expense, _type == CategoryType.income],
              borderRadius: BorderRadius.circular(20),
              onPressed: (i) => setState(() {
                _type = i == 0 ? CategoryType.expense : CategoryType.income;
                _selectedCategory = null;
              }),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Expense')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Income')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          // ใช้ ListView แนวนอนแทน GridView เพื่อให้แต่ละหมวดหมู่มีพื้นที่พอดี ไม่ล้นจอ (overflow)
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final c = categories[i];
                final selected = _selectedCategory?.id == c.id;
                return SizedBox(
                  width: 76,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              selected ? Colors.orange : Colors.grey.shade200,
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
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)', border: OutlineInputBorder()),
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
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
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
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(40),
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
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
