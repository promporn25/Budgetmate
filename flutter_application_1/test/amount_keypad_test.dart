import 'package:budgetmate/widgets/amount_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keypad has only digits, decimal and backspace', (tester) async {
    final controller = TextEditingController(text: '123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AmountKeypad(controller: controller))));
    expect(find.byType(FilledButton), findsNWidgets(12));
    for (final label in ['+', '−', '×', '÷', '=', 'C', 'Done', 'เสร็จสิ้น']) {
      expect(find.text(label), findsNothing);
    }
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    await tester.tap(find.widgetWithText(FilledButton, '5'));
    expect(controller.text, '15');
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    expect(controller.text, '1');
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared keypad limits decimals and resets after external edits',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AmountKeypad(
      controller: controller,
    ))));
    Future<void> press(String key) async {
      await tester.tap(find.widgetWithText(FilledButton, key));
      await tester.pump();
    }
    for (final key in ['.', '5', '.', '2', '3']) {
      await press(key);
    }
    expect(controller.text, '0.52');
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(controller.text, '0.5');
    controller.text = '20';
    await tester.pump();
    await press('5');
    expect(controller.text, '205');
    expect(controller.text, '205');
  });

  testWidgets('amount sheet works on a narrow phone without system keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showAmountKeypad(context, controller: controller,
          title: 'Amount'), child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, '7'));
    await tester.pump();
    expect(controller.text, '7');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AmountKeypad), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
