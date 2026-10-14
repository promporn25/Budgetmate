import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/home_screen.dart';
import 'package:budgetmate/screens/language_setup_screen.dart';
import 'package:budgetmate/screens/login_screen.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service_test.dart' show MemoryDB;

class GoogleLoginService extends DataService {
  GoogleLoginService({required this.newAccount, this.error})
      : super(database: MemoryDB());
  final bool newAccount;
  final String? error;
  @override
  bool get googleLoginCreatedAccount => newAccount;
  @override
  Future<String?> loginWithGoogle() async {
    if (error != null) return error;
    currentUser = UserModel(id: 'google-user', name: 'User',
      email: 'user@example.com', createdAt: DateTime(2026));
    notifyListeners();
    return null;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('th'));
  setUp(() => SharedPreferences.setMockInitialValues({
    'budgetmate_setup_completed': true,
  }));
  for (final newAccount in [true, false]) {
    testWidgets('Google login routes correctly for newAccount=$newAccount', (tester) async {
      final service = GoogleLoginService(newAccount: newAccount);
      addTearDown(service.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<DataService>.value(
        value: service, child: const MaterialApp(home: LoginScreen())));
      final button = find.widgetWithText(OutlinedButton, 'เข้าสู่ระบบด้วย Google');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSetupScreen), newAccount ? findsOneWidget : findsNothing);
      expect(find.byType(HomeScreen), newAccount ? findsNothing : findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed or cancelled Google login stays on login', (tester) async {
    final service = GoogleLoginService(newAccount: false, error: 'Login cancelled');
    addTearDown(service.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<DataService>.value(
      value: service, child: const MaterialApp(home: LoginScreen())));
    final button = find.widgetWithText(OutlinedButton, 'เข้าสู่ระบบด้วย Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login cancelled'), findsOneWidget);
    expect(find.byType(LanguageSetupScreen), findsNothing);
  });
}
