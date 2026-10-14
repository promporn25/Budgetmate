import 'dart:io';
import 'responsive_test_support.dart';
import 'package:budgetmate/widgets/responsive_scale.dart';
import 'package:budgetmate/screens/history_screen.dart';
import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'package:budgetmate/screens/change_password_screen.dart';
import 'package:budgetmate/screens/currency_screen.dart';
import 'package:budgetmate/screens/language_setup_screen.dart';
import 'package:budgetmate/screens/register_screen.dart';
import 'package:budgetmate/screens/login_screen.dart';
import 'package:budgetmate/screens/receipt_scan_screen.dart';
import 'dart:ui' as ui;
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/account_setting_screen.dart';
import 'package:budgetmate/screens/add_goal_saving_screen.dart';
import 'package:budgetmate/screens/add_income_expense_screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/edit_transaction_screen.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/home_screen.dart';
import 'package:budgetmate/screens/income_expense_screen.dart';
import 'package:budgetmate/screens/statistic_screen.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th');
    final fonts = FontLoader(appFontFamily)
      ..addFont(rootBundle.load('assets/fonts/Mali-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(402, 874),
    const Size(430, 932)
  ]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
            'phone cards fit $size $brightness text $scale with safe areas',
            (tester) async {
          final originalHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            originalHandler?.call(details);
          };
          AppColors.brightness = brightness;
          addTearDown(() => AppColors.brightness = Brightness.light);
          final service = DataService(database: MemoryDB())
            ..currentUser = UserModel(
                id: 'test',
                name: 'Budget Mate',
                email: 'test@example.com',
                createdAt: DateTime(2026))
            ..categories.addAll(defaultCategories);
          addTearDown(service.dispose);
          await service.addGoal(
              name: 'ท่องเที่ยวญี่ปุ่น',
              targetAmount: 25000,
              targetDate: DateTime(2027),
              icon: Icons.flight,
              note: 'เก็บเงินสำหรับทริปพักผ่อน');
          await service.setGoalPinned(service.goals.single.id, true);
          await service.addTransaction(
              type: CategoryType.income,
              amount: 10000000.99,
              category: defaultCategories
                  .firstWhere((c) => c.type == CategoryType.income),
              date: DateTime.now(),
              note: 'เงินเดือน');
          await service.addTransaction(
              type: CategoryType.expense,
              amount: 99999.99,
              category: defaultCategories
                  .firstWhere((c) => c.type == CategoryType.expense),
              date: DateTime.now(),
              note: 'ค่าใช้จ่ายสำหรับการเดินทางและพักผ่อนประจำเดือน');
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final screens = <String, Widget>{
            'history': const HistoryScreen(),
            'forgot_password': const ForgotPasswordScreen(),
            'receipt_scan': const ReceiptScanScreen(),
            'login': const LoginScreen(),
            'register': const RegisterScreen(),
            'language_setup': const LanguageSetupScreen(),
            'currency': const CurrencyScreen(),
            'change_password': const ChangePasswordScreen(),
            'home': const HomeScreen(),
            'wallet': const WalletScreen(),
            'settings': const AccountSettingScreen(),
            'goals': const GoalSavingScreen(),
            'statistics': const StatisticScreen(),
            'transactions': const IncomeExpenseScreen(),
            'add_transaction': const AddIncomeExpenseScreen(),
            'add_goal': const AddGoalSavingScreen(),
            'edit_transaction':
                EditTransactionScreen(transaction: service.transactions.first),
          };
          for (final entry in screens.entries) {
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(ChangeNotifierProvider.value(
                value: service,
                child: MaterialApp(
                    theme: phoneTheme(brightness),
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            padding: const EdgeInsets.only(top: 59, bottom: 34),
                            viewPadding:
                                const EdgeInsets.only(top: 59, bottom: 34),
                            textScaler: TextScaler.linear(scale)),
                        child: ResponsiveScale(child: child!)),
                    home: RepaintBoundary(
                        key: boundaryKey, child: entry.value))));
            // Allow layout and entry animations without waiting on network spinners.
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            final error = tester.takeException();
            if (error is FlutterError) debugPrint(error.toStringDeep());
            expect(error, isNull, reason: entry.key);
            if (const bool.fromEnvironment('CAPTURE_PHONE_LAYOUT') &&
                (size.width == 320 || size.width == 402) &&
                scale == 1.0) {
              await tester.runAsync(() async {
                final boundary = boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                final file = File(
                    '/tmp/budgetmate-phone-preview/${entry.key}-${size.width.toInt()}-${brightness.name}.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  }
}
