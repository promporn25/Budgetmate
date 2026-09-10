import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/language_setup_screen.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DataService service;
  late MemoryDB db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = MemoryDB();
    service = DataService(database: db);
    service.currentUser = UserModel(id: 'u', name: 'User', email: 'u@example.com', createdAt: DateTime(2026), language: 'English', currency: 'USD');
    await db.insert('users', service.currentUser!.toMap());
  });
  tearDown(() => service.dispose());
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(value: service,
      child: const MaterialApp(home: LanguageSetupScreen())));
    await tester.pumpAndSettle();
  }
  testWidgets('loads saved language and currency; preview does not persist', (tester) async {
    await show(tester);
    expect(find.text('USD'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไทย').last);
    await tester.pumpAndSettle();
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(service.currentUser!.language, 'English');
    expect(db.tables['users']!['u']!['language'], 'English');
  });
  testWidgets('save failure stays on setup and restores controls', (tester) async {
    await show(tester);
    db.failWrites = true;
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSetupScreen), findsOneWidget);
    expect(find.textContaining('Write rejected'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  test('setup persists profile and local defaults', () async {
    await service.completeSetup(language: 'ไทย', currency: 'THB');
    expect(db.tables['users']!['u']!['language'], 'ไทย');
    expect(await service.getDefaultPreferences(), {'language':'ไทย','currency':'THB'});
    expect(await service.isSetupCompleted(), isTrue);
  });
  test('failed setup does not mark complete', () async {
    db.failWrites = true;
    await expectLater(service.completeSetup(language:'ไทย', currency:'THB'), throwsStateError);
    expect(await service.isSetupCompleted(), isFalse);
  });
}
