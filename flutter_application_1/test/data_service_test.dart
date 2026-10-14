import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/goal_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:budgetmate/services/db_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryDB implements DBHelper {
  final tables = <String, Map<String, Map<String, dynamic>>>{};
  bool failWrites = false;
  void check() { if (failWrites) throw StateError('Write rejected'); }
  @override
  Future<int> insert(String table, Map<String, dynamic> data) async {
    check();
    (tables[table] ??= {})[data['id'] as String] = {...data};
    return 1;
  }
  @override
  Future<int> update(String table, Map<String, dynamic> data, String where, List<Object?> args) async {
    check();
    tables[table]![args.first]!.addAll(data);
    return 1;
  }
  @override
  Future<int> delete(String table, String where, List<Object?> args) async {
    check();
    tables[table]?.remove(args.first);
    return 1;
  }
  @override
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<Object?>? whereArgs, String? orderBy}) async =>
    (tables[table]?.values ?? <Map<String, dynamic>>[])
      .where((row) => where == null || row[where.split('=').first.trim()] == whereArgs!.first)
      .map((row) => {...row}).toList();
  @override
  Future<Map<String, dynamic>> transferToGoal(String id, double amount, Map<String, dynamic> entry) async {
    check();
    final goal = tables['goals']![id]!;
    final saved = (goal['saved_amount'] as num) + amount;
    final updated = {...goal, 'saved_amount': saved,
      'status': saved >= (goal['target_amount'] as num) ? 'completed' : 'inProgress'};
    tables['goals']![id] = updated;
    await insert('transactions', entry);
    return updated;
  }
  @override
  Future<Map<String, dynamic>?> changeGoalTransfer(String id, Map<String, dynamic>? replacement) async {
    check();
    final old = tables['transactions']![id]!;
    final goalId = (old['description'] as String).substring('goal_transfer:'.length);
    final goal = tables['goals']?[goalId];
    Map<String, dynamic>? updated;
    if (goal != null) {
      double contribution(Map<String, dynamic>? row) => row != null && row['type'] == 'expense' && row['category_id'] == 'c17' ? (row['amount'] as num).toDouble() : 0;
      final saved = (goal['saved_amount'] as num).toDouble() - contribution(old) + contribution(replacement);
      if (saved < 0 || saved > (goal['target_amount'] as num)) throw StateError('Invalid savings');
      updated = {...goal, 'saved_amount': saved, 'status': saved >= (goal['target_amount'] as num) ? 'completed' : 'inProgress'};
      tables['goals']![goalId] = updated;
    }
    if (replacement == null) { tables['transactions']!.remove(id); }
    else { tables['transactions']![id] = replacement; }
    return updated;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryDB db;
  late DataService service;
  final income = defaultCategories.firstWhere((c) => c.type == CategoryType.income);
  final expense = defaultCategories.firstWhere((c) => c.type == CategoryType.expense);
  Future<String?> add(double amount, {bool spending = false, DateTime? date}) => service.addTransaction(
    type: spending ? CategoryType.expense : CategoryType.income, amount: amount,
    category: spending ? expense : income, date: date ?? DateTime(2026, 9, 8));
  setUp(() async {
    db = MemoryDB();
    service = DataService(database: db);
    service.currentUser = UserModel(id: 'test-user', name: 'Original', email: 'test@example.com', createdAt: DateTime(2026));
    service.categories.addAll(defaultCategories);
    await db.insert('users', service.currentUser!.toMap());
  });
  tearDown(() => service.dispose());
  test('custom category colors, artwork and child transactions survive reload', () async {
    final parent = await service.addCategory('Travel', CategoryType.expense, Icons.flight,
      artworkNumber: 107, colorValue: 0xFFF6CCD9, subcategories: ['Taxi', 'Hotel']);
    final child = service.categories.firstWhere((c) => c.name == 'Travel › Taxi');
    await service.addTransaction(type: CategoryType.expense, amount: 50,
      category: child, date: DateTime(2026, 9, 19));
    await service.refreshData();
    final reloaded = service.categories.firstWhere((c) => c.id == parent.id);
    expect(reloaded.colorValue, 0xFFF6CCD9);
    expect(reloaded.artworkNumber, 107);
    expect(reloaded.subcategories, ['Taxi', 'Hotel']);
    expect(service.transactions.single.category.id, child.id);
    expect(service.transactions.single.category.name, 'Travel › Taxi');
    expect(db.tables['categories'], hasLength(1));
  });
  test('failed category save leaves no partial children', () async {
    db.failWrites = true;
    final count = service.categories.length;
    await expectLater(service.addCategory('Travel', CategoryType.expense, Icons.flight,
      subcategories: ['Taxi']), throwsStateError);
    expect(service.categories.length, count);
  });


  test('income, expense and period summaries agree', () async {
    await add(100);
    await add(30, spending: true);
    expect(service.balance, 70);
    expect(service.dailyTotal(CategoryType.expense, DateTime(2026, 9, 8)), 30);
    expect(service.monthlyTotal(CategoryType.income, DateTime(2026, 9)), 100);
    expect(service.yearlyTotal(CategoryType.expense, 2026), 30);
  });
  test('invalid amounts never enter the ledger', () async {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(await add(amount), isNotNull);
    }
    expect(service.transactions, isEmpty);
  });
  test('backdated entries are sorted by date', () async {
    await add(10);
    await add(20, date: DateTime(2025));
    expect(service.transactions.first.amount, 10);
  });
  test('failed add edit and delete preserve ledger', () async {
    await add(100);
    final id = service.transactions.single.id;
    db.failWrites = true;
    expect(await add(50), isNotNull);
    await expectLater(service.editTransaction(id, amount: 50), throwsStateError);
    await expectLater(service.deleteTransaction(id), throwsStateError);
    expect(service.balance, 100);
    expect(service.transactions.length, 1);
  });
  test('profile changes apply only after persistence', () async {
    db.failWrites = true;
    await expectLater(service.updateProfile(name: 'Changed'), throwsStateError);
    expect(service.currentUser!.name, 'Original');
    db.failWrites = false;
    await service.updateProfile(name: 'Changed');
    expect(service.currentUser!.name, 'Changed');
    expect(db.tables['users']!['test-user']!['name'], 'Changed');
  });
  test('failed avatar removal preserves current profile image', () async {
    service.currentUser!.avatarBase64 = 'test-image';
    db.failWrites = true;
    await expectLater(service.removeAvatar(), throwsStateError);
    expect(service.currentUser!.avatarBase64, 'test-image');
  });
  test('refresh restores persisted entries and filters other users', () async {
    await add(55);
    await db.insert('transactions', {...db.tables['transactions']!.values.single, 'id': 'other', 'user_id': 'other-user'});
    final second = DataService(database: db)..currentUser = service.currentUser;
    await second.refreshData();
    expect(second.transactions.length, 1);
    expect(second.balance, 55);
    second.dispose();
  });
  test('custom category persists across refresh', () async {
    final custom = await service.addCategory('Custom', CategoryType.income, Icons.star);
    await service.refreshData();
    expect(service.categories.where((c) => c.id == custom.id).length, 1);
  });
  test('goal validation and completed initial savings', () async {
    expect(await service.addGoal(name: 'Invalid', targetAmount: 0, targetDate: DateTime(2027), icon: Icons.savings), isNotNull);
    expect(await service.addGoal(name: 'Done', targetAmount: 10, savedAmount: 10, targetDate: DateTime(2027), icon: Icons.savings), isNull);
    expect(service.goals.single.status, GoalStatus.completed);
  });
  test('failed contribution and delete preserve goal', () async {
    await service.addGoal(name: 'Goal', targetAmount: 10, targetDate: DateTime(2027), icon: Icons.savings);
    final id = service.goals.single.id;
    db.failWrites = true;
    await expectLater(service.contributeToGoal(id, 2), throwsStateError);
    await expectLater(service.deleteGoal(id), throwsStateError);
    expect(service.goals.single.savedAmount, 0);
  });
  test('transfer handles failure, balance limit and target completion', () async {
    await add(10);
    await service.addGoal(name: 'Goal', targetAmount: 5, targetDate: DateTime(2027), icon: Icons.savings);
    final id = service.goals.single.id;
    expect(await service.transferToGoal(id, 11), isNotNull);
    expect(await service.transferToGoal(id, 6), isNotNull);
    db.failWrites = true;
    expect(await service.transferToGoal(id, 5), isNotNull);
    expect(service.balance, 10);
    expect(service.goals.single.savedAmount, 0);
    db.failWrites = false;
    expect(await service.transferToGoal(id, 5), isNull);
    expect(service.balance, 5);
    expect(service.goals.single.status, GoalStatus.completed);
    expect(await service.transferToGoal(id, 1), isNotNull);
  });
  test('editing all fields keeps one record and updates totals after reload', () async {
    await add(150, spending: true);
    final id = service.transactions.single.id;
    await service.editTransaction(id, type: CategoryType.income, amount: 500,
      category: income, date: DateTime(2026, 8, 5), note: 'ซื้อข้าว 🍜💰✨');
    expect(service.balance, 500);
    expect(service.totalExpense, 0);
    expect(service.totalsByCategory(type: CategoryType.income)[income], 500);
    expect(service.expenseByCategory(), isEmpty);
    await service.editTransaction(id, note: 'ซื้อข้าว 🍜💰✨');
    expect(service.transactions, hasLength(1));
    await service.refreshData();
    expect(service.transactions.single.note, 'ซื้อข้าว 🍜💰✨');
    expect(service.transactions.single.date, DateTime(2026, 8, 5));
    expect(service.balance, 500);
    await service.deleteTransaction(id);
    await service.refreshData();
    expect(service.transactions, isEmpty);
    expect(service.balance, 0);
  });
  test('pin and edit goal survive reload, saved amount is preserved', () async {
    await service.addGoal(name: 'Phone', targetAmount: 40000, savedAmount: 10000,
      targetDate: DateTime(2027), icon: Icons.savings);
    final id = service.goals.single.id;
    expect(service.pinnedGoals, isEmpty);
    await service.setGoalPinned(id, true);
    expect(await service.editGoal(id, name: 'New phone', targetAmount: 50000,
      targetDate: DateTime(2028), icon: Icons.savings, note: 'Goal note'), isNull);
    await service.refreshData();
    expect(service.pinnedGoals.single.name, 'New phone');
    expect(service.goals.single.savedAmount, 10000);
    expect(service.goals.single.progress, 0.2);
    expect(await service.editGoal(id, name: 'Bad', targetAmount: 5000,
      targetDate: DateTime(2028), icon: Icons.savings), isNotNull);
    expect(service.goals.single.targetAmount, 50000);
    await service.setGoalPinned(id, false);
    await service.refreshData();
    expect(service.pinnedGoals, isEmpty);
    await service.deleteGoal(id);
    await service.refreshData();
    expect(service.goals, isEmpty);
  });
  test('failed goal edits and pinning keep existing state', () async {
    await service.addGoal(name: 'Original', targetAmount: 10,
      targetDate: DateTime(2027), icon: Icons.savings);
    final id = service.goals.single.id;
    db.failWrites = true;
    expect(await service.editGoal(id, name: 'Changed', targetAmount: 20,
      targetDate: DateTime(2028), icon: Icons.savings), isNotNull);
    await expectLater(service.setGoalPinned(id, true), throwsStateError);
    expect(service.goals.single.name, 'Original');
    expect(service.pinnedGoals, isEmpty);
  });

  test('editing and deleting savings transfers updates goal and ledger together', () async {
    await add(100);
    await service.addGoal(name: 'Goal', targetAmount: 100, targetDate: DateTime(2027), icon: Icons.savings);
    await service.transferToGoal(service.goals.single.id, 25);
    final entry = service.transactions.firstWhere((t) => t.type == CategoryType.expense);
    db.failWrites = true;
    await expectLater(service.editTransaction(entry.id, amount: 40), throwsStateError);
    expect(service.goals.single.savedAmount, 25);
    db.failWrites = false;
    await service.editTransaction(entry.id, amount: 40);
    expect(service.goals.single.savedAmount, 40);
    expect(service.balance, 60);
    await service.deleteTransaction(entry.id);
    expect(service.goals.single.savedAmount, 0);
    expect(service.balance, 100);
    await service.refreshData();
    expect(service.goals.single.savedAmount, 0);
  });

}
