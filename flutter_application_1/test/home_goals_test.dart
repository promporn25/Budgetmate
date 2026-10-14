import 'package:budgetmate/models/goal_model.dart';
import 'package:budgetmate/widgets/pastel_artwork.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/screens/add_goal_saving_screen.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/home_screen.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  setUpAll(() => initializeDateFormatting('th'));
  late DataService service;
  setUp(() {
    service = DataService(database: MemoryDB())
      ..currentUser = UserModel(id: 'test', name: 'Test',
        email: 'test@example.com', createdAt: DateTime(2026));
  });
  tearDown(() => service.dispose());

  Future<void> showHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: service,
      child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
  }

  Future<void> addGoal(String name) async {
    expect(await service.addGoal(name: name, targetAmount: 1000,
      targetDate: DateTime(2027), icon: Icons.savings), isNull);
  }

  testWidgets('other artwork can be selected, saved and reopened on a goal', (tester) async {
    await addGoal('Custom artwork');
    await showHome(tester);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: service,
      child: MaterialApp(home: AddGoalSavingScreen(goal: service.goals.single))));
    await tester.pumpAndSettle();
    final other = find.byKey(const Key('goal-other-artwork'));
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(find.text('500 รูป'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'องุ่น');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('องุ่น'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: other, matching: find.byWidgetPredicate(
      (widget) => widget is PastelArtwork && widget.categoryNumber == 136)), findsOneWidget);
    await tester.tap(find.text(service.t('save')).first);
    await tester.pumpAndSettle();
    final stored = GoalModel.fromMap(service.goals.single.toMap('test'));
    expect(stored.artworkNumber, 136);
    expect(stored.copyWith(savedAmount: 10).artworkNumber, 136);
    await service.editGoal(stored.id, name: 'Updated name', targetAmount: 1000,
      targetDate: DateTime(2027), icon: stored.icon);
    expect(service.goals.single.artworkNumber, 136);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal notes appear on cards, open in full, and update after editing', (tester) async {
    const note = 'Save for a family holiday and accommodation';
    await service.addGoal(name: 'Holiday', targetAmount: 1000,
      targetDate: DateTime(2027), icon: Icons.savings, note: note);
    await showHome(tester);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: service,
      child: const MaterialApp(home: GoalSavingScreen())));
    await tester.pumpAndSettle();
    final id = service.goals.single.id;
    expect(find.byKey(ValueKey('goal-note-$id')), findsOneWidget);
    expect(find.text(note), findsOneWidget);
    await tester.tap(find.text('Holiday'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('goal-note-detail'))).data, note);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await service.editGoal(id, name: 'Holiday', targetAmount: 1000,
      targetDate: DateTime(2027), icon: Icons.savings, note: 'Updated note');
    await tester.pumpAndSettle();
    expect(find.text('Updated note'), findsOneWidget);
    expect(find.text(note), findsNothing);
    await service.editGoal(id, name: 'Holiday', targetAmount: 1000,
      targetDate: DateTime(2027), icon: Icons.savings, note: '');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('goal-note-$id')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home offers a goal even before the first one is created', (tester) async {
    await showHome(tester);
    final add = find.byKey(const Key('home-add-goal'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(AddGoalSavingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinned goals are visible and open savings', (tester) async {
    await addGoal('Holiday fund');
    await service.setGoalPinned(service.goals.single.id, true);
    await showHome(tester);
    final card = find.text('Holiday fund');
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    expect(tester.takeException(), isNull);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(GoalSavingScreen), findsOneWidget);
  });

  testWidgets('home only shows pinned goals and removes them when unpinned', (tester) async {
    await addGoal('Pinned fund');
    await addGoal('Recent fund');
    final id = service.goals.first.id;
    await showHome(tester);
    expect(find.text('Pinned fund'), findsNothing);
    expect(find.text('Recent fund'), findsNothing);
    await service.setGoalPinned(id, true);
    await tester.pumpAndSettle();
    expect(find.text('Pinned fund'), findsOneWidget);
    expect(find.text('Recent fund'), findsNothing);
    final secondId = service.goals.last.id;
    await service.setGoalPinned(secondId, true);
    await tester.pumpAndSettle();
    expect(find.text('Pinned fund'), findsOneWidget);
    expect(find.text('Recent fund'), findsOneWidget);
    await service.setGoalPinned(id, false);
    await tester.pumpAndSettle();
    expect(find.text('Pinned fund'), findsNothing);
    expect(find.text('Recent fund'), findsOneWidget);
    await service.setGoalPinned(secondId, false);
    await tester.pumpAndSettle();
    expect(find.text('Pinned fund'), findsNothing);
    expect(find.text('Recent fund'), findsNothing);
    expect(service.goals, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
