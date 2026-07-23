import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';


const List<IconData> _goalIcons = [
  Icons.restaurant, Icons.local_cafe, Icons.home, Icons.directions_car,
  Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer,
  Icons.pets, Icons.school,
];

/// หน้า Add Goal Saving (3.4.12) - เพิ่มเป้าหมายการออมเงินใหม่ลง SQLite
class AddGoalSavingScreen extends StatefulWidget {
  const AddGoalSavingScreen({super.key});

  @override
  State<AddGoalSavingScreen> createState() => _AddGoalSavingScreenState();
}

class _AddGoalSavingScreenState extends State<AddGoalSavingScreen> {
  IconData _selectedIcon = _goalIcons.first;
  final _nameCtrl = TextEditingController();
  String _amountText = '';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 180));
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
    final amount = double.tryParse(_amountText) ?? 0;
    if (_nameCtrl.text.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อและจำนวนเงินเป้าหมาย')));
      return;
    }

    setState(() => _saving = true);

    await context.read<DataService>().addGoal(
          name: _nameCtrl.text,
          targetAmount: amount,
          targetDate: _targetDate,
          icon: _selectedIcon,
        );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Goal Saving', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('SAVE',
                    style: TextStyle(
                        color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameCtrl,
              hint: 'ชื่อเป้าหมาย',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 18),
            const Text('Categories', style: AppTextStyles.heading),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: _goalIcons.map((icon) {
                final selected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: selected ? Colors.orange : AppColors.surface,
                      child: Icon(icon, size: 24, color: selected ? Colors.white : Colors.black54),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_outlined, color: Colors.grey.shade600),
                title: const Text('วันที่ต้องการให้ถึงเป้าหมาย', style: TextStyle(fontSize: 13.5)),
                subtitle: Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text('฿ $_amountText',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Expanded(child: _numPad()),
          ],
        ),
      ),
    );
  }

  Widget _numPad() {
    final keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫'];
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.9,
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
                  child: Text(key,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
            ),
          ),
        );
      },
    );
  }
}