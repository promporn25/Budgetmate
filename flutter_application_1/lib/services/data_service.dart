import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'db_helper.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/user_model.dart';

const _sessionKey = 'budgetmate_session_user_id';
const _setupDoneKey = 'budgetmate_setup_completed';
const _defaultLangKey = 'budgetmate_default_language';
const _defaultCurrencyKey = 'budgetmate_default_currency';
const _themeModeKey = 'budgetmate_theme_mode'; // 'light' | 'dark'
const _successNotesKey = 'budgetmate_success_notes_enabled';

/// DataService รวบรวมการทำงานของระบบทั้งหมดตามขอบเขตโครงงาน (1.3.1 - 1.3.4)
/// เวอร์ชันนี้เก็บข้อมูลจริงลง SQLite ผ่าน DBHelper (ไม่ใช่ in-memory demo แล้ว)
/// - รายการ/เป้าหมายจะถูกโหลดเฉพาะของผู้ใช้ที่ล็อกอินอยู่ (currentUser)
/// - รหัสผ่านเก็บเป็นค่า SHA-256 hash
/// - สถานะล็อกอินถูกจำไว้ด้วย SharedPreferences จึงไม่ต้องล็อกอินใหม่ทุกครั้งที่เปิดแอป
class DataService extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DBHelper.instance;

  // ---------------- User session ----------------
  UserModel? currentUser;
  bool isReady = false;

  // ---------------- Profile picture (เก็บ path ไฟล์ในเครื่องผ่าน SharedPreferences ต่อผู้ใช้) ----------------
  String? avatarPath;

  // ---------------- ธีมของแอป (Light/Dark) ----------------
  ThemeMode themeMode = ThemeMode.light;

  // ---------------- การแจ้งเตือนเมื่อทำรายการสำเร็จ (Success Notes) ----------------
  bool successNotesEnabled = true;

  // ---------------- Category (โหลดทั้งหมดครั้งเดียวตอนเริ่มแอป) ----------------
  final List<CategoryModel> categories = [];

  // ---------------- Transaction (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => List.unmodifiable(_transactions.reversed);

  // ---------------- Goal Saving (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals);

  // =========================================================
  // เริ่มต้นระบบ: seed หมวดหมู่เริ่มต้น + กู้คืน session ที่ล็อกอินค้างไว้
  // เรียกครั้งเดียวจาก LoadingScreen ก่อนเข้าแอป
  // =========================================================
  Future<void> init() async {
    // TODO: ยังไม่เชื่อม SQLite สำหรับหมวดหมู่ตอนนี้ - ใช้ defaultCategories ตรงๆ ในหน่วยความจำไปก่อน
    // เมื่อพร้อมเชื่อม DB จริง ให้เปลี่ยนกลับไปเรียก _seedCategoriesIfEmpty() + _loadCategories() แทน
    categories
      ..clear()
      ..addAll(defaultCategories);

    final prefs = await SharedPreferences.getInstance();
    themeMode = (prefs.getString(_themeModeKey) ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    successNotesEnabled = prefs.getBool(_successNotesKey) ?? true;

    final userId = prefs.getString(_sessionKey);
    if (userId != null) {
      final rows = await _db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (rows.isNotEmpty) {
        currentUser = UserModel.fromMap(rows.first);
        avatarPath = prefs.getString('avatar_path_${currentUser!.id}');
        await _loadUserData();
      } else {
        await prefs.remove(_sessionKey);
      }
    }
    isReady = true;
    notifyListeners();
  }

  /// เพิ่มหมวดหมู่เริ่มต้นที่ยังไม่มีในฐานข้อมูล (เทียบทีละรายการด้วย id)
  /// ต่างจากเดิมที่เช็คแค่ "ตารางว่างหรือไม่" ครั้งเดียว ซึ่งทำให้เครื่องที่เคย
  /// ติดตั้งแอปไปแล้ว (มีหมวดหมู่เก่าอยู่บ้าง) ไม่เคยได้รับหมวดหมู่ใหม่ที่เพิ่มเข้ามาทีหลังเลย
  Future<void> _seedCategoriesIfEmpty() async {
    final rows = await _db.query('categories');
    final existingIds = rows.map((r) => r['id'] as String).toSet();
    for (final c in defaultCategories) {
      if (!existingIds.contains(c.id)) {
        await _db.insert('categories', c.toMap());
      }
    }
  }

  Future<void> _loadCategories() async {
    final rows = await _db.query('categories');
    categories
      ..clear()
      ..addAll(rows.map((r) => CategoryModel.fromMap(r)));
  }

  CategoryModel _categoryById(String id) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories.isNotEmpty ? categories.first : defaultCategories.first,
    );
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    final txRows = await _db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
      orderBy: 'date ASC',
    );
    _transactions
      ..clear()
      ..addAll(txRows.map(
          (r) => TransactionModel.fromMap(r, _categoryById(r['category_id'] as String))));

    final goalRows = await _db.query(
      'goals',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
    );
    _goals
      ..clear()
      ..addAll(goalRows.map((r) => GoalModel.fromMap(r)));
  }

  String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();

  // =========================================================
  // SETUP (หน้า "My wallet" - เลือกภาษา/สกุลเงินเริ่มต้น แสดงครั้งแรกที่เปิดแอป)
  // =========================================================
  Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupDoneKey) ?? false;
  }

  /// บันทึกภาษา/สกุลเงินที่เลือกในหน้า My wallet ให้เป็นค่าเริ่มต้น
  /// (จะถูกนำไปใช้เป็นค่าตั้งต้นตอนสมัครสมาชิกครั้งแรก)
  Future<void> completeSetup({required String language, required String currency}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, true);
    await prefs.setString(_defaultLangKey, language);
    await prefs.setString(_defaultCurrencyKey, currency);
  }

  Future<Map<String, String>> getDefaultPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'language': prefs.getString(_defaultLangKey) ?? 'ไทย',
      'currency': prefs.getString(_defaultCurrencyKey) ?? 'THB',
    };
  }

  // =========================================================
  // AUTHENTICATION (หน้า Login / Register)
  // =========================================================
  Future<String?> register(String name, String email, String password) async {
    final exists = await _db.query('users', where: 'email = ?', whereArgs: [email]);
    if (exists.isNotEmpty) {
      return 'อีเมลนี้ถูกใช้งานแล้ว';
    }

    final defaults = await getDefaultPreferences();
    final user = UserModel(
      id: _uuid.v4(),
      name: name,
      email: email,
      password: _hash(password),
      createdAt: DateTime.now(),
      language: defaults['language']!,
      currency: defaults['currency']!,
    );
    await _db.insert('users', user.toMap());

    currentUser = user;
    _transactions.clear();
    _goals.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.id);

    notifyListeners();
    return null; // สำเร็จ
  }

  Future<String?> login(String email, String password) async {
    final rows = await _db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';

    final user = UserModel.fromMap(rows.first);
    if (user.password != _hash(password)) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }

    currentUser = user;
    await _loadUserData();

    final prefs = await SharedPreferences.getInstance();
    avatarPath = prefs.getString('avatar_path_${user.id}');
    await prefs.setString(_sessionKey, user.id);

    notifyListeners();
    return null;
  }

  /// รีเซ็ตรหัสผ่านด้วยอีเมล (หน้า Forgot Password)
  /// คืนค่า null หากสำเร็จ หรือข้อความ error หากไม่พบบัญชีที่ใช้อีเมลนี้
  Future<String?> resetPassword(String email, String newPassword) async {
    final rows = await _db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return 'ไม่พบบัญชีที่ใช้อีเมลนี้ในระบบ';

    final userId = rows.first['id'] as String;
    await _db.update('users', {'password': _hash(newPassword)}, 'id = ?', [userId]);
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    _transactions.clear();
    _goals.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? language, String? currency}) async {
    if (currentUser == null) return;
    if (name != null) currentUser!.name = name;
    if (language != null) currentUser!.language = language;
    if (currency != null) currentUser!.currency = currency;
    await _db.update('users', currentUser!.toMap(), 'id = ?', [currentUser!.id]);
    notifyListeners();
  }

  /// เปิดตัวเลือกรูปภาพ (กล้อง/คลังภาพ) แล้วบันทึกไฟล์ลงเครื่องถาวร
  /// เก็บ path ไว้ใน SharedPreferences แยกตาม user id (ไม่ผูกกับตาราง users ใน SQLite
  /// เพื่อไม่ต้องแก้ schema เดิม) คืนค่า true หากเปลี่ยนรูปสำเร็จ
  Future<bool> pickAvatar({required bool fromCamera}) async {
    if (currentUser == null) return false;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final savedPath = '${dir.path}/avatar_${currentUser!.id}.$ext';

    // ลบไฟล์รูปเก่า (ถ้ามี) ก่อนเขียนทับ กันไฟล์ค้างเปลืองพื้นที่
    if (avatarPath != null) {
      final old = File(avatarPath!);
      if (await old.exists()) {
        try {
          await old.delete();
        } catch (_) {}
      }
    }

    await File(picked.path).copy(savedPath);
    avatarPath = savedPath;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_path_${currentUser!.id}', savedPath);

    notifyListeners();
    return true;
  }

  Future<void> removeAvatar() async {
    if (currentUser == null || avatarPath == null) return;
    final file = File(avatarPath!);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    avatarPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('avatar_path_${currentUser!.id}');
    notifyListeners();
  }

  /// เปลี่ยนธีมแอป (Light/Dark) - ใช้ทั่วทั้งแอปผ่าน MaterialApp.themeMode
  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  /// เปิด/ปิดการแจ้งเตือนเมื่อทำรายการสำเร็จ (เช่น banner "บันทึกสำเร็จ")
  Future<void> toggleSuccessNotes() async {
    successNotesEnabled = !successNotesEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_successNotesKey, successNotesEnabled);
    notifyListeners();
  }

  /// เปลี่ยนรหัสผ่าน (ต้องกรอกรหัสผ่านเดิมให้ถูกต้องก่อน) - หน้า Password & Security
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (currentUser == null) return 'กรุณาเข้าสู่ระบบก่อน';
    if (currentUser!.password != _hash(currentPassword)) {
      return 'รหัสผ่านเดิมไม่ถูกต้อง';
    }
    await _db.update('users', {'password': _hash(newPassword)}, 'id = ?', [currentUser!.id]);
    notifyListeners();
    return null;
  }

  // =========================================================
  // 1.3.1 ระบบฟังก์ชันบันทึกรายรับ-รายจ่าย
  // =========================================================
  Future<void> addTransaction({
    required CategoryType type,
    required double amount,
    required CategoryModel category,
    required DateTime date,
    String? note,
    String? description,
    String? receiptPath,
  }) async {
    if (currentUser == null) return;
    final tx = TransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
      receiptPath: receiptPath,
    );
    await _db.insert('transactions', tx.toMap(currentUser!.id));
    _transactions.add(tx);
    notifyListeners();
  }

  Future<void> editTransaction(
    String id, {
    CategoryType? type,
    double? amount,
    CategoryModel? category,
    DateTime? date,
    String? note,
    String? description,
  }) async {
    if (currentUser == null) return;
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final updated = _transactions[index].copyWith(
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
    );
    _transactions[index] = updated;
    await _db.update('transactions', updated.toMap(currentUser!.id), 'id = ?', [id]);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _db.delete('transactions', 'id = ?', [id]);
    notifyListeners();
  }

  Future<void> addCategory(String name, CategoryType type, IconData icon) async {
    final category = CategoryModel(id: _uuid.v4(), name: name, type: type, icon: icon);
    await _db.insert('categories', category.toMap());
    categories.add(category);
    notifyListeners();
  }

  List<CategoryModel> categoriesByType(CategoryType type) =>
      categories.where((c) => c.type == type).toList();

  // =========================================================
  // 1.3.2 ระบบตั้งเป้าหมายการออม (Goal Saving)
  // =========================================================
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    required IconData icon,
    double savedAmount = 0,
  }) async {
    if (currentUser == null) return;
    final goal = GoalModel(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      startDate: DateTime.now(),
      targetDate: targetDate,
      icon: icon,
    );
    await _db.insert('goals', goal.toMap(currentUser!.id));
    _goals.add(goal);
    notifyListeners();
  }

  /// เพิ่มเงินออมเข้าเป้าหมาย และอัปเดตสถานะอัตโนมัติเมื่อถึงเป้าหมาย
  /// หมายเหตุ: เมธอดนี้ไม่กระทบ Ledger Balance (ไม่สร้างรายจ่าย) — เก็บไว้เพื่อความเข้ากันได้ย้อนหลัง
  /// สำหรับการ "โอนเงินจริง" ที่ต้องหักยอดคงเหลือด้วย ให้ใช้ [transferToGoal] แทน
  Future<void> contributeToGoal(String goalId, double amount) async {
    final goal = _goals.firstWhere((g) => g.id == goalId);
    goal.savedAmount = (goal.savedAmount + amount).clamp(0, goal.targetAmount);
    if (goal.savedAmount >= goal.targetAmount) {
      goal.status = GoalStatus.completed;
    }
    if (currentUser != null) {
      await _db.update('goals', goal.toMap(currentUser!.id), 'id = ?', [goal.id]);
    }
    notifyListeners();
  }

  static const _goalSavingCategoryId = 'c17';

  /// หาหมวดหมู่ "เงินออม" ที่ใช้บันทึกรายจ่ายอัตโนมัติเมื่อโอนเงินเข้าเป้าหมาย
  /// สร้างให้อัตโนมัติถ้ายังไม่มี (เผื่อฐานข้อมูลเก่าที่ seed ไปก่อนเพิ่มหมวดนี้)
  Future<CategoryModel> _ensureGoalSavingCategory() async {
    final existing = categories.where(
        (c) => c.id == _goalSavingCategoryId || c.name == 'เงินออม');
    if (existing.isNotEmpty) return existing.first;

    final category = const CategoryModel(
      id: _goalSavingCategoryId,
      name: 'เงินออม',
      type: CategoryType.expense,
      icon: Icons.savings,
      description: 'หมวดหมู่รายจ่ายสำหรับการโอนเงินเข้าเป้าหมายการออม (สร้างอัตโนมัติ)',
    );
    await _db.insert('categories', category.toMap());
    categories.add(category);
    return category;
  }

  /// โอนเงิน "จริง" เข้าเป้าหมายการออม (ข้อ 1.3.2.1 แบบหักยอดจริง):
  /// 1) หักยอดจาก Ledger Balance โดยบันทึกเป็นรายการรายจ่ายอัตโนมัติ (หมวด "เงินออม")
  /// 2) เพิ่มยอดเงินออมสะสม (saved_amount) ของเป้าหมายพร้อมกัน
  /// คืนค่า null หากโอนสำเร็จ หรือข้อความ error หากทำไม่ได้ (เช่น ยอดคงเหลือไม่พอ)
  Future<String?> transferToGoal(String goalId, double amount, {String? note}) async {
    if (currentUser == null) return 'กรุณาเข้าสู่ระบบก่อน';
    if (amount <= 0) return 'กรุณากรอกจำนวนเงินให้ถูกต้อง';

    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) return 'ไม่พบเป้าหมายนี้';
    final goal = _goals[goalIndex];

    if (amount > balance) {
      return 'ยอดเงินคงเหลือใน Ledger ไม่เพียงพอ (คงเหลือ ฿${balance.toStringAsFixed(2)})';
    }

    final category = await _ensureGoalSavingCategory();
    final tx = TransactionModel(
      id: _uuid.v4(),
      type: CategoryType.expense,
      amount: amount,
      category: category,
      date: DateTime.now(),
      note: note ?? 'โอนเงินเข้าเป้าหมาย: ${goal.name}',
      description: 'goal_transfer:${goal.id}',
    );

    final wasCompleted = goal.status == GoalStatus.completed;
    try {
      // 1) บันทึกรายจ่ายอัตโนมัติ (หักออกจาก Ledger Balance ทันทีเพราะ balance คำนวณจาก transactions)
      await _db.insert('transactions', tx.toMap(currentUser!.id));
      _transactions.add(tx);

      // 2) เพิ่มยอดออมสะสมของเป้าหมาย
      goal.savedAmount += amount;
      if (goal.savedAmount >= goal.targetAmount) {
        goal.status = GoalStatus.completed;
      }
      await _db.update('goals', goal.toMap(currentUser!.id), 'id = ?', [goal.id]);
    } catch (e) {
      // ชดเชยย้อนกลับ (compensating rollback) เนื่องจาก DBHelper ปัจจุบันไม่มี atomic transaction()
      // TODO: ถ้าต้องการความปลอดภัยสูงสุด ควรเพิ่มเมธอด runInTransaction ใน DBHelper
      // แล้วห่อ insert(transactions) + update(goals) ไว้ในทรานแซกชันเดียวของ SQLite จริง ๆ
      _transactions.removeWhere((t) => t.id == tx.id);
      await _db.delete('transactions', 'id = ?', [tx.id]);
      goal.savedAmount -= amount;
      goal.status = wasCompleted ? GoalStatus.completed : GoalStatus.inProgress;
      notifyListeners();
      return 'เกิดข้อผิดพลาด ไม่สามารถโอนเงินได้ กรุณาลองใหม่อีกครั้ง';
    }

    notifyListeners();
    return null;
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _db.delete('goals', 'id = ?', [id]);
    notifyListeners();
  }

  /// เป้าหมายที่ใกล้ถึงเป้า (ใช้แจ้งเตือนตามข้อ 1.3.2.2)
  List<GoalModel> get nearingGoals => _goals.where((g) => g.isNearTarget).toList();

  // =========================================================
  // 1.3.3 การแสดงผลข้อมูลทางการเงิน (คำนวณจากข้อมูลที่โหลดไว้ในหน่วยความจำ)
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
            t.type == type && t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// สรุปรายรับ-รายจ่ายรายเดือน ย้อนหลัง [months] เดือน (ข้อ 1.3.3.1)
  List<MapEntry<DateTime, Map<String, double>>> monthlySummary({int months = 6}) {
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
  MapEntry<CategoryModel, double>? get mostSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  MapEntry<CategoryModel, double>? get leastSpentCategory {
    final map = expenseByCategory();
    if (map.isEmpty) return null;
    final entries = map.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return entries.first;
  }

  List<TransactionModel> transactionsForDay(DateTime day) {
    return transactions
        .where((t) =>
            t.date.year == day.year && t.date.month == day.month && t.date.day == day.day)
        .toList();
  }
}