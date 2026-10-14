import 'package:flutter/material.dart';
import '../screens/app_theme.dart';

/// Numeric amount entry with two decimal places and cursor-aware deletion.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.controller});
  final TextEditingController controller;
  static const double height = 232;

  void _press(String key) {
    final text = controller.text;
    final selection = controller.selection;
    var start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final replacement = key == '⌫' ? '' : key;
    if (key == '⌫' && start == end && start > 0) start--;
    var next = text.replaceRange(start, end, replacement);
    var cursor = start + replacement.length;
    if (next.startsWith('.')) {
      next = '0$next';
      cursor++;
    }
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(next) || next.length > 16) {
      return;
    }
    controller.value = TextEditingValue(
      text: next, selection: TextSelection.collapsed(offset: cursor));
  }

  Widget _key(String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16))),
          onPressed: () => _press(label),
          child: label == '⌫'
            ? const Icon(Icons.backspace_outlined, size: 23, semanticLabel: 'Delete')
            : Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(24)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final row in const [
        ['7', '8', '9'],
        ['4', '5', '6'],
        ['1', '2', '3'],
        ['.', '0', '⌫'],
      ])
        Row(children: row.map(_key).toList()),
    ]),
  ));
}

/// Opens the same amount keyboard for fields in dialogs and receipt forms.
Future<void> showAmountKeypad(
  BuildContext context, {
  required TextEditingController controller,
  required String title,
}) async {
  FocusScope.of(context).unfocus();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: TextStyle(color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: true,
            keyboardType: TextInputType.none,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, color: AppColors.ink),
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 8),
          AmountKeypad(
            controller: controller,
          ),
        ]),
      ),
    ),
  );
}
