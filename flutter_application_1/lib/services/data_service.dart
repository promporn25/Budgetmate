import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/user_model.dart';

/// DataService รวบรวมการทำงานของระบบทั้งหมดตามขอบเขตโครงงาน (1.3.1 - 1.3.4)
/// ทำหน้าที่เสมือนชั้น Backend/Repository ในเวอร์ชัน in-memory (demo)
/// เพื่อให้สามารถต่อยอดไปเชื่อมกับ Firebase / MySQL ได้ในภายหลัง
class DataService extends ChangeNotifier {
  final _uuid = const Uuid();

  // ---------------- User (1.3.5 / Account Setting) ----------------
  UserModel? currentUser;
  final List<UserModel> _users = [];

  // ---------------- Category ----------------
  final List<CategoryModel> categories = List.of(defaultCategories);

  // ---------------- Transaction (1.3.1 บันทึกรายรับ-รายจ่าย) ----------------
  final List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions =>
      List.unmodifiable(_transactions.reversed);

  // ---------------- Goal Saving (1.3.2 ตั้งเป้าหมายการออม) ----------------
  final List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals);

  DataService() {
    _seedDemoData();
  }

  // =========================================================
  // AUTHENTICATION (หน้า Login / Register)
  // =========================================================
  String? register(String name, String email, String password) {
    if (_users.any((u) => u.email == email)) {
      return 'อีเมลนี้ถูกใช้งานแล้ว';
    }
    final user = UserModel(
      id: _uuid.v4(),
      name: name,
      email: email,
      password: password,
      createdAt: DateTime.now(),
    );
    _users.add(user);
    currentUser = user;
    notifyListeners();
    return null; // สำเร็จ
  }

  String? login(String email, String password) {
    try {
      final user = _users.firstWhere(
          (u) => u.email == email && u.password == password);
      currentUser = user;
      notifyListeners();
      return null;
    } catch (_) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  void updateProfile({String? name, String? language, String? currency}) {
    if (currentUser == null) return;
    if (name != null) currentUser!.name = name;
    if (language != null) currentUser!.language = language;
    if (currency != null) currentUser!.currency = currency;
    notifyListeners();
  }

  // =========================================================
  // 1.3.1 ระบบฟังก์ชันบันทึกรายรับ-รายจ่าย
  // =========================================================
  void addTransaction({
    required CategoryType type,
    required double amount,
    required CategoryModel category,
    required DateTime date,
    String? note,
    String? description,
    String? receiptPath,
  }) {
    _transactions.add(TransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
      receiptPath: receiptPath,
    ));
    notifyListeners();
  }

  void editTransaction(String id, {
    CategoryType? type,
    double? amount,
    CategoryModel? category,
    DateTime? date,
    String? note,
    String? description,
  }) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions[index] = _transactions[index].copyWith(
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
    );
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void addCategory(String name, CategoryType type, IconData icon) {
    categories.add(CategoryModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      icon: icon,
    ));
    notifyListeners();
  }

  List<CategoryModel> categoriesByType(CategoryType type) =>
      categories.where((c) => c.type == type).toList();

  // =========================================================
  // 1.3.2 ระบบตั้งเป้าหมายการออม (Goal Saving)
  // =========================================================
  void addGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    required IconData icon,
    double savedAmount = 0,
  }) {
    _goals.add(GoalModel(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      startDate: DateTime.now(),
      targetDate: targetDate,
      icon: icon,
    ));
    notifyListeners();
  }

  /// เพิ่มเงินออมเข้าเป้าหมาย และอัปเดตสถานะอัตโนมัติเมื่อถึงเป้าหมาย
  void contributeToGoal(String goalId, double amount) {
    final goal = _goals.firstWhere((g) => g.id == goalId);
    goal.savedAmount = (goal.savedAmount + amount).clamp(0, goal.targetAmount);
    if (goal.savedAmount >= goal.targetAmount) {
      goal.status = GoalStatus.completed;
    }
    notifyListeners();
  }

  void deleteGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  /// เป้าหมายที่ใกล้ถึงเป้า (ใช้แจ้งเตือนตามข้อ 1.3.2.2)
  List<GoalModel> get nearingGoals =>
      _goals.where((g) => g.isNearTarget).toList();

  // =========================================================
  // 1.3.3 การแสดงผลข้อมูลทางการเงิน
  // =========================================================
  double get totalIncome => _transactions
      .where((t) => t.type == CategoryType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == CategoryType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  double monthlyTotal(CategoryType type, DateTime month) {
    return _transactions
        .where((t) =>
            t.type == type &&
            t.date.year == month.year &&
            t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// สรุปรายรับ-รายจ่ายรายเดือน ย้อนหลัง [months] เดือน (ข้อ 1.3.3.1)
  List<MapEntry<DateTime, Map<String, double>>> monthlySummary(
      {int months = 6}) {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, Map<String, double>>>[];
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      result.add(MapEntry(month, {
        'income': monthlyTotal(CategoryType.income, month),
        'expense': monthlyTotal(CategoryType.expense, month),
      }));
    }
    return result;
  }

  /// สัดส่วนเปอร์เซ็นต์รายรับ/รายจ่าย (ข้อ 1.3.3.2)
  Map<String, double> get incomeExpensePercentage {
    final total = totalIncome + totalExpense;
    if (total == 0) return {'income': 0, 'expense': 0};
    return {
      'income': (totalIncome / total) * 100,
      'expense': (totalExpense / total) * 100,
    };
  }

  /// สัดส่วนค่าใช้จ่ายแยกตามหมวดหมู่ สำหรับ Pie Chart หน้า Income/Expense
  Map<CategoryModel, double> expenseByCategory({DateTime? month}) {
    final Map<CategoryModel, double> map = {};
    for (final t in _transactions.where((t) => t.type == CategoryType.expense)) {
      if (month != null &&
          !(t.date.year == month.year && t.date.month == month.month)) {
        continue;
      }
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  // =========================================================
  // 1.3.4 ระบบวิเคราะห์พฤติกรรมผู้ใช้ (User Behavior Analysis)
  // =========================================================
  /// หมวดหมู่ที่ใช้จ่ายมากที่สุด / น้อยที่สุด (behavior_id ในเอกสาร)
  MapEntry<CategoryModel, double>? get mostSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  MapEntry<CategoryModel, double>? get leastSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.first;
  }

  List<TransactionModel> transactionsForDay(DateTime day) {
    return transactions
        .where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .toList();
  }

  // =========================================================
  // ข้อมูลตัวอย่างสำหรับสาธิตการทำงาน (Demo seed data)
  // =========================================================
  void _seedDemoData() {
    final now = DateTime.now();
    final food = categories.firstWhere((c) => c.name == 'อาหาร');
    final travel = categories.firstWhere((c) => c.name == 'ท่องเที่ยว');
    final salary = categories.firstWhere((c) => c.name == 'เงินเดือน');
    final shopping = categories.firstWhere((c) => c.name == 'ช้อปปิ้ง');

    addTransaction(
        type: CategoryType.income,
        amount: 25000,
        category: salary,
        date: DateTime(now.year, now.month, 1),
        note: 'เงินเดือนประจำเดือน');
    addTransaction(
        type: CategoryType.expense,
        amount: 120,
        category: food,
        date: now.subtract(const Duration(days: 1)),
        note: 'ข้าวเที่ยง');
    addTransaction(
        type: CategoryType.expense,
        amount: 850,
        category: shopping,
        date: now.subtract(const Duration(days: 2)),
        note: 'ซื้อเสื้อผ้า');
    addTransaction(
        type: CategoryType.expense,
        amount: 1500,
        category: travel,
        date: now.subtract(const Duration(days: 5)),
        note: 'ตั๋วเดินทาง');

    addGoal(
      name: 'ท่องเที่ยวญี่ปุ่น',
      targetAmount: 30000,
      savedAmount: 15000,
      targetDate: DateTime(now.year + 1, now.month, now.day),
      icon: Icons.flight_takeoff,
    );
    addGoal(
      name: 'กองทุนฉุกเฉิน',
      targetAmount: 50000,
      savedAmount: 46000,
      targetDate: DateTime(now.year, now.month + 6, now.day),
      icon: Icons.savings,
    );
  }
}
