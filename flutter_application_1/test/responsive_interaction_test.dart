import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/add_goal_saving_screen.dart';
import 'package:budgetmate/screens/add_income_expense_screen.dart';
import 'package:budgetmate/screens/edit_transaction_screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/widgets/amount_keypad.dart';
import 'package:budgetmate/widgets/responsive_scale.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'responsive_test_support.dart';
import 'package:budgetmate/screens/transaction_details_sheet.dart';
import 'package:budgetmate/widgets/category_editor_sheet.dart';
import 'package:budgetmate/widgets/period_selector.dart';
import 'package:budgetmate/screens/login_screen.dart';
import 'package:budgetmate/screens/register_screen.dart';
import 'package:budgetmate/screens/change_password_screen.dart';
import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await initializeDateFormatting('th');
    await (FontLoader(appFontFamily)
          ..addFont(rootBundle.load('assets/fonts/Mali-Regular.ttf')))
        .load();
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('forms keyboard and keypad $size dark=$dark', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        AppColors.brightness = dark ? Brightness.dark : Brightness.light;
        addTearDown(() => AppColors.brightness = Brightness.light);
        final service = DataService(database: MemoryDB())
          ..currentUser = UserModel(
              id: 'test',
              name: 'ทดสอบ',
              email: 'test@example.com',
              createdAt: DateTime(2026))
          ..categories.addAll(defaultCategories);
        addTearDown(service.dispose);
        await service.addTransaction(
            type: CategoryType.expense,
            amount: 10000,
            category: defaultCategories.first,
            date: DateTime.now());
        final screens = [
          const LoginScreen(),
          const RegisterScreen(),
          const ForgotPasswordScreen(),
          const ChangePasswordScreen(),
          const AddIncomeExpenseScreen(),
          const AddGoalSavingScreen(),
          EditTransactionScreen(transaction: service.transactions.first),
        ];
        for (final screen in screens) {
          await tester.pumpWidget(ChangeNotifierProvider.value(
              value: service,
              child: MaterialApp(
                  theme: phoneTheme(dark ? Brightness.dark : Brightness.light),
                  builder: (context, child) {
                    final mq = MediaQuery.of(context);
                    return MediaQuery(
                        data: mq.copyWith(
                            padding: EdgeInsets.only(
                                top: 59,
                                bottom: mq.viewInsets.bottom > 0 ? 0 : 34),
                            viewPadding:
                                const EdgeInsets.only(top: 59, bottom: 34),
                            textScaler: const TextScaler.linear(1.3)),
                        child: ResponsiveScale(child: child!));
                  },
                  home: screen)));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} initial');

          // Open the real editable field before simulating keyboard geometry.
          final field = find
              .byWidgetPredicate((w) => w is TextField && !w.readOnly)
              .first;
          await tester.ensureVisible(field);
          await tester.tap(field);
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} keyboard');
          final editable =
              find.descendant(of: field, matching: find.byType(EditableText));
          await tester.ensureVisible(editable);
          await tester.pump();
          expect(tester.getBottomRight(editable).dy,
              lessThanOrEqualTo(size.height - 260),
              reason: 'Focused input must remain above the keyboard');
          FocusManager.instance.primaryFocus?.unfocus();
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);

          if (screen is! EditTransactionScreen &&
              screen is! AddIncomeExpenseScreen &&
              screen is! AddGoalSavingScreen) {
            await tester.pumpWidget(const SizedBox());
            continue;
          }
          if (screen is EditTransactionScreen) {
            await tester.tap(
                find.byWidgetPredicate((w) => w is TextField && w.readOnly));
          } else {
            final amount = find.text(screen is AddGoalSavingScreen
                ? service.t('enter_valid_amount')
                : 'กรุณาระบุจำนวนเงิน');
            await tester.ensureVisible(amount);
            await tester.tap(amount);
          }
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} keypad');
          final key = find
              .descendant(
                  of: find.byType(AmountKeypad), matching: find.text('7'))
              .first;
          expect(
              tester.getRect(key).bottom, lessThanOrEqualTo(size.height - 34));
          await tester.tap(key);
          await tester.pump();
          final keypad =
              tester.widget<AmountKeypad>(find.byType(AmountKeypad).first);
          keypad.controller.text = '1234567890123.45';
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} long amount');
          await tester.pumpWidget(const SizedBox());
        }
        // Exercise overlays in the Navigator, not just their page variants.
        final overlays = <String, void Function(BuildContext)>{
          'calendar': (context) {
            showDialog<void>(
                context: context,
                builder: (_) => PastelCalendarDialog(
                    initialDate: DateTime(2026, 9, 28),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2200),
                    isThai: true));
          },
          'details': (context) {
            showTransactionDetails(context, service.transactions.first);
          },
          'edit': (context) {
            showEditTransactionSheet(context, service.transactions.first);
          },
          'category': (context) {
            showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => CategoryEditorSheet(
                    service: service, type: CategoryType.expense));
          },
        };
        for (final overlay in overlays.entries) {
          await tester.pumpWidget(ChangeNotifierProvider.value(
              value: service,
              child: MaterialApp(
                  theme: phoneTheme(AppColors.brightness),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          padding: EdgeInsets.only(
                              top: 59,
                              bottom:
                                  tester.view.viewInsets.bottom > 0 ? 0 : 34),
                          viewPadding:
                              const EdgeInsets.only(top: 59, bottom: 34),
                          textScaler: const TextScaler.linear(1.3)),
                      child: ResponsiveScale(child: child!)),
                  home: Builder(
                      builder: (context) => Scaffold(
                          body: Center(
                              child:
                                  TextButton(onPressed: () => overlay.value(context), child: const Text('Open'))))))));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: overlay.key);
          if (overlay.key == 'details' || overlay.key == 'edit') {
            final title = find
                .text(overlay.key == 'details' ? 'รายละเอียด' : 'แก้ไขรายการ')
                .first;
            expect(tester.getRect(title).top, greaterThanOrEqualTo(59),
                reason: 'Sheet title must clear the notch');
          }
          if (overlay.key == 'edit' || overlay.key == 'category') {
            final input = find
                .byWidgetPredicate((w) => w is TextField && !w.readOnly)
                .first;
            await tester.ensureVisible(input);
            await tester.tap(input);
            tester.view.viewInsets = const FakeViewPadding(bottom: 260);
            await tester.pumpAndSettle();
            await tester.ensureVisible(input);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${overlay.key} keyboard');
            expect(tester.getRect(input).bottom,
                lessThanOrEqualTo(size.height - 260));
          }
          await tester.pumpWidget(const SizedBox());
          tester.view.viewInsets = const FakeViewPadding();
        }
      });
    }
  }
}
