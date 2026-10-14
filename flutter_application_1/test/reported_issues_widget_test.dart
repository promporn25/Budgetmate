import 'package:budgetmate/widgets/category_editor_sheet.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:budgetmate/screens/home_screen.dart';
import 'package:budgetmate/screens/add_income_expense_screen.dart';
import 'package:budgetmate/widgets/amount_keypad.dart';
import 'package:budgetmate/screens/add_goal_saving_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/edit_transaction_screen.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/income expense overview.dart';
import 'package:budgetmate/screens/register_screen.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  setUpAll(() => initializeDateFormatting('th'));
  late DataService service;
  setUp(() {
    service = DataService(database: MemoryDB())
      ..currentUser = UserModel(
          id: 'test',
          name: 'Test',
          email: 'test@example.com',
          createdAt: DateTime(2026))
      ..categories.addAll(defaultCategories);
  });
  tearDown(() => service.dispose());
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: service, child: MaterialApp(home: child)));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String value) async {
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    for (final digit in value.split('')) {
      final key = find.widgetWithText(FilledButton, digit);
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pump();
    }
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  for (final goal in [false, true]) {
    testWidgets('shared numeric keypad opens and enters amounts on ${goal ? 'goal' : 'transaction'} screen',
        (tester) async {
      await show(tester, goal ? const AddGoalSavingScreen() : const AddIncomeExpenseScreen());
      await tester.tap(find.text(goal ? service.t('enter_valid_amount') : 'กรุณาระบุจำนวนเงิน'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AmountKeypad), findsOneWidget);
      for (final key in ['2', '3']) {
        await tester.tap(find.widgetWithText(FilledButton, key));
        await tester.pump();
      }
      final keypad = tester.widget<AmountKeypad>(find.byType(AmountKeypad));
      expect(keypad.controller.text, '23');
      if (goal) {
        await tester.tapAt(const Offset(10, 350));
      } else {
        expect(find.text('บันทึกรายการ'), findsNothing);
        await tester.tap(find.byIcon(Icons.check_rounded).last);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    });
  }


  for (final systemBack in [false, true]) {
    testWidgets('wallet back preserves login ($systemBack)', (tester) async {
      await show(tester, Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const WalletScreen())),
        child: const Text('Login route')))));
      await tester.tap(find.text('Login route'));
      await tester.pumpAndSettle();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const Key('wallet-back')));
      }
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Login route'), findsNothing);
      expect(service.currentUser?.id, 'test');
    });
  }

  testWidgets('search category and save using the header action', (tester) async {
    final category = defaultCategories.firstWhere((c) => c.type == CategoryType.expense);
    await show(tester, const AddIncomeExpenseScreen());
    await tester.enterText(find.byKey(const Key('category-search')), service.categoryName(category));
    await tester.pump();
    await tester.tap(find.text(service.categoryName(category)).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final key in ['2', '5']) {
      await tester.tap(find.widgetWithText(FilledButton, key));
      await tester.pump();
    }
    expect(find.text('บันทึกรายการ'), findsNothing);
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('save')).first);
    await tester.pumpAndSettle();
    expect(service.transactions, hasLength(1));
    expect(service.transactions.single.amount, 25);
    expect(service.transactions.single.type, CategoryType.expense);
    final notice = find.text(service.t('transaction_saved'));
    expect(notice, findsOneWidget);
    expect(tester.getTopLeft(notice).dy, lessThan(150));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom category sheet saves and selects a new category', (tester) async {
    await show(tester, const AddIncomeExpenseScreen());
    await tester.ensureVisible(find.text(service.t('other_category')));
    await tester.tap(find.text(service.t('other_category')));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, service.t('category_name_hint'));
    await tester.enterText(name, 'New category');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.widgetWithText(FilledButton, service.t('save')).last);
    await tester.tap(find.widgetWithText(FilledButton, service.t('save')).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.categories.any((c) => c.name == 'New category'), isTrue);
    expect(find.byType(AmountKeypad), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category editor chooses artwork, color and subcategories', (tester) async {
    await show(tester, const AddIncomeExpenseScreen());
    await tester.ensureVisible(find.text(service.t('other_category')));
    await tester.tap(find.text(service.t('other_category')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, service.t('choose_icon')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('category-artwork-grid')), matching: find.byType(Text)), findsNothing);
    expect(find.text('500 รูป'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'เกม');
    await tester.pump();
    await tester.tap(find.byTooltip('เกม'));
    await tester.pumpAndSettle();
    final editor = find.byType(CategoryEditorSheet);
    await tester.tap(find.descendant(of: editor, matching: find.bySemanticsLabel('สี 2')));
    await tester.enterText(find.widgetWithText(TextField, service.t('category_name_hint')), 'Fun');
    tester.testTextInput.hide();
    await tester.tap(find.byTooltip('เพิ่มหมวดหมู่ย่อย'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'ชื่อหมวดหมู่ย่อย'), 'Games');
    tester.testTextInput.hide();
    final save = find.descendant(of: editor, matching: find.widgetWithText(FilledButton, service.t('save')));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final category = service.categories.firstWhere((c) => c.name == 'Fun');
    expect(category.artworkNumber, 55);
    expect(category.colorValue, 0xFFF6CCD9);
    expect(category.subcategories, ['Games']);
    expect(service.categories.any((c) => c.name == 'Fun › Games'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart matches all history and selected-day type filters', (tester) async {
    final income = defaultCategories.firstWhere((c) => c.type == CategoryType.income);
    final expense = defaultCategories.firstWhere((c) => c.type == CategoryType.expense);
    final today = DateTime.now();
    for (final row in [
      (CategoryType.income, income, 500.0, today),
      (CategoryType.expense, expense, 350.0, today),
      (CategoryType.expense, expense, 0.5, today.subtract(const Duration(days: 1))),
      (CategoryType.income, income, 100.0, today.subtract(const Duration(days: 1))),
    ]) {
      await service.addTransaction(type: row.$1, category: row.$2,
        amount: row.$3, date: row.$4);
    }
    await show(tester, const Scaffold(body: IncomeExpenseOverview()));
    List<double> values() => tester.widget<PieChart>(find.byType(PieChart))
      .data.sections.map((section) => section.value).toList();
    expect(values(), [600, 350.5]);
    await tester.tap(find.text(service.t('income')).last);
    await tester.pumpAndSettle();
    expect(values(), [500]);
    await tester.tap(find.text(service.t('expense')).last);
    await tester.pumpAndSettle();
    expect(values(), [350]);
    await tester.tap(find.text(service.t('all')).last);
    await tester.pumpAndSettle();
    expect(values(), [600, 350.5]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiny category keeps its amount without a zero percent label', (tester) async {
    final expenses = defaultCategories.where((c) => c.type == CategoryType.expense).toList();
    await service.addTransaction(type: CategoryType.expense, category: expenses[0],
      amount: 350, date: DateTime.now());
    await service.addTransaction(type: CategoryType.expense, category: expenses[1],
      amount: 0.5, date: DateTime.now());
    await show(tester, const Scaffold(body: IncomeExpenseOverview()));
    final sections = tester.widget<PieChart>(find.byType(PieChart)).data.sections;
    expect(sections.map((s) => s.value), [350, 0.5]);
    expect(sections.last.title, isEmpty);
    expect(find.text('0.1%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> addIncome() async {
    await service.addTransaction(
        type: CategoryType.income,
        amount: 500,
        category:
            defaultCategories.firstWhere((c) => c.type == CategoryType.income),
        date: DateTime.now(),
        note: 'ข้อความยาว 🍜💰✨ ทดสอบหมายเหตุ');
  }

  testWidgets(
      'income chart uses income, notes visible, delete can be cancelled',
      (tester) async {
    await addIncome();
    await show(
        tester,
        const Scaffold(
            body: IncomeExpenseOverview(initialFilter: HistoryFilter.income)));
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('ข้อความยาว 🍜💰✨ ทดสอบหมายเหตุ'), findsOneWidget);
    await tester.tap(find.byTooltip('จัดการรายการ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('cancel')));
    await tester.pumpAndSettle();
    expect(service.transactions, hasLength(1));
    await tester.tap(find.byTooltip('จัดการรายการ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, service.t('delete')));
    await tester.pumpAndSettle();
    expect(service.balance, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('transaction editor preloads note and saves to same id',
      (tester) async {
    await addIncome();
    final id = service.transactions.single.id;
    await show(tester,
        EditTransactionScreen(transaction: service.transactions.single));
    expect(find.text('ข้อความยาว 🍜💰✨ ทดสอบหมายเหตุ'), findsOneWidget);
    await enterAmount(tester, '800');
    await tester.enterText(find.byType(TextField).last, 'แก้ไขแล้ว ✨');
    tester.testTextInput.hide();
    await tester.tap(find.widgetWithText(FilledButton, service.t('save')));
    await tester.pumpAndSettle();
    expect(service.transactions.single.id, id);
    expect(service.transactions.single.note, 'แก้ไขแล้ว ✨');
    expect(service.balance, 800);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history opens details, edits and duplicates only after save',
      (tester) async {
    await addIncome();
    final originalId = service.transactions.single.id;
    await show(
        tester,
        const Scaffold(
            body: IncomeExpenseOverview(initialFilter: HistoryFilter.income)));
    await tester.tap(find.text('ข้อความยาว 🍜💰✨ ทดสอบหมายเหตุ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, service.t('edit')));
    await tester.pumpAndSettle();
    await enterAmount(tester, '700');
    tester.testTextInput.hide();
    await tester.tap(find.widgetWithText(FilledButton, service.t('save')));
    await tester.pumpAndSettle();
    expect(service.transactions.single.id, originalId);
    expect(service.balance, 700);
    await tester.tap(find.byTooltip('จัดการรายการ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ทำซ้ำ'));
    await tester.pumpAndSettle();
    expect(service.transactions, hasLength(1));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(service.transactions, hasLength(1));
    await tester.tap(find.byTooltip('จัดการรายการ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ทำซ้ำ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึกรายการใหม่'));
    await tester.pumpAndSettle();
    expect(service.transactions, hasLength(2));
    expect(service.transactions.map((t) => t.id).toSet(), hasLength(2));
    expect(service.balance, 1400);
    expect(tester.takeException(), isNull);
  });
  testWidgets('edit sheet keeps save visible with keyboard on a small phone',
      (tester) async {
    await addIncome();
    await show(
        tester,
        const Scaffold(
            body: IncomeExpenseOverview(initialFilter: HistoryFilter.income)));
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('จัดการรายการ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, service.t('edit')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, service.t('save')).hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('blank confirmation reports missing field before mismatch',
      (tester) async {
    await show(tester, const RegisterScreen());
    await tester.enterText(find.byType(TextField).at(0), 'Test');
    await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'd123456');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byType(PrimaryButton));
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(find.text(service.t('enter_confirm_password')), findsOneWidget);
    expect(find.text(service.t('password_mismatch')), findsNothing);
  });
  testWidgets('goals pin, confirm deletion, and accept typed deposit amounts',
      (tester) async {
    await addIncome();
    await service.addGoal(
        name: 'Phone',
        targetAmount: 100,
        targetDate: DateTime(2027),
        icon: Icons.savings);
    await show(tester, const GoalSavingScreen());
    await tester.tap(find.byTooltip(service.t('pin_goal')));
    await tester.pumpAndSettle();
    expect(service.pinnedGoals, hasLength(1));
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    await enterAmount(tester, '120');
    await tester.ensureVisible(
        find.widgetWithText(FilledButton, service.t('transfer')));
    await tester.tap(find.widgetWithText(FilledButton, service.t('transfer')));
    await tester.pumpAndSettle();
    expect(find.textContaining(service.t('amount_exceeds_prefix')),
        findsOneWidget);
    expect(service.goals.single.savedAmount, 0);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final depositController = tester.widget<AmountKeypad>(find.byType(AmountKeypad)).controller;
    depositController.selection = TextSelection(baseOffset: 0, extentOffset: depositController.text.length);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '2'));
    await tester.tap(find.widgetWithText(FilledButton, '5'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, service.t('transfer')));
    await tester.pumpAndSettle();
    expect(service.goals.single.savedAmount, 25);
    expect(service.balance, 475);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('cancel')));
    await tester.pumpAndSettle();
    expect(service.goals, hasLength(1));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.t('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, service.t('delete')));
    await tester.pumpAndSettle();
    expect(service.goals, isEmpty);
    expect(service.balance, 475);
    expect(tester.takeException(), isNull);
  });
  testWidgets('goal editor retains existing savings, icon and pin',
      (tester) async {
    await service.addGoal(
        name: 'Phone',
        targetAmount: 100,
        savedAmount: 25,
        targetDate: DateTime(2027),
        icon: Icons.savings,
        note: 'Original note');
    final goal = service.goals.single;
    await service.setGoalPinned(goal.id, true);
    await show(tester, AddGoalSavingScreen(goal: service.goals.single));
    expect(find.text('Original note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'New phone');
    tester.testTextInput.hide();
    await tester.tap(find.text(service.t('save')));
    await tester.pumpAndSettle();
    expect(service.goals.single.name, 'New phone');
    expect(service.goals.single.id, goal.id);
    expect(service.goals.single.icon.codePoint, Icons.savings.codePoint);
    expect(service.goals.single.savedAmount, 25);
    expect(service.pinnedGoals, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
