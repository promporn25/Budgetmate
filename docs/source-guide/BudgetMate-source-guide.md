# คู่มืออธิบายซอร์สโค้ด BudgetMate

ภาษาไทย • อ้างอิงไฟล์ปัจจุบันในเครื่อง ณ 13 ตุลาคม 2026 • รวมการแก้ไขที่ยังไม่ได้ commit

เอกสารนี้อธิบายสถาปัตยกรรม ขั้นตอนทำงาน โมเดล หน้าจอ วิดเจ็ต ฐานข้อมูล OCR ระบบบัญชี เว็บรีเซ็ตรหัสผ่าน โค้ด native และชุดทดสอบ พร้อมโค้ดจริงและเลขบรรทัด ส่วนท้ายมีคำอธิบายรายไฟล์และโค้ดเต็มของไฟล์โปรแกรมที่รวมในขอบเขต โดย HTML สามารถกดเปิดโค้ดเต็มของแต่ละไฟล์ได้

วิธีอ่าน: เริ่มจากภาพรวมและเส้นทางข้อมูล จากนั้นอ่านหัวข้อฟังก์ชันที่สนใจ แล้วใช้สารบัญรายไฟล์หรือค้นหาชื่อเมธอด เลขบรรทัดเป็นของ snapshot นี้ จึงอาจเปลี่ยนเมื่อแก้ไฟล์ภายหลัง เอกสารนี้เป็นการอ่านโค้ด ไม่ใช่ผลยืนยันว่า build ผ่านหรือว่าบริการบน Firebase ถูก deploy ตรงกับไฟล์ในเครื่อง

## 1. ภาพรวมและความสัมพันธ์ของส่วนต่าง ๆ

BudgetMate เป็นแอป Flutter สำหรับบันทึกรายรับ รายจ่าย และเป้าหมายเงินออม ใช้ Provider ส่ง DataService ให้หน้าจอ การยืนยันตัวตนทำผ่าน Firebase Authentication ส่วนข้อมูลโปรไฟล์ รายการ และเป้าหมายบันทึกผ่าน DBHelper ไป Firestore

| ส่วน | รับผิดชอบ | ตัวอย่างไฟล์ |
| --- | --- | --- |
| เริ่มโปรแกรม | เตรียม Firebase ภาษาไทย ธีม และ Provider | lib/main.dart |
| หน้าจอ | รับข้อมูล ตรวจฟอร์ม แสดงผล และเปลี่ยนหน้า | lib/screens/ |
| บริการ | กฎการบันทึก คำนวณยอด บัญชี OCR และการเก็บไฟล์ | lib/services/ |
| โมเดล | โครงสร้างข้อมูลและแปลงระหว่าง object กับ Map | lib/models/ |
| วิดเจ็ต | ส่วน UI ที่หลายหน้าใช้ร่วมกัน | lib/widgets/ |
| ระบบภายนอก | Firebase Auth, Firestore; OCR ปัจจุบันทำในเครื่อง | db_helper.dart, receipt_service.dart |
| เว็บ | ตั้งรหัสผ่านใหม่จากลิงก์อีเมล | public/ |
| เครื่องมือและทดสอบ | ตรวจพฤติกรรมและสร้างไฟล์กฎรหัสผ่าน | test/, tests/, tool/, scripts/ |

เส้นทางหลัก: ผู้ใช้กดปุ่ม → Screen → DataService → DBHelper → Firestore → อัปเดตรายการในหน่วยความจำ → notifyListeners() → widget ที่ watch/Consumer สร้างหน้าจอใหม่ ส่วน OCR ใช้ Screen → ReceiptService → Apple Vision/Tesseract → ReceiptDraft → ผู้ใช้ตรวจแก้ → addTransaction()

## 2. เริ่มแอปและกู้คืนการเข้าสู่ระบบ

flutter_application_1/lib/main.dart บรรทัด 12–21

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เตรียมข้อมูล locale ภาษาไทยสำหรับ DateFormat (เช่น ชื่อเดือน/วันภาษาไทย)
  // ต้องเรียกก่อน runApp ไม่งั้นจะเจอ LocaleDataException ตอนใช้ DateFormat(..., 'th')
  await initializeDateFormatting('th', null);

  runApp(const BudgetMateApp());
}
```

ensureInitialized() เตรียม Flutter ก่อนเรียก plugin; initializeApp() ใช้ค่าตามแพลตฟอร์ม; initializeDateFormatting() เตรียมชื่อเดือนและวันภาษาไทย; runApp() เริ่ม widget tree หาก Firebase เริ่มไม่สำเร็จ โค้ดส่วนนี้ยังไม่มีหน้ารองรับข้อผิดพลาดโดยเฉพาะ

flutter_application_1/lib/main.dart บรรทัด 38–55

```dart
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService(),
      child: Consumer<DataService>(
        builder: (context, service, _) {
          AppColors.brightness = service.themeMode == ThemeMode.dark
              ? Brightness.dark
              : Brightness.light;
          return MaterialApp(
            title: 'BUDGETMATE',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            themeMode: service.themeMode,
            // ปรับขนาดทุกหน้าให้พอดีกับความกว้างจอจริง
            builder: (context, child) => ResponsiveScale(child: child!),
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.black,
```

ChangeNotifierProvider สร้าง DataService หนึ่งตัวในต้นไม้แอป Consumer รับการเปลี่ยนค่า themeMode และสร้าง MaterialApp ใหม่ หน้าจออ่าน service ด้วย context.read เมื่อต้องสั่งงาน และ context.watch เมื่อต้องรีเฟรชตามข้อมูล

flutter_application_1/lib/screens/loading_screen.dart บรรทัด 23–48

```dart
  Future<void> _init() async {
    final service = context.read<DataService>();
    final started = DateTime.now();

    await service.init(); // สร้างตาราง/seed หมวดหมู่ + กู้คืน session (จะตั้งค่า AppColors.brightness ให้ด้วย)

    final elapsed = DateTime.now().difference(started);
    final remain = const Duration(milliseconds: 1200) - elapsed;
    if (remain > Duration.zero) {
      await Future.delayed(remain);
    }

    if (!mounted) return;

    Widget nextScreen;
    if (service.currentUser != null) {
      nextScreen = const HomeScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      noAnimationRoute(nextScreen),
    );
```

LoadingScreen เรียก init() และแสดงช่วงโหลดรวมอย่างน้อยประมาณ 1.2 วินาที จากนั้นเปิด Home ถ้ามี currentUser หรือ Login ถ้าไม่มี ใช้ pushReplacement แทนหน้าโหลด จึงย้อนกลับมาหน้าโหลดไม่ได้ จุดนี้ไม่ได้ใช้ isSetupCompleted() เป็นเงื่อนไขนำทาง

flutter_application_1/lib/services/data_service.dart บรรทัด 149–186

```dart
  Future<void> init() async {
    categories
      ..clear()
      ..addAll(defaultCategories);

    final prefs = await SharedPreferences.getInstance();
    themeMode = (prefs.getString(_themeModeKey) ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    successNotesEnabled = prefs.getBool(_successNotesKey) ?? true;
    _defaultLanguage = prefs.getString(_defaultLangKey) ?? 'ไทย';
    _defaultCurrency = prefs.getString(_defaultCurrencyKey) ?? 'THB';

    // Firebase Authentication จำสถานะล็อกอินไว้ให้เองอยู่แล้ว (persistent session)
    // จึงเช็คแค่ว่ามีผู้ใช้ที่ล็อกอินค้างอยู่หรือไม่ แล้วโหลดโปรไฟล์ที่ตรงกันจาก Firestore
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      try {
        final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);
        if (rows.isNotEmpty) {
          currentUser = UserModel.fromMap(rows.first);
          avatarPath = prefs.getString('avatar_path_${currentUser!.id}');
          await _loadUserData();
        }
      } catch (e) {
        // เชื่อมต่อ Firestore ไม่ได้ตอนเปิดแอป (เน็ตช้า/หลุด) - ปล่อยให้เข้าหน้า Login
        // ตามปกติแทนที่จะค้างที่ Loading ตลอดไป ผู้ใช้ล็อกอินใหม่ได้เองเมื่อเน็ตกลับมา
        currentUser = null;
      }
    }
    isReady = true;
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    final rows = await _db.query('categories');
    categories
      ..clear()
```

init() ใส่หมวดหมู่เริ่มต้น อ่านธีม ภาษา สกุลเงิน และตัวเลือกแจ้งสำเร็จจาก SharedPreferences จากนั้นตรวจ FirebaseAuth.currentUser ถ้ามีจึงโหลดโปรไฟล์และข้อมูลเจ้าของบัญชี หากกู้ข้อมูลมีปัญหาจะล้าง currentUser และให้ไปหน้า Login

## 3. โมเดลข้อมูลและตำแหน่งจัดเก็บ

| โมเดล | ฟิลด์หลัก | ตำแหน่ง/ความหมาย |
| --- | --- | --- |
| UserModel | id, name, email, language, currency, ledgerCurrency, avatarBase64 | users/{uid}; uid มาจาก Firebase Auth ไม่มีฟิลด์รหัสผ่าน |
| CategoryModel | id, name, type, icon, artworkNumber, subcategories | หมวดมาตรฐานอยู่ในโค้ด; หมวดผู้ใช้อยู่ users/{uid}/categories/{id} |
| TransactionModel | id, type, amount, category, date, note, description, receiptPath, currency | transactions/{id}; user_id ระบุเจ้าของ category_id เชื่อมหมวด |
| GoalModel | id, targetAmount, savedAmount, targetDate, status, isPinned, currency | goals/{id}; user_id ระบุเจ้าของ |
| ReceiptDraft | amount?, date?, merchant | ข้อมูลชั่วคราวจาก OCR ก่อนยืนยัน ไม่ใช่เอกสารฐานข้อมูล |

flutter_application_1/lib/models/transaction_model.dart บรรทัด 49–65

```dart
  Map<String, dynamic> toMap(String userId) {
    return {
      'id': id,
      'currency': currency,
      'user_id': userId,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'amount': amount,
      'category_id': category.id,
      'date': date.toIso8601String(),
      'note': note,
      'description': description,
      'receipt_path': receiptPath,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, CategoryModel category) {
    return TransactionModel(
```

toMap(userId) เปลี่ยน object เป็นค่าที่ Firestore รับได้ เช่น enum กลายเป็น string และ DateTime กลายเป็น ISO string; fromMap() แปลงกลับโดยต้องส่ง CategoryModel ที่หาได้จาก category_id เข้าไปด้วย copyWith() ใช้สร้างรายการใหม่จากค่าของเดิมเมื่อแก้ไข

flutter_application_1/lib/models/goal_model.dart บรรทัด 36–41

```dart
  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  /// ตามข้อ 1.3.2.2 แจ้งเตือนเมื่อใกล้ถึงเป้าหมาย (>= 90%)
  bool get isNearTarget => progress >= 0.9 && progress < 1.0;

```

ความคืบหน้า = savedAmount / targetAmount จำกัดในช่วง 0–1; เป้าหมายใกล้สำเร็จเมื่อถึง 90% แต่ยังไม่ถึง 100% ตัวอย่าง 900 จาก 1,000 ให้ progress 0.9 และ isNearTarget เป็น true

หมวดลูกใช้ id รูปแบบ parentId:sub:index และชื่อแบบชื่อแม่ › ชื่อลูก; persisted_icons.dart แปลง codePoint ที่เก็บไว้กลับเป็น IconData จากรายการคงที่ ถ้าไม่พบใช้ไอคอนสำรอง จึงรักษาความเข้ากันได้กับข้อมูลเดิมและการตัดฟอนต์ที่ไม่ใช้ใน release

## 4. DataService: ศูนย์กลางสถานะและกฎของแอป

DataService สืบทอด ChangeNotifier เก็บ currentUser, categories, _transactions, _goals และค่าตั้งต้น มี constructor รับ DBHelper เพื่อให้ทดสอบโดยแทนฐานข้อมูลได้ transactions ส่งสำเนาที่เรียงวันที่ใหม่สุดก่อนและแก้ list โดยตรงไม่ได้; goals กรองตามสกุลเงินปัจจุบัน

| กลุ่มเมธอด | หน้าที่ |
| --- | --- |
| init / refreshData / _loadUserData | โหลดหมวด รายการ และเป้าหมายของผู้ใช้ |
| register / login / loginWithGoogle / logout | จัดการบัญชีและ session |
| resetPassword / changePassword | ส่งลิงก์รีเซ็ตหรือยืนยันรหัสเดิมก่อนเปลี่ยน |
| addTransaction / editTransaction / deleteTransaction | เพิ่ม แก้ ลบรายการและรักษาสถานะในหน่วยความจำ |
| addCategory / categoriesByType | สร้างหมวดและกรองรายรับหรือรายจ่าย |
| addGoal / editGoal / setGoalPinned / deleteGoal | จัดการเป้าหมายและการปักหมุด |
| transferToGoal / contributeToGoal | เพิ่มยอดออม สองเมธอดมีผลต่อบัญชีต่างกัน |
| totalIncome / totalExpense / balance / summaries | รวมยอดและเตรียมข้อมูลกราฟ |
| setLanguage / setCurrency / updateProfile / pickAvatar | แก้ค่าผู้ใช้และรูป |
| toggleTheme / toggleSuccessNotes / completeSetup | บันทึกตัวเลือกการใช้งาน |

flutter_application_1/lib/services/data_service.dart บรรทัด 593–631

```dart
  Future<String?> addTransaction({
    required CategoryType type,
    required double amount,
    required CategoryModel category,
    required DateTime date,
    String? note,
    String? description,
    String? receiptPath,
  }) async {
    if (currentUser == null) return t('please_login_first');
    if (!amount.isFinite || amount <= 0) return t('enter_valid_amount');
    final tx = TransactionModel(
      id: _uuid.v4(),
      currency: currentCurrency,
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
      receiptPath: receiptPath,
    );
    try {
      await _db.insert('transactions', _toStored(tx.toMap(currentUser!.id)));
    } catch (e) {
      // ไม่เพิ่มเข้า _transactions ถ้าบันทึกลง Firestore ไม่สำเร็จ กัน state
      // ในหน่วยความจำกับข้อมูลจริงใน Firestore ไม่ตรงกัน
      return '${t('save_failed')}: $e';
    }
    _transactions.add(tx);
    notifyListeners();
    return null;
  }

  Future<void> editTransaction(
    String id, {
    CategoryType? type,
    double? amount,
    CategoryModel? category,
```

ขั้นตอนเพิ่มรายการ: ต้องมีผู้ใช้ → จำนวนเป็น finite และมากกว่า 0 → สร้าง UUID และตรึง currency ของรายการ → await การเขียนฐานข้อมูล → เพิ่มเข้า _transactions → notifyListeners() หากเขียนล้มเหลวจะคืนข้อความและยังไม่เพิ่มรายการในเครื่อง ค่า null หมายถึงสำเร็จ รูปแบบนี้ต่างจาก edit/delete ที่อาจ throw และต้องดัก exception ในหน้าจอ

## 5. ฟอร์มรายรับ–รายจ่าย การแก้ไข ทำซ้ำ และลบ

flutter_application_1/lib/screens/add_income_expense_screen.dart บรรทัด 237–272

```dart
  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    if (_tempTransactions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('add_at_least_one'))));
      return;
    }

    setState(() => _saving = true);

    try {
      final savedIds = <String>{};
      for (final tx in _tempTransactions) {
        final error = await service.addTransaction(
          type: tx['category'].type,
          amount: tx['amount'],
          category: tx['category'],
          date: DateTime.now(),
          note: tx['note'],
        );

        if (error != null) {
          if (mounted) {
            setState(() {
              _tempTransactions =
                  _tempTransactions.where((t) => !savedIds.contains(t['id'])).toList();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          }
          return;
        }

        savedIds.add(tx['id'] as String);
      }

```

หน้าเพิ่มรายการมีรายการรอบันทึก _tempTransactions กดเพิ่มเพื่อสะสมได้หลายรายการ แล้ว _save() บันทึกทีละรายการ savedIds จำรายการที่สำเร็จ หากบางรายการคืน error จะนำรายการที่สำเร็จออก เหลือรายการที่ยังไม่สำเร็จให้ลองใหม่ การบันทึกทั้งชุดนี้ไม่ได้เป็น transaction เดียว หากรายการที่สามล้มเหลว สองรายการแรกยังถูกบันทึกแล้ว

flutter_application_1/lib/screens/edit_transaction_screen.dart บรรทัด 62–99

```dart
  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _error = _t('กรอกจำนวนเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.duplicate) {
        final error = await service.addTransaction(
            type: _type,
            amount: amount,
            category: _category!,
            date: _date,
            note: _note.text.trim());
        if (error != null) throw StateError(error);
      } else {
        await service.editTransaction(widget.transaction.id,
            type: _type,
            amount: amount,
            category: _category,
            date: _date,
            note: _note.text.trim());
      }
      if (!mounted) return;
      showSuccessNotice(context,
          widget.duplicate ? 'transaction_duplicated' : 'transaction_updated');
      Navigator.pop(context, true);
    } catch (_) {
```

หน้าแก้ไขเติมค่าจากรายการเดิม ถ้า duplicate เป็น true จะเรียก addTransaction เพื่อสร้าง id ใหม่ และใช้วันปัจจุบันเป็นค่าเริ่มต้น ถ้าเป็นการแก้จะส่ง id เดิมให้ editTransaction จึงไม่เพิ่มจำนวนรายการ การทำซ้ำไม่ได้คัดลอก receiptPath หรือ description ของการโอนเงินออม

flutter_application_1/lib/services/data_service.dart บรรทัด 669–682

```dart
  Future<void> deleteTransaction(String id) async {
    if (currentUser == null) throw StateError(t('please_login_first'));
    final index = _transactions.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    if (_transactions[index].description?.startsWith('goal_transfer:') == true) {
      _applyUpdatedGoal(await _db.changeGoalTransfer(id, null));
    } else {
      await _db.delete('transactions', 'id = ?', [id]);
    }
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<CategoryModel> addCategory(String name, CategoryType type, IconData icon, {
```

รายการทั่วไปลบผ่าน DBHelper.delete ส่วนรายการ description ขึ้นต้น goal_transfer: จะส่งให้ changeGoalTransfer ปรับยอดเป้าหมายพร้อมลบรายการก่อนล้าง list ในเครื่อง transaction_details_sheet.dart เป็นหน้ารายละเอียดและเมนูแก้ไข/ทำซ้ำ/ลบ โดยมี dialog ยืนยันก่อนลบ

## 6. เป้าหมายการออมและความสอดคล้องของยอด

flutter_application_1/lib/services/data_service.dart บรรทัด 789–813

```dart
  Future<String?> transferToGoal(String goalId, double amount, {String? note}) async {
    if (currentUser == null) return t('please_login_first');
    if (!amount.isFinite || amount <= 0) return t('enter_valid_amount');

    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) return t('goal_not_found');
    final goal = _goals[goalIndex];

    if (amount > balance) {
      return '${t('insufficient_ledger_prefix')} ${formatMoney(balance)})';
    }

    // แก้บั๊ก: เดิมเมธอดนี้ไม่ตรวจว่าจำนวนที่โอนเกินยอดที่ยังขาดอยู่ของเป้าหมายหรือไม่
    // (ต่างจาก contributeToGoal ที่ clamp ค่า saved_amount ไว้) ทำให้ saved_amount
    // สามารถเกิน target_amount ได้แบบเงียบๆ เมื่อผู้ใช้กรอกจำนวนเกินที่ต้องการอีก
    final remaining = goal.targetAmount - goal.savedAmount;
    if (amount > remaining) {
      return '${t('amount_exceeds_prefix')} ${formatMoney(remaining)})';
    }

    final category = await _ensureGoalSavingCategory();
    final tx = TransactionModel(
      id: _uuid.v4(),
      currency: currentCurrency,
      type: CategoryType.expense,
```

transferToGoal ตรวจยอดต้องมากกว่า 0 มีเป้าหมาย เงินไม่เกิน balance และไม่เกินส่วนที่เป้ายังขาด จากนั้นสร้างรายจ่ายหมวด c17 พร้อม description = goal_transfer:<id> และให้ DBHelper อัปเดตสองเอกสารร่วมกัน คำว่าโอนในแอปหมายถึงบันทึกบัญชีภายใน ไม่มีการเรียกธนาคารเพื่อเคลื่อนย้ายเงินจริง

flutter_application_1/lib/services/db_helper.dart บรรทัด 30–53

```dart
  Future<Map<String, dynamic>> transferToGoal(
    String goalId, double amount, Map<String, dynamic> entry,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || entry['user_id'] != uid || !amount.isFinite || amount <= 0) {
      throw StateError('ข้อมูลการโอนไม่ถูกต้อง');
    }
    final goalRef = _col('goals').doc(goalId);
    return _fs.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      final data = snapshot.data();
      if (data == null || data['user_id'] != uid) {
        throw StateError('ไม่พบเป้าหมาย');
      }
      final saved = (data['saved_amount'] as num).toDouble() + amount;
      final target = (data['target_amount'] as num).toDouble();
      if (saved > target) throw StateError('จำนวนเงินเกินเป้าหมาย');
      final updated = {...data, 'saved_amount': saved,
        'status': saved >= target ? 'completed' : 'inProgress'};
      transaction.update(goalRef, updated);
      transaction.set(_col('transactions').doc(entry['id'] as String), entry);
      return updated;
    });
  }
```

Firestore transaction อ่านเป้าหมายล่าสุด ตรวจเจ้าของและยอดไม่เกินเป้า แล้วอัปเดต saved_amount และสร้างรายจ่ายใน commit เดียว ถ้ามีการแก้พร้อมกัน Firestore สามารถทำ transaction ซ้ำจากข้อมูลใหม่ได้ อย่างไรก็ดี เงื่อนไขเงินคงเหลือในกระเป๋าตรวจจาก state ฝั่งแอป ไม่ได้คำนวณยอดทั้งบัญชีใน transaction นี้

flutter_application_1/lib/services/db_helper.dart บรรทัด 72–86

```dart
        double contribution(Map<String, dynamic>? row) => row != null &&
            row['type'] == 'expense' && row['category_id'] == 'c17'
            ? (row['amount'] as num).toDouble() : 0;
        final saved = (goal['saved_amount'] as num).toDouble()
            - contribution(old) + contribution(replacement);
        final target = (goal['target_amount'] as num).toDouble();
        if (!saved.isFinite || saved < 0 || saved > target) {
          throw StateError('ยอดเงินออมหลังแก้ไขต้องอยู่ระหว่าง 0 ถึงยอดเป้าหมาย');
        }
        updatedGoal = {...goal, 'saved_amount': saved,
          'status': saved >= target ? 'completed' : 'inProgress'};
        transaction.update(goalRef, updatedGoal);
      }
      if (replacement == null) {
        transaction.delete(entryRef);
```

เมื่อแก้/ลบรายการโอน ใช้สูตรยอดใหม่ = ยอดออมเดิม − ส่วนของรายการเก่า + ส่วนของรายการใหม่ โดยนับเป็นเงินออมเมื่อ type เป็น expense และ category_id เป็น c17 เท่านั้น จากนั้นตรวจยอดอยู่ระหว่าง 0 กับ target ตัวอย่างยอดออม 400 ที่รวมรายการ 100 อยู่แล้ว แก้รายการเป็น 150 จะได้ยอดออม 450

contributeToGoal เป็นเมธอดที่ยังอยู่เพื่อความเข้ากันได้ โดยเพิ่มยอดออมและจำกัดไม่เกินเป้า แต่ไม่สร้างรายจ่าย ส่วน addGoal สามารถรับ savedAmount ตั้งต้นได้โดยไม่สร้างรายจ่ายเช่นกัน deleteGoal ลบเฉพาะเป้าหมาย ไม่ได้ลบประวัติรายการโอนที่เคยบันทึก

## 7. สกุลเงิน การรวมยอด และกราฟ

flutter_application_1/lib/services/data_service.dart บรรทัด 65–66

```dart
  Iterable<TransactionModel> get _activeTransactions => _transactions.where(
    (entry) => (entry.currency ?? currentUser?.ledgerCurrency ?? 'THB') == currentCurrency);
```

flutter_application_1/lib/services/data_service.dart บรรทัด 878–888

```dart
  double get totalIncome => _activeTransactions
      .where((t) => t.type == CategoryType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _activeTransactions
      .where((t) => t.type == CategoryType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  double monthlyTotal(CategoryType type, DateTime month) {
```

ระบบใช้การแยกบัญชีตามสกุลเงิน: รายการ THB นับเมื่อเลือก THB และรายการ USD นับเมื่อเลือก USD ไม่มีการดึงอัตราแลกเปลี่ยนหรือแปลงยอดเก่า ฟิลด์ ledgerCurrency ใช้รองรับข้อมูลเก่าที่ไม่มี currency; setCurrency เปลี่ยนสกุลเงินที่เลือกโดยรักษา ledgerCurrency เดิม

ตัวอย่างมีรายรับ THB 1,000 รายจ่าย THB 200 และรายรับ USD 50: เมื่อเลือก THB balance = 800; เมื่อเลือก USD balance = 50 การเปลี่ยนสกุลเงินไม่ได้เปลี่ยน 800 บาทให้เป็น 50 ดอลลาร์

flutter_application_1/lib/services/data_service.dart บรรทัด 931–944

```dart
  List<MapEntry<DateTime, Map<String, double>>> monthlySummary({int months = 6, DateTime? endMonth}) {
    final now = endMonth ?? DateTime.now();
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

  /// สรุปรายรับ-รายจ่ายรายปี ย้อนหลัง [years] ปี นับจาก [endYear] (ค่าเริ่มต้นคือปีปัจจุบัน)
```

dailySummary, monthlySummary และ yearlySummary สร้างช่องเวลาย้อนหลังรวมช่องที่ไม่มีรายการเป็นศูนย์ Home ใช้ 7 วัน / 6 เดือน / 5 ปีตามตัวเลือก PeriodFilterBar แล้วส่งค่ารายรับและรายจ่ายเข้า fl_chart

flutter_application_1/lib/screens/income expense overview.dart บรรทัด 71–88

```dart
    final byCategory = <String, MapEntry<CategoryModel, double>>{};
    for (final transaction in historyList) {
      final key = '${transaction.type.name}:${transaction.category.id}';
      final previous = byCategory[key]?.value ?? 0;
      byCategory[key] = MapEntry(transaction.category, previous + transaction.amount);
    }
    final entries = byCategory.values.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final isThai = service.currentLanguage != 'English';
    final chartTitle = switch (_historyFilter) {
      HistoryFilter.all => isThai ? 'สัดส่วนรายรับและรายจ่าย · ทุกวัน' : 'Income and expenses · All dates',
      HistoryFilter.income => isThai ? 'สัดส่วนรายรับ' : 'Income breakdown',
      HistoryFilter.expense => isThai ? 'สัดส่วนรายจ่าย' : 'Expense breakdown',
    };

    return Column(
      children: [
```

หน้ารวมรายรับ–รายจ่ายรวมหมวดจาก historyList ที่ผ่านตัวกรองเดียวกับรายการที่มองเห็น ใช้ key ประเภท+รหัสหมวด จึงไม่ปนรายรับกับรายจ่ายที่ชื่อเหมือนกัน total ใช้เป็นฐานของกราฟวงกลม ส่วน incomeExpensePercentage ใน DataService คือสัดส่วนรายรับและรายจ่ายต่อผลบวกของทั้งสอง ไม่ใช่อัตรากำไรหรือเปอร์เซ็นต์ออม

mostSpentCategory และ leastSpentCategory เรียงผลรวมรายจ่ายตามหมวด ไม่ใช่โมเดล AI และไม่ทำนายอนาคต ใน Statistic มีกราฟตามช่วงเวลาที่เลือก แต่บางการ์ดใช้ยอดรวมทั้งสกุลเงิน เช่น mostSpentCategory และ incomeExpensePercentage จึงไม่ควรอธิบายว่าทุกการ์ดกรองช่วงเวลาเหมือนกราฟ

## 8. สแกนใบเสร็จ: รูปภาพ → OCR → ตรวจแก้ → รายจ่าย

flutter_application_1/lib/services/receipt_service.dart บรรทัด 18–51

```dart
  static Future<String> _localRead(Uint8List bytes) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError('Offline scanning requires Android or iOS');
    }
    if (_nativeBusy) {
      throw StateError('The previous native scan is still finishing');
    }
    _nativeBusy = true;
    try {
      String? appleText;
      if (Platform.isIOS) {
        try {
          appleText = await const MethodChannel('budgetmate/receipt_ocr')
              .invokeMethod<String>('readText', bytes);
          if (appleText != null &&
              ReceiptDraft.fromText(appleText).amount != null) {
            return appleText;
          }
        } on PlatformException {
          // Older systems and native errors can still use bundled Tesseract.
        } on MissingPluginException {
          // A full native rebuild registers the Apple OCR channel.
        }
      }
      final root = await getTemporaryDirectory();
      final directory =
          await Directory('${root.path}/receipt-ocr-').createTemp();
      final image = File('${directory.path}/receipt');
      try {
        await image.writeAsBytes(bytes, flush: true);
        final text = await FlutterTesseractOcr.extractText(image.path,
            language: 'tha+eng', args: {'psm': '4'});
        if (ReceiptDraft.fromText(text).amount != null) return text;
        return appleText ?? text;
```

รองรับ OCR บน Android และ iOS; iOS ลอง MethodChannel budgetmate/receipt_ocr ก่อน หากอ่านได้และ parser พบยอดจึงใช้ผลนั้น ไม่เช่นนั้นใช้ Tesseract พร้อมโมเดล tha+eng ที่รวมอยู่ใน assets Android ใช้ Tesseract โดยตรง _nativeBusy ป้องกัน native scan ซ้อน แม้ Future ด้าน Dart จะหมดเวลาไปแล้ว

flutter_application_1/lib/services/receipt_service.dart บรรทัด 61–69

```dart
  Future<ReceiptDraft> scan(Uint8List bytes) async {
    final text = await _readText(bytes).timeout(timeout);
    final draft = ReceiptDraft.fromText(text);
    if (draft.amount == null) {
      throw const FormatException('No readable receipt or slip amount');
    }
    return draft;
  }
}
```

scan() จำกัดเวลาตาม timeout ซึ่งค่าเริ่มต้น 55 วินาที แล้วแปลงข้อความเป็น ReceiptDraft ถ้าไม่พบยอดจะ throw FormatException จึงไม่ผ่านไปบันทึกอัตโนมัติ การ OCR ไม่ต้องส่งภาพไป Cloud Vision ในเส้นทางปัจจุบัน แต่การบันทึกรายการยังใช้ Firestore

flutter_application_1/lib/services/receipt_parser.dart บรรทัด 69–81

```dart
        final priority = _transferLabels.hasMatch(name)
            ? 3
            : _netLabels.hasMatch(name)
                ? 2
                : 1;
        if (priority < bestPriority) continue;
        final tail = line.substring(
            label.end,
            labelIndex + 1 < labels.length
                ? labels[labelIndex + 1].start
                : line.length);
        double? value = _moneyValue(tail);
        if (value == null &&
```

flutter_application_1/lib/services/receipt_parser.dart บรรทัด 100–103

```dart
    double? amount = candidates.length == 1 ? candidates.single : null;
    if (candidates.isEmpty && _transferContext.hasMatch(normalized)) {
      final currencyAmounts = <double>{};
      for (var i = 0; i < lines.length; i++) {
```

parser ปรับเลขไทยเป็นเลขอารบิก จัดรูปช่องว่างและอักขระที่ OCR แยกผิด แล้วให้ลำดับความสำคัญกับยอดโอน > ยอดสุทธิ > ยอดทั่วไป หลีกเลี่ยงภาษี เงินทอน ยอดคงเหลือ และเลขอ้างอิง ถ้ามียอดขัดแย้งที่ลำดับเดียวกันจะคืน null ไม่เลือกตัวสุดท้ายเงียบ ๆ

วันที่รองรับรูปแบบตัวเลขและชื่อเดือนไทย/อังกฤษ แปลง พ.ศ. โดยลบ 543 และตรวจวันจริง เช่น 31 กุมภาพันธ์ต้องไม่ผ่าน ชื่อร้าน/ผู้รับพิจารณาป้ายผู้รับและคู่ชื่อกับเลขบัญชีที่ปิดบัง; ถ้าหลักฐานผู้รับไม่พออาจปล่อยว่าง ข้อความทั่วไปที่ไม่ใช่สลิปใช้บรรทัดแรกเป็นชื่อร้าน

flutter_application_1/lib/screens/receipt_scan_screen.dart บรรทัด 160–201

```dart
  Future<void> _save() async {
    if (_busy || !_scanSucceeded) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _message = _t(
          'กรุณากรอกยอดเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != _owner || service.currentCurrency != _currency) {
      setState(() => _message = _t('บัญชีหรือสกุลเงินเปลี่ยน กรุณาเลือกรูปใหม่',
          'Account or currency changed. Select the image again.'));
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var saved = false;
    final receiptStore = LocalReceiptStore();
    try {
      _localReceiptPath ??= await receiptStore.save(_image!,
          owner: uid, isPng: _contentType == 'image/png');

      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          service.currentCurrency != _currency) {
        throw StateError('Account or currency changed');
      }
      final error = await service.addTransaction(
          type: CategoryType.expense,
          amount: amount,
          category: _category!,
          date: _date,
          note: _note.text.trim(),
          receiptPath: _localReceiptPath);
      saved = error == null;
      if (!mounted) return;
```

ก่อนบันทึก ผู้ใช้ต้องตรวจยอด วันที่ สกุลเงิน และเลือกหมวด หน้าจอจำเจ้าของและสกุลเงินตอนเลือกรูป และตรวจซ้ำก่อนสร้างรายจ่ายเพื่อไม่ให้บันทึกข้ามบัญชีเมื่อ session เปลี่ยน ถ้าหาวันที่ไม่ได้ใช้วันนี้ รูปต้องเป็น JPG/PNG และมีขนาดไม่เกิน 5 MB ตามการตรวจใน _pick()

flutter_application_1/lib/services/local_receipt_store.dart บรรทัด 15–29

```dart
  Future<String> save(Uint8List bytes,
      {required String owner, required bool isPng}) async {
    final account = sha256.convert(utf8.encode(owner)).toString();
    final relative = '$account/${const Uuid().v4()}.${isPng ? 'png' : 'jpg'}';
    final root = await _directory();
    final file = File(p.join(root.path, 'receipts', relative));
    await file.parent.create(recursive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return 'local-receipt:$relative';
  }
```

ภาพแนบเก็บใน Application Support ของเครื่อง แบ่งโฟลเดอร์ตาม SHA-256 ของ owner และตั้งชื่อ UUID จากนั้นบันทึก marker local-receipt:... ลงรายการ marker อาจตามข้อมูลไปเครื่องอื่น แต่ bytes ของภาพไม่ตามไปด้วย การ hash ชื่อโฟลเดอร์ไม่ใช่การเข้ารหัสรูป หากบันทึกรายการล้มเหลว หน้าสแกนพยายามลบรูปที่ไม่มีรายการอ้างอิง

flutter_application_1/ios/Runner/ReceiptTextRecognizer.swift บรรทัด 7–16

```swift
    guard #available(iOS 15.0, macOS 12.0, *) else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let supported = try request.supportedRecognitionLanguages()
    guard supported.contains("th-TH") else { return nil }
    request.recognitionLanguages = ["th-TH", "en-US"]
    try VNImageRequestHandler(data: data, options: [:]).perform([request])

    // Bank slips place the label at the left and amount at the far right.
```

Swift ใช้ Vision ตรวจว่า OS และภาษาไทยรองรับหรือไม่ แล้วอ่านภาพแบบ accurate โค้ดที่เหลือจัดกล่องข้อความให้อยู่แถวเดียวกันตามพื้นที่ทับซ้อนแนวตั้ง ก่อนเรียงซ้ายไปขวา เพื่อให้ป้ายยอดกับตัวเลขปลายแถวกลับมาต่อกัน ทั้งนี้ไฟล์ AppDelegate.swift ฝั่ง iOS ขาดอยู่ใน working tree จึงยังยืนยันการลงทะเบียน channel ใน build ปัจจุบันไม่ได้

## 9. บัญชีผู้ใช้ ภาษา ธีม และรูปโปรไฟล์

flutter_application_1/lib/services/data_service.dart บรรทัด 264–285

```dart
  Future<String?> register(String name, String email, String password) async {
    final invalid = passwordValidationKey(password);
    if (invalid != null) return t(invalid);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw FirebaseAuthException(
          code: 'network-timeout',
          message: 'เชื่อมต่อ Firebase ไม่ได้ (หมดเวลา 15 วินาที) - เช็คการเชื่อมต่ออินเทอร์เน็ต',
        ),
      );
      final fbUser = cred.user;
      if (fbUser == null) return t('save_failed');
      await fbUser.updateDisplayName(name);

      final defaults = await getDefaultPreferences();
      final user = UserModel(
        id: fbUser.uid,
        name: name,
        email: email,
```

สมัครสมาชิกตรวจนโยบายรหัสผ่านก่อนเรียก Firebase Auth แล้วใช้ uid เขียนโปรไฟล์ใน Firestore การสร้างบัญชี Auth กับการเขียนโปรไฟล์เป็นคนละขั้นตอน ไม่ใช่ atomic transaction เดียว login() จึงมีทางสร้างโปรไฟล์เมื่อพบว่าบัญชี Auth มีอยู่แต่เอกสารผู้ใช้ยังไม่มี

flutter_application_1/lib/services/data_service.dart บรรทัด 362–379

```dart
  Future<String?> loginWithGoogle() async {
    _googleLoginCreatedAccount = false;
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return t('login_error'); // ผู้ใช้กดยกเลิก

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCred.user;
      if (fbUser == null || fbUser.email == null) return t('login_error');

      // ใช้ uid ของ Firebase Auth เป็น document id เสมอ (แหล่งอ้างอิงเดียวกับ
      // register/login แบบอีเมล-รหัสผ่าน) เพื่อไม่ให้บัญชี Google กับบัญชีอีเมลชนกัน
```

Google Sign-In แลก accessToken/idToken เป็น credential สำหรับ Firebase Auth จากนั้นโหลดหรือสร้างโปรไฟล์ googleLoginCreatedAccount บอกหน้าล็อกอินให้พาบัญชีใหม่ไปตั้งค่าภาษา/สกุลเงิน ส่วนบัญชีเดิมไป Home ตามโค้ดนำทาง

flutter_application_1/lib/services/data_service.dart บรรทัด 552–575

```dart
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final invalid = passwordValidationKey(newPassword);
    if (invalid != null) return t(invalid);
    if (currentUser == null) return t('please_login_first');
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.email == null) return t('please_login_first');

    try {
      final credential = EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return t('wrong_current_password');
        case 'weak-password':
          return t('password_min_length');
        default:
```

changePassword ยืนยันตัวตนซ้ำด้วยรหัสผ่านเดิมก่อน updatePassword ส่วน resetPassword ส่งลิงก์ผ่านอีเมล หน้าเว็บ public/reset_password.html จะรับช่วงการตั้งรหัสใหม่ ไม่ได้เก็บรหัสผ่านลง UserModel

AppStrings เป็น Map ภาษาไทยและอังกฤษ t(key) คืนคำแปล หรือคืน key หากไม่มีคำแปล หมวดมาตรฐานแปลด้วย cat_<id> ส่วนหมวดที่ผู้ใช้ตั้งเองใช้ชื่อเดิม SharedPreferences เก็บธีม ตัวเลือกแจ้งสำเร็จ และค่าตั้งต้นก่อนล็อกอิน ข้อมูลภาษาของผู้ใช้ที่ล็อกอินบันทึกในโปรไฟล์ Firestore

pickAvatar ใช้ image_picker ย่อกว้างไม่เกิน 480 และคุณภาพ 60 ตรวจ bytes ไม่เกิน 700 KiB แล้วเก็บ Base64 ใน users/{uid}.avatar_base64 หลังบันทึกคลาวด์จึงสร้างไฟล์แคชในเครื่อง; ถ้าแคชล้มเหลวไม่ย้อนล้างรูปที่บันทึกสำเร็จแล้ว ข้อความเรื่องแผนบริการในคอมเมนต์ไม่ใช้เป็นข้อสรุปราคาหรือเงื่อนไขบริการปัจจุบัน

## 10. เว็บรีเซ็ตรหัสผ่านและกฎรหัสผ่านร่วม

public/reset_password.js บรรทัด 1–14

```javascript
(function () {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode');
  const oobCode = params.get('oobCode');
  const apiKey = params.get('apiKey');
  // Firebase shares this URL across email templates. Preserve its standard
  // handler for verification, recovery and other non-password-reset actions.
  if (mode && mode !== 'resetPassword') {
    const fallback = new URL('https://budgetmate-app-a94da.firebaseapp.com/__/auth/action');
    fallback.search = params.toString();
    window.location.replace(fallback.href);
    return;
  }

```

หน้าเว็บอ่าน mode, oobCode และ apiKey จาก URL ถ้าเป็น action อื่นจะส่งต่อ handler ของ Firebase ที่ระบุไว้ในโค้ด; ถ้าเป็น resetPassword จึงตรวจรหัสลิงก์กับ API ก่อนแสดงฟอร์ม

public/reset_password.js บรรทัด 114–125

```javascript
  async function requestReset(body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const res = await fetch(apiUrl('resetPassword'), {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body), signal: controller.signal,
      });
      const data = await res.json();
      return {ok: res.ok, data};
    } finally { clearTimeout(timeout); }
  }
```

requestReset ส่ง POST JSON พร้อม AbortController จำกัด 15 วินาที ตอนตรวจลิงก์ส่งเฉพาะ oobCode ตอนตั้งรหัสส่ง oobCode และ newPassword สถานะหน้าแบ่ง loading, invalid, form, success มี retry สำหรับปัญหาเชื่อมต่อ กดบันทึกซ้ำถูกกันด้วย saving และ disable ปุ่ม

flutter_application_1/lib/services/password_policy.dart บรรทัด 24–35

```dart
String? passwordValidationKey(String password) {
  if (password.runes.length < passwordMinLength) return 'password_min_length';
  if (password.length > passwordMaxLength) return 'password_max_length';
  if (password.trim().isEmpty || _blockedPasswords.contains(password.toLowerCase())) {
    return 'password_common';
  }
  if (!RegExp("[a-z]").hasMatch(password)) return 'password_lowercase';
  if (!RegExp("[A-Z]").hasMatch(password)) return 'password_uppercase';
  if (!RegExp("[0-9]").hasMatch(password)) return 'password_digit';
  if (!RegExp("[\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E]").hasMatch(password)) return 'password_symbol';
  return null;
}
```

กฎปัจจุบัน: อย่างน้อย 6 Unicode code points สูงสุด 128 UTF-16 units ต้องมี a–z, A–Z, ตัวเลข และสัญลักษณ์ตาม regex และไม่อยู่ในรายการรหัสที่ปิดกั้น ห้าม trim ค่ารหัสที่นำไปส่งจริง โค้ดเรียก trim เพื่อตรวจว่าเป็นช่องว่างทั้งหมดเท่านั้น

config/password_policy.json เป็นแหล่งแก้กฎ scripts/generate_password_policy.py สร้าง password_policy.dart และ public/password_policy.js ให้ตรงกัน PasswordRequirements แสดงเงื่อนไขใน Flutter ส่วนเว็บมี policy-status และข้อความรหัสยืนยัน นี่เป็นการตรวจฝั่ง client; เอกสารนี้ไม่ได้ตรวจค่าตั้งนโยบายจริงใน Firebase console

## 11. ฐานข้อมูล สิทธิ์ และ backend เดิม

flutter_application_1/lib/services/db_helper.dart บรรทัด 11–25

```dart
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  // The existing database is named 'default', without parentheses.
  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  CollectionReference<Map<String, dynamic>> _col(String table) {
    if (table == 'categories') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      return _fs.collection('users').doc(uid).collection('categories');
    }
```

DBHelper ชื่อคล้ายตัวช่วย SQLite และยังรับ where แบบ id = ? แต่ภายในใช้ Firestore จริง databaseId ตั้งเป็นชื่อ default ซึ่งต่างจากสตริง (default) ต้องให้ตรงกับฐานที่มีในโปรเจกต์ categories เป็น subcollection ของผู้ใช้ ส่วนตารางอื่น map ตรงเป็น collection

query() รองรับเงื่อนไขเท่ากับหนึ่งค่าและ orderBy ที่ใช้ในโปรเจกต์ ไม่ใช่ SQL parser; query และ count มี timeout 10 วินาที แต่ insert/update/delete ไม่ได้ครอบ timeout แบบเดียวกัน insertBatch แบ่งครั้งละ 450 รายการ firestore.indexes.json ระบุดัชนี transactions ตาม user_id และ date สำหรับ query ที่โหลดประวัติ

firestore.rules บรรทัด 4–28

```text
    function owner(uid) { return request.auth != null && request.auth.uid == uid; }
    function validId(id) { return request.resource.data.id == id; }
    match /users/{uid} {
      allow get: if owner(uid);
      allow create, update: if owner(uid) && validId(uid)
        && !request.resource.data.keys().hasAny(['password', 'password_hash']);
      allow delete: if owner(uid);
      match /categories/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && validId(id)
          && request.resource.data.name is string
          && request.resource.data.type in ['income', 'expense'];
      }
    }
    match /transactions/{id} {
      allow read, delete: if owner(resource.data.user_id);
      allow create: if owner(request.resource.data.user_id) && validTransaction(id);
      allow update: if owner(resource.data.user_id)
        && request.resource.data.user_id == resource.data.user_id && validTransaction(id);
    }
    function validTransaction(id) {
      return validId(id) && request.resource.data.amount is number
        && request.resource.data.amount > 0
        && request.resource.data.type in ['income', 'expense']
        && request.resource.data.category_id is string
```

rules ตรวจ Firebase uid ให้ตรงกับเจ้าของเอกสาร การแก้ transaction เปลี่ยน user_id ไม่ได้ และตรวจยอดมากกว่า 0 กับชนิด income/expense โปรไฟล์ไม่อนุญาต field password/password_hash กฎเป้าหมายจำกัด saved_amount ในช่วง 0..target_amount แต่ไม่ได้บังคับความสัมพันธ์ทุกรูปแบบ เช่นรายการโอนกับยอดออมข้ามเอกสารด้วย rules เพียงอย่างเดียว

functions/index.js บรรทัด 1–20

```javascript
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {ImageAnnotatorClient} = require('@google-cloud/vision');
const vision = new ImageAnnotatorClient();

exports.scanReceipt = onCall({region: 'asia-southeast1', timeoutSeconds: 60,
  memory: '512MiB', maxInstances: 3}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const content = request.data?.image;
  if (typeof content !== 'string' || content.length > 7 * 1024 * 1024 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(content)) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  const bytes = Buffer.from(content, 'base64');
  if (!bytes.length || bytes.length > 5 * 1024 * 1024) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  try {
    const [result] = await vision.documentTextDetection({
      image: {content: bytes}, imageContext: {languageHints: ['th', 'en']},
    }, {timeout: 45000});
```

functions/index.js เป็น callable OCR แบบคลาวด์ที่ยังเก็บใน repository ตรวจ auth และภาพ Base64 ก่อนเรียก Google Cloud Vision แล้วส่งข้อความกลับ README ระบุว่าเป็น backend เดิม เส้นทาง ReceiptService ปัจจุบันไม่เรียกฟังก์ชันนี้ storage.rules ก็เป็นกฎภาพ receipts บน Storage ที่ยังเก็บไว้ แต่ LocalReceiptStore ปัจจุบันเก็บภาพในเครื่อง

## 12. ระบบหน้าจอและองค์ประกอบร่วม

Flutter ประกอบหน้าจอด้วย widget tree: Scaffold วางโครงหน้า Column/Row จัดแนว Expanded/Flexible แบ่งพื้นที่ ส่วน StatefulWidget เก็บสถานะฟอร์มและตัวกรอง setState ใช้กับสถานะเฉพาะหน้า และ notifyListeners ใช้กับข้อมูลร่วมของแอป หลัง await หน้าจอมักเช็ค mounted ก่อนเปลี่ยน UI เพื่อไม่ใช้งานหน้าที่ถูกปิดไปแล้ว

flutter_application_1/lib/widgets/amount_keypad.dart บรรทัด 10–28

```dart
  void _press(String key) {
    final text = controller.text;
    final selection = controller.selection;
    var start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final replacement = key == '⌫' ? '' : key;
    if (key == '⌫' && start == end && start > 0) start--;
    var next = text.replaceRange(start, end, replacement);
    var cursor = start + replacement.length;
    if (next.startsWith('.')) {
      next = '0$next';
      cursor++;
    }
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(next) || next.length > 16) {
      return;
    }
    controller.value = TextEditingValue(
      text: next, selection: TextSelection.collapsed(offset: cursor));
  }
```

AmountKeypad แทรกและลบตามตำแหน่ง cursor ไม่ได้ต่อท้ายอย่างเดียว ถ้าเริ่มด้วยจุดจะเติม 0 หน้า ตรวจรูปแบบทศนิยมไม่เกิน 2 ตำแหน่งและข้อความไม่เกิน 16 ตัว ก่อนอัปเดต TextEditingController

flutter_application_1/lib/widgets/responsive_scale.dart บรรทัด 9–19

```dart
class ResponsiveScale extends StatelessWidget {
  const ResponsiveScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: child,
      );
}
```

ResponsiveScale เวอร์ชันนี้ไม่ได้ย่อทั้งจอจากความกว้างเสมือน 360; ทำ SafeArea เฉพาะซ้าย/ขวา ปล่อยแต่ละหน้าดูแลพื้นที่ด้านบน ล่าง และคีย์บอร์ด จึงรักษาการขยายข้อความจากระบบ

flutter_application_1/lib/widgets/success_notice.dart บรรทัด 10–24

```dart
void showSuccessNotice(BuildContext context, String messageKey) {
  final service = context.read<DataService>();
  if (!service.successNotesEnabled) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  final message = service.t(messageKey);
  final dismissLabel = service.t('dismiss_success_notice');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!overlay.mounted) return;
    final previous = _notices[overlay];
    if (previous != null) {
      previous.remove();
      previous.dispose();
    }
    late final OverlayEntry entry;
    void dismiss() {
```

showSuccessNotice วาง OverlayEntry ที่ root overlay จึงยังเห็นข้อความแม้ปิด sheet หรือเปลี่ยนหน้าแล้ว แทนข้อความเก่าด้วยข้อความใหม่ เคารพ successNotesEnabled และมี timer ปิดประมาณ 4 วินาที

## 13. แผนที่ไฟล์: อธิบายรายไฟล์พร้อมโค้ดเต็ม

แต่ละรายการด้านล่างมีหน้าที่ จุดเชื่อมต่อ และโค้ดจริงทั้งไฟล์ กด “เปิดโค้ดเต็ม” ใน HTML เพื่อดูเลขบรรทัด คำอธิบายครอบคลุมไฟล์โปรแกรมของแอป ชุดทดสอบ และโค้ด platform ที่อยู่ใน snapshot; assets และไฟล์ประกอบการ build อธิบายในบัญชีไฟล์ท้ายเล่ม

### 13.1 config/password_reset_email_th.html

โค้ด HTML/CSS ของหน้าเว็บตาม path: โครง DOM รูปแบบข้อความ ปุ่ม และส่วนเชื่อมสคริปต์; public/reset_password.html ใช้ร่วมกับ reset_password.js ส่วน web/index.html เป็นจุดโหลด Flutter web

7 บรรทัด • SHA-256: ac70be86f3b13269

```text
<p>สวัสดี</p>
<p>เราได้รับคำขอรีเซ็ตรหัสผ่านบัญชี BudgetMate ที่ใช้อีเมล %EMAIL%</p>
<p>คลิกลิงก์ด้านล่างเพื่อตั้งรหัสผ่านใหม่</p>
<p><a href="%LINK%">รีเซ็ตรหัสผ่าน</a></p>
<p>หากคุณไม่ได้ส่งคำขอนี้ คุณสามารถละเว้นอีเมลฉบับนี้ได้ รหัสผ่านของคุณจะไม่เปลี่ยนแปลงจนกว่าคุณจะตั้งรหัสผ่านใหม่</p>
<p>ขอบคุณที่ใช้ BudgetMate</p>
<p>ทีม BudgetMate</p>
```

### 13.2 docs/render-flowchart.swift

เครื่องมือสร้างภาพ flowchart จากการวาดด้วย Swift ในเอกสาร ไม่ได้อยู่ในเส้นทาง runtime ของแอป BudgetMate

96 บรรทัด • SHA-256: ed4395631a379c95

```swift
// Run: swift -module-cache-path /tmp/budgetmate-swift-cache docs/render-flowchart.swift
import AppKit

let width = 1800, height = 2100
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: CGFloat(height)); cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
let ink = NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.28, alpha: 1)
func text(_ value: String, _ rect: NSRect, size: CGFloat = 24, bold: Bool = false) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    let font = NSFont(name: bold ? "Thonburi-Bold" : "Thonburi", size: size) ?? NSFont.systemFont(ofSize: size)
    (value as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: style])
}
func box(_ value: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 90, decision: Bool = false) {
    let rect = NSRect(x: x, y: y, width: w, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
    (decision ? NSColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 1) : NSColor(calibratedRed: 0.89, green: 0.95, blue: 0.98, alpha: 1)).setFill(); path.fill()
    ink.withAlphaComponent(0.4).setStroke(); path.lineWidth = 1.5; path.stroke()
    text(value, NSRect(x: x + 12, y: y + 12, width: w - 24, height: h - 16))
}
func arrow(_ x: CGFloat, _ y: CGFloat) {
    ink.setStroke(); ink.setFill()
    let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: y)); p.line(to: NSPoint(x: x, y: y + 24)); p.lineWidth = 2; p.stroke()
    let a = NSBezierPath(); a.move(to: NSPoint(x: x - 6, y: y + 18)); a.line(to: NSPoint(x: x, y: y + 27)); a.line(to: NSPoint(x: x + 6, y: y + 18)); a.close(); a.fill()
}
text("BudgetMate — App Flowchart", NSRect(x: 40, y: 25, width: 1720, height: 65), size: 44, bold: true)
text("แผนผังฉบับย่อ • ตรวจเทียบโค้ดใน workspace วันที่ 10 ตุลาคม 2026", NSRect(x: 40, y: 90, width: 1720, height: 50), size: 24)
box("เปิดแอป → เตรียมข้อมูลและกู้คืน Session", x: 400, y: 150, w: 1000, h: 65)
arrow(900, 218)
box("มีผู้ใช้ในระบบ → หน้าหลัก     |     ไม่มีผู้ใช้ → หน้าเข้าสู่ระบบ (ขั้นตอน 1)", x: 180, y: 250, w: 1440, h: 65, decision: true)
arrow(900, 318)
box("5 แท็บหลัก: หน้าหลัก • กระเป๋าเงิน • เพิ่มรายการ • สถิติ • เมนูบัญชี", x: 100, y: 350, w: 1600, h: 65)
text("ทางลัดในหน้าหลัก / กระเป๋าเงิน / เมนูบัญชี: จดรายจ่าย • สลิป/ใบเสร็จ • ธุรกรรม • ออมเงิน", NSRect(x: 60, y: 435, width: 1680, height: 50), size: 23)

let panels: [(String, [String])] = [
 ("1  เข้าสู่ระบบและสมัครสมาชิก", [
 "อีเมล + รหัสผ่าน\nสำเร็จ → หน้าหลัก / ผิดพลาด → แก้ไข",
 "Google สำเร็จ: บัญชีเดิม → หน้าหลัก\nสร้างบัญชีใหม่ → เลือกภาษาและสกุลเงิน",
 "สมัครสมาชิก → ตรวจข้อมูลและสร้างบัญชี\nสำเร็จ → เลือกภาษาและสกุลเงิน",
 "บันทึกการตั้งค่าสำเร็จ → หน้าหลัก\nหากไม่มีผู้ใช้ในระบบ → หน้าเข้าสู่ระบบ",
 "ลืมรหัสผ่าน → ขอส่งลิงก์ทางอีเมล\nตั้งรหัสใหม่ผ่านลิงก์ → กลับมาเข้าสู่ระบบ"
 ]),
 ("2  เพิ่มรายรับ / รายจ่าย", [
 "เลือกประเภทรายการ\nกรอกจำนวนเงิน หมวดหมู่ และหมายเหตุ",
 "จำนวนเงิน > 0 และเลือกหมวดหมู่?\nไม่ผ่าน → แก้ไข / ผ่าน → รายการรอบันทึก",
 "เพิ่มอีก / แก้ไข / ลบรายการรอบันทึก\nเมื่อพร้อม → กดยืนยันบันทึก",
 "บันทึกทีละรายการ\nผิดพลาด → ตรวจรายการที่ยังรอบันทึก",
 "สำเร็จทั้งหมด → รายการธุรกรรม\nIncomeExpenseScreen"
 ]),
 ("3  สลิป / ใบเสร็จ", [
 "เปิดจากทางลัด หรือหน้าเพิ่มรายการ\nถ่ายรูป / เลือกรูปภาพ",
 "อ่านข้อมูลจากภาพสำเร็จ?\nไม่สำเร็จ → ลองใหม่หรือเลือกรูปใหม่",
 "สำเร็จ → ตรวจแก้ยอดเงิน วันที่ หมายเหตุ\nและเลือกหมวดหมู่รายจ่าย",
 "ตรวจข้อมูล → บันทึกรายจ่ายพร้อมรูป\nผิดพลาด → แก้ไข / ลองบันทึกอีกครั้ง",
 "บันทึกสำเร็จ → ประวัติรายการ\nHistoryScreen"
 ]),
 ("4  เป้าหมายการออม", [
 "เปิดจากทางลัด / หน้าหลัก / กระเป๋าเงิน\nดูเป้าหมายการออม",
 "สร้าง / แก้ไข / ยืนยันลบ / ปักหมุด\nหรือเลือกโอนเงินเข้าเป้าหมาย",
 "กรอกจำนวนเงิน > 0\nไม่เกินยอดคงเหลือและยอดที่ยังขาด",
 "ไม่ผ่าน / บันทึกผิดพลาด → แก้ไขหรือลองใหม่\nผ่าน → บันทึกการโอน",
 "เพิ่มยอดออม + สร้างรายจ่ายการออม\nยอดคงเหลือลดลง → หน้าเป้าหมาย"
 ]),
 ("5  กระเป๋าเงิน / ธุรกรรม / สถิติ", [
 "กระเป๋าเงิน → ดูยอดคงเหลือ\nและสรุปรายรับ–รายจ่าย",
 "แตะสรุป หรือทางลัดธุรกรรม\n→ รายการรายรับ–รายจ่าย",
 "เลือกรายการ → ดูรายละเอียด\nแก้ไข / ทำสำเนา / ยืนยันลบ",
 "หน้าหลัก → ประวัติรายการ\nดูรายการย้อนหลัง",
 "แท็บสถิติ → เลือกช่วงเวลา\nดูกราฟและความคืบหน้าการออม"
 ]),
 ("6  เมนูบัญชี", [
 "แก้ไขชื่อและรูปโปรไฟล์\nเปลี่ยนรหัสผ่าน",
 "เลือกภาษา\nเปลี่ยนธีมสว่าง / มืด",
 "เปิด / ปิดการแจ้งบันทึกสำเร็จ\nดูข้อมูลเกี่ยวกับแอป",
 "กดออกจากระบบ\nล้างสถานะเข้าสู่ระบบ",
 "กลับหน้าเข้าสู่ระบบ\nLoginScreen"
 ])
]
for (index, panel) in panels.enumerated() {
    let x = CGFloat(40 + (index % 3) * 590), y = CGFloat(510 + (index / 3) * 740)
    text(panel.0, NSRect(x: x, y: y, width: 540, height: 55), size: 25, bold: true)
    for (i, label) in panel.1.enumerated() {
        let top = y + 62 + CGFloat(i) * 123
        box(label, x: x, y: top, w: 540, h: 94, decision: label.contains("?") || label.contains("ไม่ผ่าน"))
        // Independent alternatives are intentionally not connected as a sequence.
        if i < 4 && [1, 2, 3].contains(index) { arrow(x + 270, top + 96) }
        if index == 5 && i == 3 { arrow(x + 270, top + 96) }
    }
}
text("ลูกศรแสดงลำดับขั้นตอน • กล่องที่ไม่มีลูกศรเชื่อมเป็นตัวเลือกหรือเส้นทางแยก\nรายละเอียด เงื่อนไข และไฟล์อ้างอิงเพิ่มเติม: docs/app-flowchart.md", NSRect(x: 50, y: 1990, width: 1700, height: 90), size: 23)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/app-flowchart.png"))
```

### 13.3 firestore.rules

กฎ Firebase Security Rules ตรวจสิทธิ์ตาม uid เจ้าของและเงื่อนไขข้อมูล; อ่านบท 11 ประกอบ ไม่ยืนยันว่าไฟล์นี้ถูก deploy แล้ว

46 บรรทัด • SHA-256: dc894ea493f11768

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function owner(uid) { return request.auth != null && request.auth.uid == uid; }
    function validId(id) { return request.resource.data.id == id; }
    match /users/{uid} {
      allow get: if owner(uid);
      allow create, update: if owner(uid) && validId(uid)
        && !request.resource.data.keys().hasAny(['password', 'password_hash']);
      allow delete: if owner(uid);
      match /categories/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && validId(id)
          && request.resource.data.name is string
          && request.resource.data.type in ['income', 'expense'];
      }
    }
    match /transactions/{id} {
      allow read, delete: if owner(resource.data.user_id);
      allow create: if owner(request.resource.data.user_id) && validTransaction(id);
      allow update: if owner(resource.data.user_id)
        && request.resource.data.user_id == resource.data.user_id && validTransaction(id);
    }
    function validTransaction(id) {
      return validId(id) && request.resource.data.amount is number
        && request.resource.data.amount > 0
        && request.resource.data.type in ['income', 'expense']
        && request.resource.data.category_id is string
        && request.resource.data.date is string;
    }
    match /goals/{id} {
      allow read, delete: if owner(resource.data.user_id);
      allow create: if owner(request.resource.data.user_id) && validGoal(id);
      allow update: if owner(resource.data.user_id)
        && request.resource.data.user_id == resource.data.user_id && validGoal(id);
    }
    function validGoal(id) {
      return validId(id) && request.resource.data.target_amount is number
        && request.resource.data.target_amount > 0
        && request.resource.data.saved_amount is number
        && request.resource.data.saved_amount >= 0
        && request.resource.data.saved_amount <= request.resource.data.target_amount
        && request.resource.data.status in ['inProgress', 'completed'];
    }
  }
}
```

### 13.4 flutter_application_1/android/app/build.gradle.kts

สคริปต์ Gradle Kotlin DSL ตั้งค่า Android build และ plugins; app/build.gradle.kts ระบุ SDK, applicationId, Java 17 และ release signing แบบ debug ใน snapshot นี้

47 บรรทัด • SHA-256: e64611dd57a82d63

```text
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
```

### 13.5 flutter_application_1/android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt

Activity หลัก Android สืบทอด FlutterActivity เป็น host สำหรับ Flutter engine ไม่ได้คำนวณรายรับรายจ่าย

โครงสร้างที่ประกาศ: class MainActivity : FlutterActivity() (L5)

5 บรรทัด • SHA-256: ee5ca248be85304f

```text
package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

### 13.6 flutter_application_1/android/build.gradle.kts

สคริปต์ Gradle Kotlin DSL ตั้งค่า Android build และ plugins; app/build.gradle.kts ระบุ SDK, applicationId, Java 17 และ release signing แบบ debug ใน snapshot นี้

24 บรรทัด • SHA-256: 6a26dba2cb8dfba1

```text
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
```

### 13.7 flutter_application_1/android/settings.gradle.kts

สคริปต์ Gradle Kotlin DSL ตั้งค่า Android build และ plugins; app/build.gradle.kts ระบุ SDK, applicationId, Java 17 และ release signing แบบ debug ใน snapshot นี้

29 บรรทัด • SHA-256: 7b3642632af3dbe9

```text
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
```

### 13.8 flutter_application_1/ios/Runner/ReceiptTextRecognizer.swift

ตัวอ่าน Vision บนเครื่อง ตรวจภาษาไทย แล้วรวมกล่องข้อความตามแถวและเรียงซ้ายไปขวา คืน nil เมื่อระบบไม่รองรับเพื่อให้ fallback

โครงสร้างที่ประกาศ: enum ReceiptTextRecognizer (L5)

43 บรรทัด • SHA-256: ff6079685090e5fc

```swift
import Foundation
import Vision

/// On-device OCR. Returning nil lets older systems fall back to Tesseract.
enum ReceiptTextRecognizer {
  static func read(_ data: Data) throws -> String? {
    guard #available(iOS 15.0, macOS 12.0, *) else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let supported = try request.supportedRecognitionLanguages()
    guard supported.contains("th-TH") else { return nil }
    request.recognitionLanguages = ["th-TH", "en-US"]
    try VNImageRequestHandler(data: data, options: [:]).perform([request])

    // Bank slips place the label at the left and amount at the far right.
    // Reassemble observations by visual row, not by OCR block order.
    let observations = (request.results ?? []).sorted {
      $0.boundingBox.midY > $1.boundingBox.midY
    }
    var rows: [[VNRecognizedTextObservation]] = []
    for observation in observations {
      if let index = rows.firstIndex(where: { row in
        guard let first = row.first else { return false }
        let a = first.boundingBox
        let b = observation.boundingBox
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        // Amounts often use much larger type than their label. Match shared
        // vertical space instead of requiring nearly identical text centers.
        return overlap > min(a.height, b.height) * 0.6
      }) {
        rows[index].append(observation)
      } else {
        rows.append([observation])
      }
    }
    return rows.map { row in
      row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")
    }.joined(separator: "\n")
  }
}
```

### 13.9 flutter_application_1/ios/Runner/Runner-Bridging-Header.h

Header เชื่อม Objective-C กับ Swift ของ iOS runner โดย import GeneratedPluginRegistrant เพื่อให้ Swift เรียกตัวลงทะเบียน Flutter plugins ได้

1 บรรทัด • SHA-256: 1a8d11d01d1cc92c

```text
#import "GeneratedPluginRegistrant.h"
```

### 13.10 flutter_application_1/ios/RunnerTests/RunnerTests.swift

ชุดทดสอบ: โครงทดสอบฝั่ง native ที่มากับโปรเจกต์ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

โครงสร้างที่ประกาศ: class RunnerTests: XCTestCase (L5)

12 บรรทัด • SHA-256: 5e8f4908dacea6f2

```swift
import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}
```

### 13.11 flutter_application_1/lib/firebase_options.dart

ค่าตั้ง Firebase ที่ FlutterFire สร้าง เลือก Android/iOS/macOS ตาม platform ส่วน web/windows/linux โยน UnsupportedError จึงมีโฟลเดอร์ platform ไม่ได้แปลว่ารันได้ครบทุกระบบ

โครงสร้างที่ประกาศ: class DefaultFirebaseOptions (L8)

65 บรรทัด • SHA-256: a7c8bdf23c120bf4

```dart
// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC0JWDJifYyt2RftAC-LugntNO70Zns8Nc',
    appId: '1:636277696280:android:cc79a1007baa596ba1206d',
    messagingSenderId: '636277696280',
    projectId: 'budgetmate-app-a94da',
    storageBucket: 'budgetmate-app-a94da.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_bR-20sEJp6CpbU7Bgh9poAtBHnsMREQ',
    appId: '1:636277696280:ios:15564d6417db857fa1206d',
    messagingSenderId: '636277696280',
    projectId: 'budgetmate-app-a94da',
    storageBucket: 'budgetmate-app-a94da.firebasestorage.app',
    iosClientId: '636277696280-2r1tehf0qj7okml610e5t7909q1sonve.apps.googleusercontent.com',
    iosBundleId: 'com.promporn.budgetmate',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD_bR-20sEJp6CpbU7Bgh9poAtBHnsMREQ',
    appId: '1:636277696280:ios:5c02afbb198561fca1206d',
    messagingSenderId: '636277696280',
    projectId: 'budgetmate-app-a94da',
    storageBucket: 'budgetmate-app-a94da.firebasestorage.app',
    iosClientId: '636277696280-uu3s353g6un9d3mov24m31j336fr0vio.apps.googleusercontent.com',
    iosBundleId: 'com.example.flutterApplication1',
  );
}
```

### 13.12 flutter_application_1/lib/main.dart

จุดเริ่มแอป ตั้ง Firebase และ locale แล้วห่อ MaterialApp ด้วย Provider/Consumer ของ DataService; AppScrollBehavior เพิ่มการลากด้วยเมาส์และ trackpad

โครงสร้างที่ประกาศ: class AppScrollBehavior extends MaterialScrollBehavior (L24); class BudgetMateApp extends StatelessWidget (L34)

79 บรรทัด • SHA-256: f060bebac4bbf6ba

```dart
import 'package:budgetmate/firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/data_service.dart';
import 'screens/loading_screen.dart';
import 'screens/app_theme.dart' show appFontFamily, AppColors, AppTheme;
import 'widgets/responsive_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เตรียมข้อมูล locale ภาษาไทยสำหรับ DateFormat (เช่น ชื่อเดือน/วันภาษาไทย)
  // ต้องเรียกก่อน runApp ไม่งั้นจะเจอ LocaleDataException ตอนใช้ DateFormat(..., 'th')
  await initializeDateFormatting('th', null);

  runApp(const BudgetMateApp());
}

/// อนุญาตให้ลากด้วยเมาส์/ทัชแพด/ปากกา เพื่อเลื่อน list ได้ (Web/Desktop)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class BudgetMateApp extends StatelessWidget {
  const BudgetMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService(),
      child: Consumer<DataService>(
        builder: (context, service, _) {
          AppColors.brightness = service.themeMode == ThemeMode.dark
              ? Brightness.dark
              : Brightness.light;
          return MaterialApp(
            title: 'BUDGETMATE',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            themeMode: service.themeMode,
            // ปรับขนาดทุกหน้าให้พอดีกับความกว้างจอจริง
            builder: (context, child) => ResponsiveScale(child: child!),
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.black,
              brightness: Brightness.light,
              fontFamily: appFontFamily,
              appBarTheme: const AppBarTheme(
                toolbarHeight: 56,
                titleTextStyle: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: AppTheme.dark,
            home: const LoadingScreen(),
          );
        },
      ),
    );
  }
}
```

### 13.13 flutter_application_1/lib/models/category_model.dart

กำหนด CategoryType, หมวดมาตรฐาน c01–c55 และหมวดลูก; CategoryIcon เลือกภาพ artwork หรือภาพ asset ก่อน fallback เป็นไอคอน คอมเมนต์เรื่อง seed SQLite เป็นข้อความเก่า

โครงสร้างที่ประกาศ: enum CategoryType (L7); class CategoryModel (L10); class CategoryIcon extends StatelessWidget (L84)

229 บรรทัด • SHA-256: 92f876e506c1b4e3

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'persisted_icons.dart';
import '../widgets/pastel_artwork.dart';

/// ประเภทของหมวดหมู่ สอดคล้องกับ Entity Category (category_type)
enum CategoryType { income, expense }

/// เอนทิตี้ Category ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class CategoryModel {
  final String id; // category_id
  final String name; // category_name
  final CategoryType type; // category_type
  final IconData icon; // ไอคอน fallback เสมอ (ใช้ตอนยังไม่มีรูป หรือโหลดรูปไม่สำเร็จ)
  final String? description; // description

  /// path ไฟล์รูปภาพไอคอนหมวดหมู่ (เช่น 'assets/images/categories/c01.png')
  /// ถ้าเป็น null หรือโหลดไฟล์ไม่สำเร็จ (เช่น ยังไม่ได้ใส่ไฟล์จริงลง assets)
  /// ตัว CategoryIcon widget จะ fallback กลับไปแสดง [icon] แทนโดยอัตโนมัติ
  final String? imagePath;
  final int? artworkNumber;
  final int? colorValue;
  final List<String> subcategories;

  List<CategoryModel> get childCategories => [
    for (var i = 0; i < subcategories.length; i++)
      CategoryModel(id: '$id:sub:$i', name: '$name › ${subcategories[i]}',
        type: type, icon: icon, imagePath: imagePath,
        artworkNumber: artworkNumber, colorValue: colorValue),
  ];

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.description,
    this.imagePath,
    this.artworkNumber,
    this.colorValue,
    this.subcategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'icon_code': icon.codePoint,
      'description': description,
      'image_path': imagePath,
      'artwork_number': artworkNumber,
      'color_value': colorValue,
      'subcategories': subcategories,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      // หมายเหตุ: ไอคอนมาตรฐานของ Icons.* ใช้ fontFamily 'MaterialIcons'
      icon: persistedIconFromCodePoint(map['icon_code'] as int),
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      artworkNumber: (map['artwork_number'] as num?)?.toInt(),
      colorValue: (map['color_value'] as num?)?.toInt(),
      subcategories: List<String>.from(map['subcategories'] as List? ?? const []),
    );
  }
}

/// วิดเจ็ตแสดงไอคอนของหมวดหมู่ — ใช้แทน `Icon(category.icon, ...)` ได้ทุกจุดในแอป
/// ถ้า [CategoryModel.imagePath] ตั้งไว้และโหลดรูปสำเร็จ จะแสดงรูปภาพนั้นแทน
/// ถ้าไม่ได้ตั้งไว้ (null) หรือโหลดรูปไม่สำเร็จ (เช่น ยังไม่มีไฟล์จริงใน assets)
/// จะ fallback กลับไปแสดง Material Icon (category.icon) โดยอัตโนมัติ ไม่ทำให้แอปพัง
///
/// หมายเหตุเรื่องสี: [color] จะถูกใช้ "ทาสีทับ" เฉพาะตอน fallback เป็น Material Icon
/// เท่านั้น (เช่น ตอนที่ยังไม่มีไฟล์รูปจริง) ส่วนตอนแสดงรูปภาพจริงจะ "ไม่" ทาสีทับ
/// เพราะรูปภาพหมวดหมู่มักเป็นภาพสีเต็ม/หลายสี ถ้า tint สีทับ (เช่นตอนเลือกแล้วเปลี่ยน
/// เป็นสีขาว) จะทำให้รูปเพี้ยนหรือมองไม่เห็นรายละเอียด จึงปล่อยให้รูปแสดงสีตามต้นฉบับ
/// แล้วใช้สีพื้นหลัง/ขอบกรอบรอบๆ แทนในการสื่อสถานะ selected/unselected
class CategoryIcon extends StatelessWidget {
  final CategoryModel category;
  final double size;
  final Color? color;

  /// ถ้า true: รูปภาพจะถูกวางอยู่ในกรอบขนาด [size] x [size] โดยใช้ BoxFit.contain
  /// นั่นคือรูปจะถูกย่อ/ขยายให้ "พอดีกับกรอบตามสัดส่วนจริงของไฟล์ภาพ" เสมอ
  /// (ไม่ครอบตัด ไม่บิดสัดส่วน) ต่างจากโหมดปกติที่วางรูปแบบไอคอนเล็กลอยตัว
  /// ใช้ตอนอยากให้เห็นรูปเต็มพื้นที่กรอบ เช่น ตะแกรงเลือกหมวดหมู่ใน Add Income/Expense
  final bool fill;

  /// ระดับซูมภาพ (ใช้เฉพาะตอน fill = true) สำหรับปรับภาพให้เต็มกรอบมากขึ้นเล็กน้อย
  /// โดยยังคงสัดส่วนเดิมของภาพไว้ (ไม่ยืด/บิด) ค่า 1.0 = ไม่ซูม
  /// มากกว่า 1.0 = ซูมเข้าเล็กน้อย แต่รูปจะยังคงแสดงตามสัดส่วนจริงเสมอ
  final double zoom;

  /// รัศมีมุมโค้งของกรอบตัดภาพตอน fill = true ให้เข้ากับทรงกรอบสี่เหลี่ยมมุมโค้ง
  /// ของ container ด้านนอก (ค่าเริ่มต้นอ้างอิงจาก AppRadius.md ของดีไซน์ระบบ)
  final double? clipRadius;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.color,
    this.fill = false,
    this.zoom = 1.0,
    this.clipRadius,
  });

  @override
  Widget build(BuildContext context) {
    final number = int.tryParse(category.id.replaceFirst('c', ''));
    if (number != null && category.id == 'c${number.toString().padLeft(2, '0')}' && number >= 1 && number <= 55) {
      return PastelArtwork(categoryNumber: number, size: size);
    }
    if (category.artworkNumber != null) {
      return PastelArtwork(categoryNumber: category.artworkNumber!, size: size);
    }
    final path = category.imagePath;
    if (path == null || path.isEmpty) {
      return GoalArtwork(category.icon, size: size, color: color);
    }
    if (fill) {
      // ใช้ BoxFit.contain แทน cover เพื่อให้ "ขนาดที่แสดงจริงของรูปปรับตามสัดส่วน
      // ต้นฉบับของไฟล์ภาพที่ใส่เข้ามา" เสมอ ไม่ว่าไฟล์จะเป็นแนวตั้ง แนวนอน หรือจัตุรัส
      // ก็จะถูกย่อ/ขยายให้พอดีกับกรอบ [size] x [size] โดยไม่ครอบตัดหรือบิดสัดส่วน
      return ClipRRect(
        borderRadius: BorderRadius.circular(clipRadius ?? AppRadius.md),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Transform.scale(
              scale: zoom,
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(category.icon, size: size * 0.55, color: color),
              ),
            ),
          ),
        ),
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) =>
          Icon(category.icon, size: size, color: color),
    );
  }
}

/// หมวดหมู่เริ่มต้นของระบบ (จะถูก seed ลง SQLite อัตโนมัติครั้งแรกที่เปิดแอป)
/// imagePath เตรียม path ไว้ล่วงหน้าตาม id (เช่น c01 -> c01.png) พอมีไฟล์รูปจริง
/// แค่นำไปวางที่ assets/images/categories/ ตามชื่อไฟล์นี้ได้เลย ไม่ต้องแก้โค้ดเพิ่ม
/// (ถ้ายังไม่มีไฟล์ตอนนี้ก็ไม่เป็นไร CategoryIcon จะ fallback ไปใช้ icon เดิมให้อัตโนมัติ)
const String _catImgBase = 'assets/images/categories';
final List<CategoryModel> defaultCategories = [
  CategoryModel(id: 'c01', name: 'อาหาร', type: CategoryType.expense, icon: Icons.restaurant, imagePath: '$_catImgBase/c01.png'),
  CategoryModel(id: 'c02', name: 'เครื่องดื่ม', type: CategoryType.expense, icon: Icons.local_cafe, imagePath: '$_catImgBase/c02.png'),
  CategoryModel(id: 'c03', name: 'ที่พัก', type: CategoryType.expense, icon: Icons.home, imagePath: '$_catImgBase/c03.png'),
  CategoryModel(id: 'c04', name: 'ยานพาหนะ', type: CategoryType.expense, icon: Icons.directions_car, imagePath: '$_catImgBase/c04.png'),
  CategoryModel(id: 'c05', name: 'ภาษี', type: CategoryType.expense, icon: Icons.receipt_long, imagePath: '$_catImgBase/c05.png'),
  CategoryModel(id: 'c06', name: 'ช้อปปิ้ง', type: CategoryType.expense, icon: Icons.shopping_bag, imagePath: '$_catImgBase/c06.png'),
  CategoryModel(id: 'c07', name: 'ของขวัญ', type: CategoryType.expense, icon: Icons.card_giftcard, imagePath: '$_catImgBase/c07.png'),
  CategoryModel(id: 'c08', name: 'ท่องเที่ยว', type: CategoryType.expense, icon: Icons.flight, imagePath: '$_catImgBase/c08.png'),
  CategoryModel(id: 'c09', name: 'ความงาม', type: CategoryType.expense, icon: Icons.spa, imagePath: '$_catImgBase/c09.png'),
  CategoryModel(id: 'c10', name: 'บันเทิง', type: CategoryType.expense, icon: Icons.music_note, imagePath: '$_catImgBase/c10.png'),
  CategoryModel(id: 'c11', name: 'กีฬา', type: CategoryType.expense, icon: Icons.sports_soccer, imagePath: '$_catImgBase/c11.png'),
  CategoryModel(id: 'c12', name: 'สัตว์เลี้ยง', type: CategoryType.expense, icon: Icons.pets, imagePath: '$_catImgBase/c12.png'),
  CategoryModel(id: 'c13', name: 'การศึกษา', type: CategoryType.expense, icon: Icons.school, imagePath: '$_catImgBase/c13.png'),
  CategoryModel(id: 'c14', name: 'เงินเดือน', type: CategoryType.income, icon: Icons.payments, imagePath: '$_catImgBase/c14.png'),
  CategoryModel(id: 'c15', name: 'รายได้เสริม', type: CategoryType.income, icon: Icons.trending_up, imagePath: '$_catImgBase/c15.png'),
  CategoryModel(id: 'c16', name: 'โบนัส', type: CategoryType.income, icon: Icons.card_membership, imagePath: '$_catImgBase/c16.png'),

  // หมวดหมู่รายจ่ายพิเศษ: ใช้บันทึกอัตโนมัติเมื่อผู้ใช้ "โอนเงินจริง" เข้าเป้าหมายการออม
  // (ต้องใช้ id คงที่ 'c17' เพื่อให้ DataService ค้นหา/สร้างซ้ำได้อย่างสม่ำเสมอ)
  CategoryModel(id: 'c17', name: 'เงินออม', type: CategoryType.expense, icon: Icons.savings, imagePath: '$_catImgBase/c17.png'),

  // ===== หมวดหมู่รายรับเพิ่มเติม (ตามชุดไอคอนอ้างอิง) =====
  CategoryModel(id: 'c18', name: 'เงินออม', type: CategoryType.income, icon: Icons.savings, imagePath: '$_catImgBase/c18.png'),
  CategoryModel(id: 'c19', name: 'ค่าคอมมิชชั่น', type: CategoryType.income, icon: Icons.handshake, imagePath: '$_catImgBase/c19.png'),
  CategoryModel(id: 'c20', name: 'ลงทุน', type: CategoryType.income, icon: Icons.currency_bitcoin, imagePath: '$_catImgBase/c20.png'),
  CategoryModel(id: 'c21', name: 'ปันผล', type: CategoryType.income, icon: Icons.insights, imagePath: '$_catImgBase/c21.png'),
  CategoryModel(id: 'c22', name: 'ค่าเช่ารับ', type: CategoryType.income, icon: Icons.home_work, imagePath: '$_catImgBase/c22.png'),
  CategoryModel(id: 'c23', name: 'รายได้ธุรกิจ', type: CategoryType.income, icon: Icons.storefront, imagePath: '$_catImgBase/c23.png'),
  CategoryModel(id: 'c24', name: 'ทุนการศึกษา', type: CategoryType.income, icon: Icons.school, imagePath: '$_catImgBase/c24.png'),
  CategoryModel(id: 'c25', name: 'เงินคืน/คืนภาษี', type: CategoryType.income, icon: Icons.request_quote, imagePath: '$_catImgBase/c25.png'),
  CategoryModel(id: 'c26', name: 'รางวัล', type: CategoryType.income, icon: Icons.emoji_events, imagePath: '$_catImgBase/c26.png'),
  CategoryModel(id: 'c27', name: 'รับจากครอบครัว', type: CategoryType.income, icon: Icons.family_restroom, imagePath: '$_catImgBase/c27.png'),
  CategoryModel(id: 'c28', name: 'รับจากเพื่อน', type: CategoryType.income, icon: Icons.people_alt, imagePath: '$_catImgBase/c28.png'),
  CategoryModel(id: 'c29', name: 'ขายของออนไลน์', type: CategoryType.income, icon: Icons.sell, imagePath: '$_catImgBase/c29.png'),
  CategoryModel(id: 'c30', name: 'รายได้จากงานอดิเรก', type: CategoryType.income, icon: Icons.camera_alt, imagePath: '$_catImgBase/c30.png'),
  CategoryModel(id: 'c31', name: 'ลิขสิทธิ์/ค่าสิทธิ์', type: CategoryType.income, icon: Icons.copyright, imagePath: '$_catImgBase/c31.png'),
  CategoryModel(id: 'c32', name: 'รายได้อื่นๆ', type: CategoryType.income, icon: Icons.star_rounded, imagePath: '$_catImgBase/c32.png'),
  CategoryModel(id: 'c33', name: 'เงินสนับสนุน', type: CategoryType.income, icon: Icons.volunteer_activism, imagePath: '$_catImgBase/c33.png'),
  CategoryModel(id: 'c34', name: 'เงินช่วยเหลือ', type: CategoryType.income, icon: Icons.support, imagePath: '$_catImgBase/c34.png'),

  // ===== หมวดหมู่รายจ่ายเพิ่มเติม (ตามชุดไอคอนอ้างอิง) =====
  CategoryModel(id: 'c35', name: 'กาแฟ', type: CategoryType.expense, icon: Icons.local_cafe, imagePath: '$_catImgBase/c35.png'),
  CategoryModel(id: 'c36', name: 'ค่าเดินทาง', type: CategoryType.expense, icon: Icons.commute, imagePath: '$_catImgBase/c36.png'),
  CategoryModel(id: 'c37', name: 'แท็กซี่', type: CategoryType.expense, icon: Icons.local_taxi, imagePath: '$_catImgBase/c37.png'),
  CategoryModel(id: 'c38', name: 'น้ำมันรถ', type: CategoryType.expense, icon: Icons.local_gas_station, imagePath: '$_catImgBase/c38.png'),
  CategoryModel(id: 'c39', name: 'ค่าจอดรถ', type: CategoryType.expense, icon: Icons.local_parking, imagePath: '$_catImgBase/c39.png'),
  CategoryModel(id: 'c40', name: 'ที่อยู่อาศัย', type: CategoryType.expense, icon: Icons.apartment, imagePath: '$_catImgBase/c40.png'),
  CategoryModel(id: 'c41', name: 'ค่าน้ำไฟ', type: CategoryType.expense, icon: Icons.lightbulb, imagePath: '$_catImgBase/c41.png'),
  CategoryModel(id: 'c42', name: 'ค่าน้ำ', type: CategoryType.expense, icon: Icons.water_drop, imagePath: '$_catImgBase/c42.png'),
  CategoryModel(id: 'c43', name: 'ของใช้ในบ้าน', type: CategoryType.expense, icon: Icons.shopping_cart, imagePath: '$_catImgBase/c43.png'),
  CategoryModel(id: 'c44', name: 'เสื้อผ้า', type: CategoryType.expense, icon: Icons.checkroom, imagePath: '$_catImgBase/c44.png'),
  CategoryModel(id: 'c45', name: 'โทรศัพท์', type: CategoryType.expense, icon: Icons.smartphone, imagePath: '$_catImgBase/c45.png'),
  CategoryModel(id: 'c46', name: 'อินเทอร์เน็ต', type: CategoryType.expense, icon: Icons.wifi, imagePath: '$_catImgBase/c46.png'),
  CategoryModel(id: 'c47', name: 'สตรีมมิ่ง', type: CategoryType.expense, icon: Icons.subscriptions, imagePath: '$_catImgBase/c47.png'),
  CategoryModel(id: 'c48', name: 'สุขภาพ', type: CategoryType.expense, icon: Icons.fitness_center, imagePath: '$_catImgBase/c48.png'),
  CategoryModel(id: 'c49', name: 'ค่ารักษาพยาบาล', type: CategoryType.expense, icon: Icons.local_hospital, imagePath: '$_catImgBase/c49.png'),
  CategoryModel(id: 'c50', name: 'ยา', type: CategoryType.expense, icon: Icons.medication, imagePath: '$_catImgBase/c50.png'),
  CategoryModel(id: 'c51', name: 'ประกัน', type: CategoryType.expense, icon: Icons.health_and_safety, imagePath: '$_catImgBase/c51.png'),
  CategoryModel(id: 'c52', name: 'อุปกรณ์การเรียน', type: CategoryType.expense, icon: Icons.edit_note, imagePath: '$_catImgBase/c52.png'),
  CategoryModel(id: 'c53', name: 'ทริป/กิจกรรม', type: CategoryType.expense, icon: Icons.camera_alt, imagePath: '$_catImgBase/c53.png'),
  CategoryModel(id: 'c54', name: 'ดูหนัง', type: CategoryType.expense, icon: Icons.local_movies, imagePath: '$_catImgBase/c54.png'),
  CategoryModel(id: 'c55', name: 'เกม', type: CategoryType.expense, icon: Icons.sports_esports, imagePath: '$_catImgBase/c55.png'),

];
```

### 13.14 flutter_application_1/lib/models/goal_model.dart

ข้อมูลเป้าหมายพร้อมสถานะ ปักหมุด โน้ต และสกุลเงิน; progress/isNearTarget ใช้แสดงความคืบหน้า copyWith และ toMap/fromMap ใช้แก้และจัดเก็บ

โครงสร้างที่ประกาศ: enum GoalStatus (L4); class GoalModel (L7)

104 บรรทัด • SHA-256: a6ba0c2c5de0408b

```dart
import 'package:flutter/material.dart';
import 'persisted_icons.dart';

enum GoalStatus { inProgress, completed }

/// เอนทิตี้ Goal_Saving ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class GoalModel {
  final String? currency;
  final String id; // goal_id
  final String name; // goal_name
  final double targetAmount; // target_amount
  double savedAmount; // saved_amount
  final DateTime startDate; // start_date
  final DateTime targetDate; // target_date
  GoalStatus status; // status
  final IconData icon;
  final int? artworkNumber;
  final bool isPinned;
  final String? note; // หมายเหตุ (optional)

  GoalModel({
    required this.id,
    this.currency,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.startDate,
    required this.targetDate,
    required this.icon,
    this.status = GoalStatus.inProgress,
    this.note,
    this.isPinned = false,
    this.artworkNumber,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  /// ตามข้อ 1.3.2.2 แจ้งเตือนเมื่อใกล้ถึงเป้าหมาย (>= 90%)
  bool get isNearTarget => progress >= 0.9 && progress < 1.0;

  GoalModel copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? startDate,
    DateTime? targetDate,
    GoalStatus? status,
    IconData? icon,
    int? artworkNumber,
    String? note,
    bool? isPinned,
  }) {
    return GoalModel(
      id: id,
      currency: currency,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      artworkNumber: artworkNumber ?? this.artworkNumber,
      note: note ?? this.note,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'id': id,
      'currency': currency,
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'start_date': startDate.toIso8601String(),
      'target_date': targetDate.toIso8601String(),
      'status': status == GoalStatus.completed ? 'completed' : 'inProgress',
      'icon_code': icon.codePoint,
      'artwork_number': artworkNumber,
      'note': note,
      'is_pinned': isPinned,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      currency: map['currency'] as String?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      targetDate: DateTime.parse(map['target_date'] as String),
      status: map['status'] == 'completed' ? GoalStatus.completed : GoalStatus.inProgress,
      icon: persistedIconFromCodePoint(map['icon_code'] as int),
      note: map['note'] as String?,
      isPinned: map['is_pinned'] == true,
      artworkNumber: (map['artwork_number'] as num?)?.toInt(),
    );
  }
}
```

### 13.15 flutter_application_1/lib/models/persisted_icons.dart

รายการ IconData แบบ const ที่อนุญาตให้แปลง codePoint กลับเป็นไอคอนโดยมี fallback ช่วยรักษาไอคอนที่เคยบันทึกและรองรับ icon tree shaking

64 บรรทัด • SHA-256: e1cf1e951e80747c

```dart
import 'package:flutter/material.dart';

/// Icons persisted by categories and savings goals. Keep legacy entries when
/// changing the picker so existing records still render after an app update.
/// Constant references allow release builds to tree-shake the icon font.
const persistedIcons = <IconData>[
  Icons.apartment,
  Icons.camera_alt,
  Icons.card_giftcard,
  Icons.card_membership,
  Icons.category_outlined,
  Icons.checkroom,
  Icons.commute,
  Icons.copyright,
  Icons.currency_bitcoin,
  Icons.directions_car,
  Icons.edit_note,
  Icons.emoji_events,
  Icons.family_restroom,
  Icons.fitness_center,
  Icons.flight,
  Icons.handshake,
  Icons.health_and_safety,
  Icons.home,
  Icons.home_work,
  Icons.insights,
  Icons.lightbulb,
  Icons.local_cafe,
  Icons.local_gas_station,
  Icons.local_hospital,
  Icons.local_movies,
  Icons.local_parking,
  Icons.local_taxi,
  Icons.medication,
  Icons.music_note,
  Icons.payments,
  Icons.people_alt,
  Icons.pets,
  Icons.receipt_long,
  Icons.request_quote,
  Icons.restaurant,
  Icons.savings,
  Icons.school,
  Icons.sell,
  Icons.shopping_bag,
  Icons.shopping_cart,
  Icons.smartphone,
  Icons.spa,
  Icons.sports_esports,
  Icons.sports_soccer,
  Icons.star_rounded,
  Icons.storefront,
  Icons.subscriptions,
  Icons.support,
  Icons.trending_up,
  Icons.volunteer_activism,
  Icons.water_drop,
  Icons.wifi,
];

IconData persistedIconFromCodePoint(int codePoint) => persistedIcons.firstWhere(
      (icon) => icon.codePoint == codePoint,
      orElse: () => Icons.category_outlined,
    );
```

### 13.16 flutter_application_1/lib/models/transaction_model.dart

ข้อมูลรายการหนึ่งรายการ รวมหมวด วัน จำนวน หมายเหตุ สกุลเงิน และ marker รูปแนบ; copyWith รักษา id เดิม toMap ใช้ category_id แทนการเก็บ object หมวดทั้งก้อน

โครงสร้างที่ประกาศ: class TransactionModel (L4)

77 บรรทัด • SHA-256: 001485cab0ba610a

```dart
import 'category_model.dart';

/// เอนทิตี้ Transaction ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class TransactionModel {
  final String? currency;
  final String id; // transaction_id
  final CategoryType type; // type (รายรับ / รายจ่าย)
  final double amount; // amount
  final CategoryModel category; // category_id (FK)
  final DateTime date; // date
  final String? note; // note
  final String? description; // description
  final String? receiptPath; // Receipt.file_path (ถ้ามีการแนบสลิป)

  const TransactionModel({
    required this.id,
    this.currency,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.description,
    this.receiptPath,
  });

  TransactionModel copyWith({
    CategoryType? type,
    double? amount,
    CategoryModel? category,
    DateTime? date,
    String? note,
    String? description,
    String? receiptPath,
  }) {
    return TransactionModel(
      id: id,
      currency: currency,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      description: description ?? this.description,
      receiptPath: receiptPath ?? this.receiptPath,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'id': id,
      'currency': currency,
      'user_id': userId,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'amount': amount,
      'category_id': category.id,
      'date': date.toIso8601String(),
      'note': note,
      'description': description,
      'receipt_path': receiptPath,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, CategoryModel category) {
    return TransactionModel(
      id: map['id'] as String,
      currency: map['currency'] as String?,
      type: map['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      amount: (map['amount'] as num).toDouble(),
      category: category,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      description: map['description'] as String?,
      receiptPath: map['receipt_path'] as String?,
    );
  }
}
```

### 13.17 flutter_application_1/lib/models/user_model.dart

ข้อมูลโปรไฟล์ ไม่มีรหัสผ่าน แยก currency ที่เลือกกับ ledgerCurrency สำหรับรายการเดิม แปลง avatar_base64 และวันที่ระหว่าง Map กับ object

โครงสร้างที่ประกาศ: class UserModel (L5)

61 บรรทัด • SHA-256: ee3adda68b769e91

```dart
/// เอนทิตี้ User ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
/// หมายเหตุ: ไม่เก็บรหัสผ่านไว้ที่นี่/ใน Firestore อีกต่อไป เพราะการยืนยันตัวตน
/// (ล็อกอิน/สมัครสมาชิก/ลืมรหัสผ่าน) ถูกโอนไปให้ Firebase Authentication ดูแลทั้งหมด
/// id ของโมเดลนี้ = uid ที่ Firebase Authentication สร้างให้ผู้ใช้แต่ละคน
class UserModel {
  final String id; // user_id (= Firebase Auth uid)
  String name; // name
  String email; // email
  final DateTime createdAt; // created_at
  String language; // ตั้งค่าในหน้า Information / Account Setting
  String currency;
  // Stored financial amounts keep this unit; display currency can change safely.
  final String ledgerCurrency;

  /// รูปโปรไฟล์ เก็บเป็น Base64 string ลง Firestore โดยตรง (ไม่ใช้ Firebase Storage)
  ///
  /// เหตุผล: Firebase Storage บังคับต้องอัปเกรดเป็นแพ็กเกจ Blaze (ผูกบัตรเครดิต)
  /// ตั้งแต่เดือน 2024 เป็นต้นมา ส่วนโปรเจกต์นี้อยู่บนแผน Spark (ฟรี) จึงเลือกเก็บรูป
  /// เป็น Base64 string ไว้ในเอกสาร users/{uid} ของ Firestore แทน (ใช้แผนฟรีได้ปกติ)
  /// โดยจำกัดขนาดรูปให้เล็ก (ย่อ + บีบอัดตอนเลือกรูป) เพื่อไม่ให้เกิน 1 MiB ต่อ
  /// เอกสารที่ Firestore กำหนดไว้ — ยังคง "ตามบัญชีไปทุกเครื่อง" เหมือนข้อมูลอื่นๆ
  /// เพราะอยู่ใน Firestore document เดียวกับโปรไฟล์ผู้ใช้
  String? avatarBase64;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.language = 'ไทย',
    this.currency = 'THB',
    this.avatarBase64,
    String? ledgerCurrency,
  }) : ledgerCurrency = ledgerCurrency ?? currency;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'language': language,
      'currency': currency,
      'ledger_currency': ledgerCurrency,
      'avatar_base64': avatarBase64,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      language: map['language'] as String? ?? 'ไทย',
      currency: map['currency'] as String? ?? 'THB',
      ledgerCurrency: map['ledger_currency'] as String? ?? map['currency'] as String? ?? 'THB',
      avatarBase64: map['avatar_base64'] as String?,
    );
  }
}
```

### 13.18 flutter_application_1/lib/screens/Forgot password screen.dart

รับอีเมลแล้วเรียก resetPassword แสดงผลส่งลิงก์หรือ error; ผู้ใช้กำหนดรหัสใหม่ที่ลิงก์เว็บ ไม่ได้เปลี่ยนรหัสในฟอร์มนี้

โครงสร้างที่ประกาศ: class ForgotPasswordScreen extends StatefulWidget (L9); class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> (L16)

232 บรรทัด • SHA-256: 4481c65924ceb54e

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

/// หน้า Forgot Password - รีเซ็ตรหัสผ่านผ่าน Firebase Authentication
/// (ผู้ใช้กรอกแค่อีเมล ระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้ทางอีเมลโดยตรง
/// จึงไม่ต้องกรอกรหัสผ่านใหม่ในแอปอีกต่อไป)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  String? _error;
  String? _success;
  bool _loading = false;

  Future<void> _handleReset() async {
    if (_loading) return;
    final service = context.read<DataService>();

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = service.t('enter_email');
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    // ส่งลิงก์รีเซ็ตรหัสผ่านผ่าน Firebase Authentication (sendPasswordResetEmail)
    final error = await service.resetPassword(email);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _success = service.t('reset_email_sent');
      });
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('forgot_password_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: Stack(
        children: [
          // ก้อนสีพาสเทลลอยด้านหลัง เพิ่มความน่ารักให้พื้นหลัง
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.16),
                      blurRadius: 88,
                      spreadRadius: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.15),
                      blurRadius: 99,
                      spreadRadius: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // ไอคอนหัวข้อพร้อมแสงเรืองสีพาสเทลด้านหลัง
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.accentDeep.withOpacity(0.20),
                                  AppColors.accentDeep.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          const HeaderIconBadge(icon: Icons.lock_reset_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('reset_password_heading'),
                        textAlign: TextAlign.center, style: AppTextStyles.title),
                    const SizedBox(height: 8),
                    Text(
                      service.t('reset_password_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // การ์ดฟอร์มโค้งมนลอยตัว ให้ความรู้สึกนุ่มนวลอบอุ่นกว่าเดิม
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md + 8),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel(service.t('email')),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: 'you@example.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_error != null || _success != null) {
                                setState(() {
                                  _error = null;
                                  _success = null;
                                });
                              }
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            MessageBanner(text: _error!),
                          ],
                          if (_success != null) ...[
                            const SizedBox(height: 14),
                            MessageBanner(text: _success!, isError: false),
                          ],
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: service.t('reset_password_heading'),
                            loading: _loading,
                            onPressed: _handleReset,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: Text(service.t('back_to_login'),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
      );
}
```

### 13.19 flutter_application_1/lib/screens/Splash screen.dart

หน้า splash อีกชุดในโปรเจกต์ รอแล้วไป Login; main ปัจจุบันเลือก LoadingScreen จึงไม่ควรอธิบายว่า SplashScreen เป็นจุดเริ่มจริง

โครงสร้างที่ประกาศ: class SplashScreen extends StatefulWidget (L6); class _SplashScreenState extends State<SplashScreen> (L13)

68 บรรทัด • SHA-256: 936e44b96c01b85f

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // TODO: ปรับ path ให้ตรงกับโปรเจกต์จริง

/// หน้า Splash - โชว์ระหว่างแอปเริ่มโหลด (เช็ค session / เตรียมข้อมูลเริ่มต้น)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      noAnimationRoute(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/loading.gif',
                  width: 76,
                  height: 76,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'BUDGETMATE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text('จัดการเงินของคุณให้เป็นเรื่องง่าย',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
```

### 13.20 flutter_application_1/lib/screens/account_setting_screen.dart

จัดการชื่อ ภาษา รูปโปรไฟล์ ธีม การแจ้งสำเร็จ และ logout พร้อมเปิดหน้ารหัสผ่าน _AvatarPicker อ่านรูป Base64 หรือแคช และเรียก pickAvatar/removeAvatar

โครงสร้างที่ประกาศ: class AccountSettingScreen extends StatelessWidget (L23); class _CuteMenuHeader extends StatelessWidget (L429); class _ProfileCard extends StatelessWidget (L501); class _AvatarPicker extends StatelessWidget (L579)

713 บรรทัด • SHA-256: e2006a2e4c809128

```dart
import '../widgets/data_action.dart';
import 'dart:convert';
import 'dart:io';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

const List<String> _languageOptions = ['ไทย', 'English'];


const List<Color> _menuTintIcon = [
  Color(0xFF80A1D4),
  Color(0xFFC08B9D),
  Color(0xFFC79A3B),
  Color(0xFF3D568F),
];


class AccountSettingScreen extends StatelessWidget {
  const AccountSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final user = service.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CuteMenuHeader(title: service.t('account_setting_title')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(service: service, user: user),
                  const SizedBox(height: 18),
                  _sectionLabel(service.t('account_section'), Icons.favorite_rounded, AppColors.accentPink),
                  _settingsGroup([
                  _tile(context, service.t('manage_profile'),
                      icon: Icons.badge_outlined,
                      tintIndex: 0,
                      onTap: () => _editNameDialog(context, service)),
                  _tile(context, service.t('password_security'),
                      icon: Icons.lock_outline_rounded,
                      tintIndex: 1,
                      onTap: () => Navigator.push(
                          context, noAnimationRoute(const ChangePasswordScreen()))),
                  _tile(context, service.t('language'),
                      icon: Icons.language_rounded,
                      tintIndex: 2,
                      trailing: user?.language ?? 'ไทย',
                      onTap: () => _languageDialog(context, service)),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel(service.t('preferences_section'), Icons.auto_awesome_rounded, AppColors.accentDeep),
                  _settingsGroup([
                  _tile(context, service.t('about_us'),
                      icon: Icons.info_outline_rounded,
                      tintIndex: 3,
                      onTap: () => _aboutDialog(context, service)),
                  _switchTile(
                    title: service.t('theme'),
                    icon: Icons.dark_mode_outlined,
                    tintIndex: 0,
                    subtitle: service.themeMode == ThemeMode.dark ? service.t('theme_dark') : service.t('theme_light'),
                    value: service.themeMode == ThemeMode.dark,
                    onChanged: (_) => service.toggleTheme(),
                  ),
                  _switchTile(
                    title: service.t('success_notes'),
                    icon: Icons.notifications_outlined,
                    tintIndex: 1,
                    subtitle: service.successNotesEnabled ? service.t('enabled') : service.t('disabled'),
                    value: service.successNotesEnabled,
                    onChanged: (_) => service.toggleSuccessNotes(),
                  ),
                  ]),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        backgroundColor: AppColors.dangerBg.withOpacity(0.5),
                        side: BorderSide(color: AppColors.danger.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                      onPressed: () async {
                        await service.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                            context,
                            noAnimationRoute(const LoginScreen()),
                            (route) => false);
                      },
                      icon: const Icon(Icons.waving_hand_rounded, size: 18),
                      label: Text(service.t('logout'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: AppTextStyles.heading)),
          ],
        ),
      );

  Widget _settingsGroup(List<Widget> children) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Divider(height: 1, indent: 44, color: AppColors.border),
        children[i],
      ],
    ]),
  );

  Widget _tile(BuildContext context, String title,
      {IconData? icon, String? trailing, VoidCallback? onTap, int tintIndex = 0}) =>
    ListTile(
      onTap: onTap,
      dense: false,
      minTileHeight: 58,
      minLeadingWidth: 26,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: icon == null ? null : Icon(icon, size: 24,
        color: _menuTintIcon[tintIndex % _menuTintIcon.length]),
      title: Text(title, style: TextStyle(fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) Text(trailing,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ]),
    );

  Widget _switchTile({required String title, required IconData icon,
    required String subtitle, required bool value,
    required ValueChanged<bool> onChanged, int tintIndex = 0}) =>
    ListTile(
      dense: false,
      minTileHeight: 58,
      minLeadingWidth: 26,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 24,
        color: _menuTintIcon[tintIndex % _menuTintIcon.length]),
      title: Text(title, style: TextStyle(fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: Semantics(label: subtitle, child: SizedBox(width: 48, height: 48,
        child: FittedBox(child: Switch(
          value: value, activeColor: AppColors.ink, onChanged: onChanged,
        )))),
    );

  void _editNameDialog(BuildContext context, DataService service) {
    final ctrl = TextEditingController(text: service.currentUser?.name);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        bool saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                setState(() => errorText = service.t('enter_username'));
                return;
              }
              setState(() {
                saving = true;
                errorText = null;
              });
              try {
                await service.updateProfile(name: name);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) setState(() {
                  saving = false;
                  errorText = '${service.t('save_failed')}: $e';
                });
              }
            }

            return Dialog(
              backgroundColor: AppColors.bg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.accentBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.badge_outlined, color: AppColors.ink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(service.t('edit_username'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(service.t('display_name'),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: ctrl,
                      hint: service.t('username_hint'),
                      icon: Icons.person_outline_rounded,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) setState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : () => Navigator.pop(dialogContext),
                            child: Text(service.t('cancel'),
                                style:
                                    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : save,
                            child: saving
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.inkOn))
                                : Text(service.t('save_action'), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkOn)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _languageDialog(BuildContext context, DataService service) {
    // แสดงธงไทยสำหรับภาษาไทย และธงสหรัฐฯ สำหรับ English
    Widget flagFor(String lang) => Text(
        lang == 'ไทย' ? '🇹🇭' : '🇺🇸',
        style: const TextStyle(fontSize: 23));

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.language_rounded, color: AppColors.ink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(service.t('choose_language'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._languageOptions.map((lang) {
                  final selected = (service.currentUser?.language ?? 'ไทย') == lang;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected ? AppColors.accentBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () async {
                          await runDataAction(context, () async { await service.setLanguage(lang); });
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected ? AppColors.ink : AppColors.border,
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              flagFor(lang),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(lang,
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                        color: selected ? AppColors.ink : AppColors.textPrimary)),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.ink, size: 20)
                              else
                                Icon(Icons.circle_outlined,
                                    color: AppColors.border, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _aboutDialog(BuildContext context, DataService service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(service.t('about_title'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          service.t('about_body'),
          style: TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: Text(service.t('close'))),
        ],
      ),
    );
  }
}

/// หัวข้อพาสเทลไล่เฉดโค้งมนด้านล่าง พร้อมประกายดาวตกแต่ง — ใช้โทนเดียวกับ
/// _SkyHeader ในหน้า Home เพื่อให้หน้าเมนูดูเข้าชุดกับส่วนอื่นของแอปและน่ารักขึ้น
class _CuteMenuHeader extends StatelessWidget {
  final String title;
  const _CuteMenuHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // บวก MediaQuery.of(context).padding.top (ความสูง status bar / notch) เข้าไปกับ
    // padding บนของ header เสมอ (เหมือน _SkyHeader ในหน้า Home) เพราะหน้านี้ใช้
    // extendBodyBehindAppBar: true ทำให้เนื้อหาเลื่อนขึ้นไปอยู่ใต้ status bar/เกาะกล้อง
    // ถ้าไม่บวกส่วนนี้ ข้อความหัวข้อ "ตั้งค่าบัญชี" จะไปชนซ้อนกับนาฬิกา/แบตเตอรี่บนจอ
    final topSafeArea = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topSafeArea + 8, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentDeep.withOpacity(0.9), AppColors.accent, AppColors.bg],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 60,
            top: topSafeArea,
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white.withOpacity(0.85)),
          ),
          Positioned(
            right: 86,
            top: topSafeArea + 20,
            child: Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white.withOpacity(0.6)),
          ),
          Positioned(
            left: 8,
            top: topSafeArea + 10,
            child: Icon(Icons.favorite_rounded, size: 12, color: Colors.white.withOpacity(0.55)),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.settings_suggest_rounded, color: AppColors.accentDeep, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF3D568F)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// การ์ดโปรไฟล์พาสเทลพร้อมฟองสบู่ตกแต่งมุม — ให้ความรู้สึกนุ่มนวลน่ารักเหมือนขนม
/// เช่นเดียวกับการ์ดรายรับ/รายจ่ายในหน้า Wallet
class _ProfileCard extends StatelessWidget {
  final DataService service;
  final dynamic user;
  const _ProfileCard({required this.service, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.accentPink.withOpacity(0.18), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 34,
              bottom: -18,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: AppColors.accentDeep.withOpacity(0.12), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _AvatarPicker(service: service),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '-',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '-',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รูปโปรไฟล์ที่แตะเพื่อเปลี่ยนได้ (ถ่ายรูปใหม่ / เลือกจากคลังภาพ / ลบรูป)
///
/// อัปเดต: ลอง decode รูปจาก `service.currentUser.avatarBase64` (Base64 string
/// ที่เก็บอยู่ใน Firestore) ก่อนเป็นอันดับแรก เพราะเป็นแหล่งข้อมูลจริงที่ผูกกับบัญชี
/// และตามไปทุกเครื่องที่ล็อกอิน ถ้ายังไม่มีจะ fallback ไปที่ไฟล์แคชในเครื่อง
/// (avatarPath) แล้วค่อย fallback สุดท้ายเป็นไอคอนคน default — เดิมโค้ดจุดนี้ดูแค่
/// avatarPath (ไฟล์ในเครื่อง) อย่างเดียว ทำให้เปลี่ยนมือถือเครื่องใหม่แล้วเห็นแต่
/// ไอคอน default เสมอแม้จะเคยตั้งรูปโปรไฟล์ไว้แล้วก็ตาม
class _AvatarPicker extends StatelessWidget {
  final DataService service;
  const _AvatarPicker({required this.service});

  @override
  Widget build(BuildContext context) {
    final avatarBase64 = service.currentUser?.avatarBase64;
    final path = service.avatarPath;
    final hasLocalImage = path != null && File(path).existsSync();

    ImageProvider? avatarImage;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarBase64));
      } catch (_) {
        avatarImage = null;
      }
    }
    if (avatarImage == null && hasLocalImage) {
      avatarImage = FileImage(File(path));
    }

    return GestureDetector(
      onTap: () => _showPickerSheet(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.accentDeep, AppColors.accentPink],
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.bg,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.accentBg,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(Icons.person, size: 30, color: AppColors.ink)
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.accentDeep,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        final hasImage = service.avatarPath != null || service.currentUser?.avatarBase64 != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.accentBg, shape: BoxShape.circle),
                    child: Icon(Icons.photo_camera_outlined, color: AppColors.accentDeep, size: 18),
                  ),
                  title: Text(service.t('take_photo'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await runDataAction(context, () async { await service.pickAvatar(fromCamera: true); });
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.accentAltBg, shape: BoxShape.circle),
                    child: Icon(Icons.photo_library_outlined, color: const Color(0xFFC79A3B), size: 18),
                  ),
                  title: Text(service.t('choose_from_gallery'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await runDataAction(context, () async { await service.pickAvatar(fromCamera: false); });
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                      child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                    ),
                    title: Text(service.t('remove_photo'), style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await runDataAction(context, () async { await service.removeAvatar(); });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### 13.21 flutter_application_1/lib/screens/add_goal_saving_screen.dart

ใช้ฟอร์มเดียวสร้างหรือแก้เป้าหมาย รับชื่อ จำนวน วันเป้าหมาย โน้ต และ artwork; ถ้าส่ง goal มาเรียก editGoal ไม่เช่นนั้น addGoal มี keypad ร่วม

โครงสร้างที่ประกาศ: class AddGoalSavingScreen extends StatefulWidget (L31); class _AddGoalSavingScreenState extends State<AddGoalSavingScreen> (L39); class _BlinkingCursor extends StatefulWidget (L666); class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin (L675)

707 บรรทัด • SHA-256: bb43a9296966299b

```dart
import '../widgets/success_notice.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/category_artwork_catalog.dart';
import '../widgets/amount_keypad.dart';
import '../models/goal_model.dart';
import '../models/category_model.dart';
import '../widgets/pastel_artwork.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;


const List<IconData> _goalIcons = [
  Icons.restaurant, Icons.local_cafe, Icons.home, Icons.directions_car,
  Icons.receipt_long, Icons.shopping_bag, Icons.card_giftcard,
  Icons.flight, Icons.spa, Icons.music_note, Icons.sports_soccer,
  Icons.pets, Icons.school,
];

// ชุดสีพาสเทลของไอคอนเป้าหมาย (โทนเดียวกับหน้า Add Income/Expense)
const List<Color> _goalTintIcon = [
  Color(0xFF6FA3D6), Color(0xFFD9789B), Color(0xFFC79A3B), Color(0xFF8C79C9),
  Color(0xFF54A57E), Color(0xFFDB8A55), Color(0xFF4FA79C), Color(0xFFB1699F),
];

/// หน้า Add Goal Saving (3.4.12) - เพิ่มเป้าหมายการออมเงินใหม่ลง SQLite
/// ปรับดีไซน์ให้นุ่มนวล มีมิติ และเพิ่มช่องหมายเหตุ (optional) ให้เหมือนหน้า Add Income/Expense
class AddGoalSavingScreen extends StatefulWidget {
  const AddGoalSavingScreen({super.key, this.goal});
  final GoalModel? goal;

  @override
  State<AddGoalSavingScreen> createState() => _AddGoalSavingScreenState();
}

class _AddGoalSavingScreenState extends State<AddGoalSavingScreen> {
  // ความสูงคงที่ของแผงปุ่มตัวเลขที่จะเลื่อนขึ้นมาจากด้านล่าง
  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
  static const double _numpadHeight = AmountKeypad.height + 18;
  static const Duration _numpadAnim = Duration(milliseconds: 260);

  IconData _selectedIcon = _goalIcons.first;
  int? _artworkNumber;
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountController = TextEditingController();
  String get _amountText => _amountController.text;
  set _amountText(String value) {
    _amountController.value = TextEditingValue(
      text: value, selection: TextSelection.collapsed(offset: value.length));
  }
  DateTime _targetDate = DateTime.now().add(const Duration(days: 180));
  bool _saving = false;

  // true เมื่อผู้ใช้กำลังจะพิมพ์จำนวนเงิน -> โชว์แป้นตัวเลข + เคอร์เซอร์กระพริบ
  bool _showNumpad = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_amountChanged);
    final goal = widget.goal;
    if (goal != null) {
      _artworkNumber = goal.artworkNumber;
      _nameCtrl.text = goal.name;
      _noteCtrl.text = goal.note ?? '';
      _amountText = goal.targetAmount.toString();
      _targetDate = goal.targetDate;
      _selectedIcon = _goalIcons.firstWhere((icon) => icon.codePoint == goal.icon.codePoint, orElse: () => goal.icon);
    }
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _openNumpad() {
    // เอา focus ออกจากช่องชื่อเป้าหมาย/หมายเหตุ
    FocusScope.of(context).unfocus();

    // ซ่อน keyboard ของมือถือ
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();

    setState(() {
      _showNumpad = true;
    });
  }

  void _closeNumpad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    if (_showNumpad) {
      setState(() {
        _showNumpad = false;
      });
    }
  }

  void _finishAmountInput() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.lightImpact();

    setState(() {
      _showNumpad = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountText) ?? 0;
    final service = context.read<DataService>();
    if (_nameCtrl.text.trim().isEmpty || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('fill_name_and_amount'))));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final error = widget.goal != null
        ? await service.editGoal(widget.goal!.id, name: _nameCtrl.text.trim(),
            targetAmount: amount, targetDate: _targetDate, icon: _selectedIcon, artworkNumber: _artworkNumber,
            note: _noteCtrl.text.trim())
        : await service.addGoal(
          name: _nameCtrl.text,
          targetAmount: amount,
          targetDate: _targetDate,
          icon: _selectedIcon, artworkNumber: _artworkNumber,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        );

    if (!mounted) return;

    if (error == null) {
      showSuccessNotice(context, widget.goal == null ? 'goal_saved' : 'goal_updated');
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;
    final compactPhone = MediaQuery.sizeOf(context).width <= 360 || MediaQuery.sizeOf(context).height <= 667;
    final compactSectionGap = compactPhone ? 8.0 : 12.0;
    // Include the translated "other" label at the actual system font size.
    final labelPainter = TextPainter(
      text: TextSpan(text: service.t('other_category'),
        style: const TextStyle(fontFamily: appFontFamily, fontSize: 11, height: 1.4)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (MediaQuery.sizeOf(context).width - 24 -
        (compactPhone ? 8 : 12)) / (compactPhone ? 3 : 4));
    final compactGridHeight = (compactPhone ? 30.0 : (_showNumpad ? 36.0 : 44.0)) +
        4 + labelPainter.height + 4;
    labelPainter.dispose();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t(widget.goal == null ? 'goal_saving' : 'edit_goal'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(child: _saveButton(service)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ----- เนื้อหาหลักของหน้า -----
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              final scrollAll = MediaQuery.viewInsetsOf(context).bottom > 0 ||
                  constraints.maxHeight < (_showNumpad ? 650 : 360);
              final form = Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: scrollAll ? 0 : 1,
                    fit: FlexFit.tight,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ----- 1. ชื่อเป้าหมาย -----
                          AppTextField(
                            controller: _nameCtrl,
                            hint: service.t('goal_name_hint'),
                            icon: Icons.flag_outlined,
                          ),
                          SizedBox(height: compactPhone ? 8 : 16),
                          // ----- 2. หมวดหมู่ (เลือกไอคอนเป้าหมาย) -----
                          Text(service.t('categories'), style: AppTextStyles.heading),
                          SizedBox(height: compactPhone ? 6 : 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: compactPhone ? 3 : 4,
                              mainAxisSpacing: compactPhone ? 6 : 8,
                              crossAxisSpacing: compactPhone ? 4 : 4,
                              mainAxisExtent: compactGridHeight,
                            ),
                            itemCount: _goalIcons.length + 1,
                            itemBuilder: (context, index) => index == _goalIcons.length
                              ? _otherArtworkTile(service) : _goalCategoryTile(
                              defaultCategories[index], service, index),
                          ),
                          SizedBox(height: compactPhone ? 10 : 16),
                          // ----- 3. วันที่เป้าหมาย -----
                          _dateCard(service),
                          SizedBox(height: compactSectionGap),
                        ],
                      ),
                    ),
                  ),
                  // ----- 4. ช่องหมายเหตุ (ไม่บังคับ) -----
                  // ย้ายออกจากพื้นที่ scroll มาไว้ในโซนคงที่ด้านล่าง ให้ติดกันพอดี
                  // กับกล่อง "กรุณากรอกจำนวนเงิน" ด้านล่าง (ไม่มีช่องว่างมาคั่น)
                  // และจะเลื่อนขึ้น/ซ่อนตอนแป้นตัวเลขเปิดอยู่ กันไม่ให้แป้นบัง
                  ClipRect(
                    child: AnimatedAlign(
                      duration: _numpadAnim,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      heightFactor: _showNumpad ? 0 : 1,
                      child: AnimatedOpacity(
                        duration: _numpadAnim,
                        opacity: _showNumpad ? 0 : 1,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: compactPhone ? 4 : 8),
                          child: AppTextField(
                            controller: _noteCtrl,
                            hint: service.t('note_optional'),
                            icon: Icons.edit_note_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // แถบจำนวนเงิน: แตะเพื่อเปิดแป้นตัวเลข พร้อมเคอร์เซอร์กระพริบระหว่างพิมพ์
                  // (ดีไซน์เดียวกับหน้า Add Income/Expense)
                  _amountDisplay(),
                  // จองพื้นที่ด้านล่างเท่ากับความสูงแป้นตัวเลข เมื่อแป้นถูกเปิดอยู่
                  AnimatedContainer(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    height: _showNumpad ? (scrollAll ? 0 : panelHeight) : (compactPhone ? bottomInset + 4 : bottomInset + 8),
                  ),
                ],
              ),
            );
              return scrollAll ? Padding(
                padding: EdgeInsets.only(bottom: _showNumpad ? panelHeight : 0),
                child: SingleChildScrollView(reverse: _showNumpad, child: form),
              ) : form;
            }),
          ),

          // ----- แผงปุ่มตัวเลข เลื่อนขึ้นจากด้านล่าง เฉพาะตอนต้องการพิมพ์จำนวนเงิน -----
          AnimatedPositioned(
            duration: _numpadAnim,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showNumpad ? 0 : -panelHeight,
            child: _numpadPanel(bottomInset),
          ),
        ],
      ),
    );
  }

  // ---------- ปุ่มบันทึกบน AppBar ----------
  Widget _saveButton(DataService service) {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentPink, AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPink.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _saving
            ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(service.t('save'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _otherArtworkTile(DataService service) {
    final selected = _artworkNumber != null && _artworkNumber! > 13;
    final compactPhone = MediaQuery.sizeOf(context).width <= 360 || MediaQuery.sizeOf(context).height <= 667;
    final tileSize = compactPhone ? 30.0 : (_showNumpad ? 36.0 : 44.0);
    final iconSize = compactPhone ? 20.0 : 25.0;
    return InkWell(
      key: const Key('goal-other-artwork'),
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        _closeNumpad();
        final choice = await showCategoryArtworkPicker(context,
          service: service, selected: _artworkNumber ?? _goalIcons.indexOf(_selectedIcon) + 1);
        if (!mounted || choice == null) return;
        setState(() {
          _artworkNumber = artworkNumberOf(choice);
          _selectedIcon = choice.icon;
        });
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: tileSize, height: tileSize,
          decoration: BoxDecoration(color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.accentPink : AppColors.border,
              width: selected ? 2 : 1)),
          child: selected
            ? PastelArtwork(categoryNumber: _artworkNumber!, size: compactPhone ? 26 : (_showNumpad ? 40 : 56))
            : Icon(Icons.add_rounded, color: AppColors.ink, size: iconSize)),
        const SizedBox(height: 4),
        Text(service.t('other_category'), style: TextStyle(fontFamily: appFontFamily, fontSize: 11, height: 1.4, color: AppColors.ink)),
      ]),
    );
  }

  // ---------- การ์ดเลือกวันที่เป้าหมาย ----------
  Widget _goalCategoryTile(CategoryModel c, DataService service, int index) {
    final compactPhone = MediaQuery.sizeOf(context).width <= 360 || MediaQuery.sizeOf(context).height <= 667;
    final selected = _artworkNumber == null
        ? _selectedIcon.codePoint == c.icon.codePoint
        : _artworkNumber == index + 1;
    final tintIcon = _goalTintIcon[index % _goalTintIcon.length];
    final pastel = [AppColors.accentBg, AppColors.accentAltBg,
      const Color(0xFFEAE5FA), const Color(0xFFE1F2EC)][index % 4];
    final tileSize = compactPhone ? 30.0 : (_showNumpad ? 36.0 : 44.0);
    final iconSize = compactPhone ? 20.0 : (_showNumpad ? 30.0 : 36.0);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        HapticFeedback.selectionClick();
        setState(() {
          _selectedIcon = c.icon;
          _artworkNumber = index + 1;

        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // เพิ่มเอฟเฟกต์ "เด้งเล็กน้อย" ตอนถูกเลือก ให้ดูมีชีวิตชีวาน่ารักขึ้น
          AnimatedScale(
            scale: selected ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOut,
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_showNumpad ? 15 : 20),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.surfaceAlt, Color.lerp(AppColors.card, pastel, 0.7)!],
              ),
              border: Border.all(
                color: selected ? AppColors.accentPink : Color.lerp(AppColors.border, pastel, 0.6)!,
                width: selected ? 2 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? AppColors.accentPink.withOpacity(0.23)
                      : AppColors.accentDeep.withOpacity(0.09),
                  blurRadius: selected ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // ไอคอนขยายใหญ่ขึ้นให้ใช้พื้นที่ ~85% ของกล่อง (เหลือ margin ~8-12%)
            // ใช้ fill+zoom เพื่อ "ตัด" พื้นที่โปร่งใส/ขอบว่างรอบไฟล์ไอคอนต้นฉบับออกไปก่อน
            // แล้วจึงขยาย artwork จริงให้เต็มกรอบมากขึ้น โดยไม่ยืด/บิดสัดส่วน และไม่ทำให้กรอบ
            // (คอนเทนเนอร์ 60x60 ด้านนอก) ขยายขนาดตามไปด้วย
            child: Center(
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.86, 0.08, 0.06, 0, 5,
                    0.04, 0.91, 0.05, 0, 3,
                    0.04, 0.09, 0.87, 0, 7,
                    0, 0, 0, 1, 0,
                  ]),
                  child: CategoryIcon(
                  category: c,
                  color: selected ? AppColors.accentDeep : tintIcon,
                  size: iconSize,
                  fill: true,
                  zoom: compactPhone ? 1.0 : 1.12,
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard(DataService service) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            _closeNumpad();
            final isThai = service.currentLanguage != 'English';
            final picked = await showDialog<DateTime>(
              context: context,
              barrierColor: Colors.black.withOpacity(0.45),
              builder: (_) => PastelCalendarDialog(
                initialDate: _targetDate,
                firstDate: widget.goal == null ? DateTime.now() : DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                isThai: isThai,
              ),
            );
            if (picked != null) setState(() => _targetDate = picked);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_rounded, color: AppColors.accentDeep, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.t('target_date_label'),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // กล่องแสดง/กรอกจำนวนเงิน: มีกรอบสีเดียวกับช่องอื่นๆ, มีลายน้ำตอนยังไม่กรอก,
  // และเคอร์เซอร์กระพริบอยู่ "หน้า" สัญลักษณ์ ฿ ระหว่างที่กำลังพิมพ์
  Widget _amountDisplay() {
    final service = context.read<DataService>();
    final showPlaceholder = !_showNumpad && _amountText.isEmpty;

    return TapRegion(
      groupId: 'goal-amount',
      onTapOutside: (_) => _closeNumpad(),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openNumpad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _showNumpad ? AppColors.accentDeep : AppColors.border,
            width: _showNumpad ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_showNumpad ? AppColors.accentDeep : Colors.black)
                  .withOpacity(_showNumpad ? 0.16 : 0.04),
              blurRadius: _showNumpad ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: showPlaceholder
            ? Row(
                children: [
                  Icon(Icons.savings_outlined, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.t('enter_valid_amount'),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _amountText,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      if (_showNumpad) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(color: AppColors.accentDeep, height: 24),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        context.watch<DataService>().currencySymbol,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ],
                  ))),
                  if (_showNumpad) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _finishAmountInput,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentDeep.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 23),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ));
  }

  // แผงปุ่มตัวเลขทั้งชุด (ความสูงคงที่ ลอยขึ้นมาจากขอบล่างจอ)
  Widget _numpadPanel(double bottomInset) {
    return TapRegion(
      groupId: 'goal-amount',
      child: Material(
      color: AppColors.bg,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: _numpadHeight + bottomInset,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // แถบจับเล็กๆ ด้านบน ให้ดูเหมือนแผ่นเลื่อนขึ้นมา (bottom sheet)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _numPad()),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    ));
  }

  Widget _numPad() => AmountKeypad(
    controller: _amountController,
  );
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
```

### 13.22 flutter_application_1/lib/screens/add_income_expense_screen.dart

ฟอร์มเลือกประเภท หมวด จำนวน และโน้ต มี keypad และรายการรอบันทึกหลายรายการ รองรับแก้รายการชั่วคราว ค้นหมวด สร้างหมวด และเปิดสแกนก่อนบันทึกจริง

โครงสร้างที่ประกาศ: class AddIncomeExpenseScreen extends StatefulWidget (L24); class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> (L32); class _BlinkingCursor extends StatefulWidget (L1219); class _BlinkingCursorState extends State<_BlinkingCursor> (L1228)

1,261 บรรทัด • SHA-256: e5f70d9cb39232ff

```dart
import '../widgets/success_notice.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/amount_keypad.dart';
import 'receipt_scan_screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'income_expense_screen.dart';

/// หน้า Add Income/Expense (3.4.10) — ปรับดีไซน์ให้ดูนุ่มนวล มีมิติ และน่ารักขึ้น
/// (โทนพาสเทลเดิม, ฟังก์ชันเดิมทั้งหมดไม่เปลี่ยนแปลง)
///
/// อัปเดต: `_save()` ปรับให้รองรับ `DataService.addTransaction()` เวอร์ชันใหม่
/// ที่คืนค่า `Future<String?>` (null = บันทึกสำเร็จ, มีข้อความ = บันทึกไม่สำเร็จ)
/// แทนที่จะปล่อยให้ exception หลุดออกมาอย่างเดียวเหมือนเดิม — ถ้ารายการไหนบันทึก
/// ไม่สำเร็จระหว่างลูป จะหยุดทันที ลบเฉพาะรายการที่บันทึกสำเร็จไปแล้วออกจากลิสต์
/// "รอบันทึก" (กันกดซ้ำซ้อน) ส่วนรายการที่เหลือ (รวมตัวที่ error) จะยังอยู่ให้กด
/// บันทึกใหม่ได้อีกครั้งโดยไม่ต้องกรอกซ้ำ
class AddIncomeExpenseScreen extends StatefulWidget {
  const AddIncomeExpenseScreen({super.key, this.initialType = CategoryType.expense});
  final CategoryType initialType;

  @override
  State<AddIncomeExpenseScreen> createState() => _AddIncomeExpenseScreenState();
}

class _AddIncomeExpenseScreenState extends State<AddIncomeExpenseScreen> {
  static const double _numpadHeight = AmountKeypad.height + 18;
  static const Duration _numpadAnim = Duration(milliseconds: 260);
  // ใช้ผูก _amountDisplay() กับ _numpadPanel() เป็นภูมิภาคเดียวกันสำหรับ TapRegion
  // เพื่อตรวจจับ "แตะข้างนอก" แล้วปิดแป้นตัวเลข โดยไม่บล็อกการเลื่อนจอ
  static const String _numpadGroupId = 'amount_numpad_group';

  CategoryType _type = CategoryType.income;
  CategoryModel? _selectedCategory;
  final _amountController = TextEditingController();
  String get _amountText => _amountController.text;
  set _amountText(String value) {
    _amountController.value = TextEditingValue(
      text: value, selection: TextSelection.collapsed(offset: value.length));
  }
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _showNumpad = false;
  String _categoryQuery = '';

  String? _editingId;
  List<Map<String, dynamic>> _tempTransactions = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _amountController.addListener(_amountChanged);
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _noteCtrl.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _openNumpad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();
    setState(() {
      _showNumpad = true;
    });
  }

  void _closeNumpad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (_showNumpad) {
      setState(() {
        _showNumpad = false;
      });
    }
  }

  void _finishAmountInput() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.lightImpact();
    setState(() {
      _showNumpad = false;
    });
  }

  String _formatAmount(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _addOrUpdate() {
    final amount = double.tryParse(_amountText) ?? 0;

    final service = context.read<DataService>();
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('enter_amount'))));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('select_category'))));
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      if (_editingId != null) {
        final index = _tempTransactions.indexWhere((t) => t['id'] == _editingId);
        if (index != -1) {
          _tempTransactions[index] = {
            'amount': amount,
            'category': _selectedCategory!,
            'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
            'id': _editingId,
          };
        }
        _editingId = null;
      } else {
        _tempTransactions.add({
          'amount': amount,
          'category': _selectedCategory!,
          'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      _amountText = '';
      _noteCtrl.clear();
      _selectedCategory = null;
      _showNumpad = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startEdit(Map<String, dynamic> tx) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();

    setState(() {
      _editingId = tx['id'] as String;
      _selectedCategory = tx['category'] as CategoryModel;
      _type = _selectedCategory!.type;
      _amountText = _formatAmount(tx['amount'] as double);
      _noteCtrl.text = (tx['note'] as String?) ?? '';
      _showNumpad = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _selectedCategory = null;
      _amountText = '';
      _noteCtrl.clear();
      _showNumpad = false;
    });
  }

  void _removeTransaction(String id) {
    final index = _tempTransactions.indexWhere((t) => t['id'] == id);
    if (index == -1) return;
    final removed = _tempTransactions[index];

    HapticFeedback.lightImpact();
    setState(() {
      _tempTransactions.removeAt(index);
      if (_editingId == id) {
        _editingId = null;
        _selectedCategory = null;
        _amountText = '';
        _noteCtrl.clear();
        _showNumpad = false;
      }
    });

    // เผื่อลบผิดพลาด (เช่นปัดทิ้งพลาด) ให้กด "เลิกทำ" เพื่อดึงรายการกลับมาได้
    if (!mounted) return;
    final isThai = context.read<DataService>().currentLanguage != 'English';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isThai ? 'ลบรายการแล้ว' : 'Item removed'),
        action: SnackBarAction(
          label: isThai ? 'เลิกทำ' : 'Undo',
          onPressed: () {
            setState(() {
              final insertAt = index <= _tempTransactions.length ? index : _tempTransactions.length;
              _tempTransactions.insert(insertAt, removed);
            });
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// บันทึกทุกรายการใน "ลิสต์รอบันทึก" (_tempTransactions) ลง Firestore จริงทีละรายการ
  /// ผ่าน service.addTransaction() ซึ่งตอนนี้คืนค่า Future<String?>:
  ///   - null    = บันทึกรายการนั้นสำเร็จ
  ///   - String  = บันทึกไม่สำเร็จ (ข้อความ error ที่จะโชว์ให้ผู้ใช้เห็น)
  ///
  /// ถ้าเจอรายการที่บันทึกไม่สำเร็จระหว่างลูป จะหยุดทันที (ไม่ยิงรายการถัดไปต่อ)
  /// แล้วเอาเฉพาะรายการที่ "บันทึกสำเร็จไปแล้วก่อนหน้า" ออกจากลิสต์รอบันทึก
  /// (กันผู้ใช้กดบันทึกซ้ำแล้วรายการเดิมถูกเพิ่มซ้ำสอง) ส่วนรายการที่เหลือ (รวมตัว
  /// ที่ error) จะยังค้างอยู่ในลิสต์ให้กดปุ่มบันทึกใหม่ได้อีกครั้งโดยไม่ต้องกรอกซ้ำ
  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    if (_tempTransactions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('add_at_least_one'))));
      return;
    }

    setState(() => _saving = true);

    try {
      final savedIds = <String>{};
      for (final tx in _tempTransactions) {
        final error = await service.addTransaction(
          type: tx['category'].type,
          amount: tx['amount'],
          category: tx['category'],
          date: DateTime.now(),
          note: tx['note'],
        );

        if (error != null) {
          if (mounted) {
            setState(() {
              _tempTransactions =
                  _tempTransactions.where((t) => !savedIds.contains(t['id'])).toList();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          }
          return;
        }

        savedIds.add(tx['id'] as String);
      }

      if (!mounted) return;
      showSuccessNotice(context, 'transaction_saved');
      _tempTransactions.clear();
      _editingId = null;
      _selectedCategory = null;

      Navigator.pushReplacement(
          context, noAnimationRoute(const IncomeExpenseScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${service.t('save_failed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type).where((category) =>
      service.categoryName(category).toLowerCase().contains(_categoryQuery.toLowerCase())).toList();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _numpadHeight + bottomInset;
    final typeAccent = _type == CategoryType.income ? AppColors.income : AppColors.expense;
    final compactPhone = MediaQuery.sizeOf(context).height <= 700 || MediaQuery.sizeOf(context).width <= 360;
    final topRowPadding = compactPhone ? 8.0 : 10.0;
    final sectionGap = compactPhone ? 8.0 : 12.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              // Short windows (including the keyboard) scroll the form as a
              // whole; normal phones retain the pinned controls and header.
              final scrollAll = MediaQuery.viewInsetsOf(context).bottom > 0 ||
                  constraints.maxHeight < (_showNumpad ? 650 : 500);
              final form = Column(
              children: [
                AppHeader(
                  title: service.t('income_expense'),
                  onBack: () => Navigator.pushReplacement(
                      context, noAnimationRoute(const HomeScreen())),
                  trailing: const SizedBox.shrink(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, topRowPadding, 12, 0),
                  child: Row(
                    children: [
                      _typeToggle(),
                      const Spacer(),
                      _saveButton(service),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, topRowPadding, 12, 0),
                  child: Row(children: [
                    Expanded(child: TextField(
                      key: const Key('category-search'),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      onTap: _closeNumpad,
                      onChanged: (value) => setState(() => _categoryQuery = value),
                      decoration: InputDecoration(
                        hintText: service.currentLanguage == 'English' ? 'Search categories' : 'ค้นหาหมวดหมู่',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                        isDense: true, filled: true, fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: service.currentLanguage == 'English' ? 'Scan receipt' : 'สแกนใบเสร็จ',
                      onPressed: () => Navigator.push(context, noAnimationRoute(const ReceiptScanScreen())),
                      icon: const Icon(Icons.document_scanner_outlined),
                    ),
                  ]),
                ),
                SizedBox(height: sectionGap),
                Flexible(
                  flex: scrollAll ? 0 : 1,
                  fit: FlexFit.tight,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Flexible(child: Text(service.t('categories'), style: AppTextStyles.heading, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 5),
                              Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accentPink),

                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _categoryRows(service, categories),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        if (_tempTransactions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${service.t('items_added')}: ${_tempTransactions.length} ${service.t('items_unit')} · ${service.t('tap_to_edit')}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // สรุปยอดรวมรายรับ/รายจ่าย/สุทธิของรายการที่ "รอบันทึก" อยู่
                          // ให้ผู้ใช้เห็นผลลัพธ์ก่อนกด Save จริง ลดโอกาสกรอกผิดแล้วไม่รู้ตัว
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _pendingSummaryCard(),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: _tempTransactions.map((tx) => _transactionTile(tx, service)).toList(),
                            ),
                          ),
                        ] else ...[
                          // คำแนะนำสั้นๆ ตอนยังไม่มีรายการ ช่วยให้ผู้ใช้ใหม่รู้ว่าต้องทำอะไรต่อ
                          SizedBox(height: sectionGap),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  CuteMascot(
                                      kind: CuteMascotKind.income,
                                      size: 20,
                                      color: AppColors.accentDeep),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      service.currentLanguage != 'English'
                                          ? 'แตะเลือกหมวดหมู่ด้านบน แล้วกรอกจำนวนเงินเพื่อเพิ่มรายการนะ 🌱'
                                          : 'Tap a category above, then enter an amount to add an item 🌱',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _editingId != null
                            ? Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentBg,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Icon(Icons.edit_rounded, size: 12, color: AppColors.ink),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${service.t('editing')}: ${_selectedCategory != null ? service.categoryName(_selectedCategory!) : ''}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _cancelEdit,
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    child: Text(service.t('cancel_edit'), style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  if (_selectedCategory != null)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.only(right: 7),
                                      decoration: BoxDecoration(color: typeAccent, borderRadius: BorderRadius.circular(2)),
                                    ),
                                  Expanded(
                                    child: Text(
                                      _selectedCategory != null
                                          ? '${service.t('selected_category')}: ${service.categoryName(_selectedCategory!)}'
                                          : service.t('select_category_prompt'),
                                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      _addButton(),
                    ],
                  ),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: _numpadAnim,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    heightFactor: _showNumpad ? 0 : 1,
                    child: AnimatedOpacity(
                      duration: _numpadAnim,
                      opacity: _showNumpad ? 0 : 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: AppTextField(
                          controller: _noteCtrl,
                          hint: service.t('note_optional'),
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _amountDisplay(),
                AnimatedContainer(
                  duration: _numpadAnim,
                  curve: Curves.easeOutCubic,
                  height: _showNumpad ? (scrollAll ? 0 : panelHeight) : (compactPhone ? 0.0 : bottomInset + 4),
                ),
              ],
            );
              return scrollAll ? Padding(
                padding: EdgeInsets.only(bottom: _showNumpad ? panelHeight : 0),
                child: SingleChildScrollView(reverse: _showNumpad, child: form),
              ) : form;
            }),
          ),

          // เดิมใช้ Positioned.fill(GestureDetector) คลุมทั้งจอเพื่อปิดแป้นเมื่อแตะข้างนอก
          // แต่วิธีนั้นทำให้ "การเลื่อนหน้าจอถูกบล็อกไปด้วย" เพราะ Flutter จะหยุดทดสอบ
          // การสัมผัสที่ widget ทึบตัวแรกที่เจอใน Stack (แม้จะตั้ง translucent ก็ตาม)
          // เปลี่ยนมาใช้ TapRegion แทน ซึ่งตรวจจับ "แตะข้างนอก" ได้โดยไม่ไปขวางการลาก/เลื่อน
          // ของเนื้อหาด้านล่าง ผู้ใช้เลื่อนดูรายการ/หมวดหมู่ได้ตามปกติแม้แป้นตัวเลขเปิดอยู่

          AnimatedPositioned(
            duration: _numpadAnim,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showNumpad ? 0 : -panelHeight,
            child: _numpadPanel(bottomInset),
          ),
        ],
      ),
      ),
      bottomNavigationBar: _showNumpad ? null : const BottomNav(currentIndex: 2),
    );
  }

  // ---------- ปุ่มบันทึก ----------
  Widget _saveButton(DataService service) {
    final disabled = _saving || _tempTransactions.isEmpty;
    return GestureDetector(
      onTap: disabled ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [AppColors.accentPink, AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: disabled ? AppColors.textMuted : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.accentPink.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: _saving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 5),
                  Text(service.t('save'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  // ---------- ปุ่มเพิ่ม/ยืนยันแก้ไข ----------
  Widget _addButton() {
    final isEditing = _editingId != null;
    return GestureDetector(
      onTap: _addOrUpdate,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEditing
                ? [AppColors.accentDeep, AppColors.accentDeep]
                : [AppColors.accentPink, AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPink.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(isEditing ? Icons.check_rounded : Icons.add_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }

  // ---------- การ์ดสรุปยอดรวมรายการที่ "รอบันทึก" ----------
  Widget _pendingSummaryCard() {
    double income = 0;
    double expense = 0;
    for (final tx in _tempTransactions) {
      final amt = tx['amount'] as double;
      if ((tx['category'] as CategoryModel).type == CategoryType.income) {
        income += amt;
      } else {
        expense += amt;
      }
    }
    final net = income - expense;
    final isThai = context.read<DataService>().currentLanguage != 'English';

    Widget item(String label, double value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              context.watch<DataService>().formatMoney(value),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          item(isThai ? 'รายรับรวม' : 'Income', income, AppColors.income),
          Container(width: 1, height: 28, color: AppColors.border),
          item(isThai ? 'รายจ่ายรวม' : 'Expense', expense, AppColors.expense),
          Container(width: 1, height: 28, color: AppColors.border),
          item(isThai ? 'ยอดสุทธิ' : 'Net', net, net >= 0 ? AppColors.income : AppColors.expense),
        ],
      ),
    );
  }

  // ---------- รายการที่เพิ่มแล้ว ----------
  Widget _transactionTile(Map<String, dynamic> tx, DataService service) {
    final isEditing = tx['id'] == _editingId;
    final isIncome = tx['category'].type == CategoryType.income;
    final accent = isIncome ? AppColors.income : AppColors.expense;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // ปัดซ้ายเพื่อลบรายการได้ทันที (นอกเหนือจากปุ่ม X เดิม) — เร็วกว่าสำหรับ
      // คนที่มีหลายรายการ และยังลบผิดแล้วกด "เลิกทำ" ใน Snackbar ได้เหมือนเดิม
      child: Dismissible(
        key: ValueKey(tx['id']),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _removeTransaction(tx['id']),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        child: GestureDetector(
        onTap: () => _startEdit(tx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isEditing ? AppColors.accentBg : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isEditing ? AppColors.accentPink : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
                        ),
                        child: Center(
                          child: CategoryIcon(
                              category: tx['category'], size: 18, color: accent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.categoryName(tx['category']),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                            if (tx['note'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(tx['note'],
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      Text('${isIncome ? '+' : '-'}${context.watch<DataService>().formatMoney(tx['amount'] as double)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13.5)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeTransaction(tx['id']),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.close_rounded, size: 15, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ---------- ช่องแสดง/กรอกจำนวนเงิน ----------
  Widget _amountDisplay() {
    final showPlaceholder = !_showNumpad && _amountText.isEmpty;

    return TapRegion(
      groupId: _numpadGroupId,
      onTapOutside: (_) => _closeNumpad(),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openNumpad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _showNumpad ? AppColors.accentPink : AppColors.border,
            width: _showNumpad ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_showNumpad ? AppColors.accentPink : Colors.black)
                  .withOpacity(_showNumpad ? 0.16 : 0.04),
              blurRadius: _showNumpad ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: showPlaceholder
            ? Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.payments_outlined, size: 14, color: AppColors.accentDeep),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กรุณาระบุจำนวนเงิน',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _amountText.isEmpty ? '0' : _amountText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (_showNumpad) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(color: AppColors.accentPink, height: 22),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        context.watch<DataService>().currencySymbol,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ))),
                  if (_showNumpad) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _finishAmountInput,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentDeep.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      ),
    );
  }

  // ---------- แผงปุ่มตัวเลข ----------
  Widget _numpadPanel(double bottomInset) {
    return TapRegion(
      groupId: _numpadGroupId,
      child: Material(
      color: AppColors.bg,
      elevation: 3,
      shadowColor: AppColors.shadow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: SizedBox(
        height: _numpadHeight + bottomInset,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _numPad()),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
      ),
    );
  }

  // ---------- กริดหมวดหมู่ ----------
  Widget _categoryRows(DataService service, List<CategoryModel> categories) {
    final tiles = <Widget>[
      ...categories.asMap().entries.map((e) => _categoryTile(e.value, service, e.key)),
      _otherCategoryTile(service),
    ];
    final compactPhone = MediaQuery.sizeOf(context).width <= 360;
    final crossAxisCount = compactPhone ? 3 : 4;
    final labelPainter = TextPainter(
      text: TextSpan(text: service.t('other_category'),
        style: TextStyle(fontFamily: appFontFamily, fontSize: compactPhone ? 10.5 : 12.5, height: 1.4)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context), maxLines: 1,
    )..layout();
    final mainAxisExtent = (compactPhone ? 30.0 : (_showNumpad ? 36.0 : 42.0)) +
        labelPainter.height + 6;
    labelPainter.dispose();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: mainAxisExtent,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }

  Widget _categoryTile(CategoryModel c, DataService service, int index) {
    final selected = _selectedCategory?.id == c.id;
    final compactPhone = MediaQuery.sizeOf(context).width <= 360;
    final iconSize = compactPhone ? 18.0 : (_showNumpad ? 22.0 : 28.0);
    final labelSize = compactPhone ? 10.0 : 11.0;
    return Semantics(selected: selected, button: true,
      child: Material(
        color: selected ? AppColors.accentBg : c.colorValue != null
            ? Color(c.colorValue!).withValues(alpha: 0.28) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            FocusScope.of(context).unfocus();
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
            HapticFeedback.selectionClick();
            setState(() { _selectedCategory = c; _showNumpad = true; });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.accentDeep : AppColors.border.withValues(alpha: 0.35), width: selected ? 2 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CategoryIcon(category: c, size: iconSize, color: AppColors.accentDeep),
              SizedBox(height: compactPhone ? 2 : 4),
              Text(service.categoryName(c), maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: appFontFamily, height: 1.4, fontSize: labelSize, color: AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _otherCategoryTile(DataService service) {
    final compactPhone = MediaQuery.sizeOf(context).width <= 360;
    return GestureDetector(
      onTap: () => _showAddCategoryDialog(service),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compactPhone ? 26.0 : (_showNumpad ? 30.0 : 36.0),
            height: compactPhone ? 26.0 : (_showNumpad ? 30.0 : 36.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compactPhone ? 13.0 : (_showNumpad ? 15.0 : 20.0)),
              color: AppColors.accentAltBg,
              border: Border.all(
                color: AppColors.border,
                width: 1.4,
              ),
            ),
            child: Icon(Icons.add_rounded, color: AppColors.accentPink, size: compactPhone ? 18.0 : 22.0),
          ),
          SizedBox(height: compactPhone ? 4.0 : 6.0),
          Text(
            service.t('other_category'),
            style: TextStyle(fontFamily: appFontFamily, height: 1.4, fontSize: compactPhone ? 10.5 : 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(DataService service) async {
    _closeNumpad();
    final created = await showModalBottomSheet<CategoryModel>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => CategoryEditorSheet(service: service, type: _type),
    );
    if (!mounted || created == null) return;
    setState(() { _selectedCategory = created; _showNumpad = true; });
  }

  Widget _typeToggle() {
    final service = context.watch<DataService>();
    final isIncome = _type == CategoryType.income;
    const toggleWidth = 160.0;
    const toggleHeight = 34.0;
    return Container(
      width: toggleWidth,
      height: toggleHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isIncome ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isIncome
                        ? [AppColors.income, AppColors.income.withOpacity(0.82)]
                        : [AppColors.expense, AppColors.expense.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.income;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: FittedBox(child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.income,
                            color: isIncome ? Colors.white : AppColors.income,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            color: isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('incomes_tab')),
                        ),
                      ],
                    )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _type = CategoryType.expense;
                    if (_editingId == null) _selectedCategory = null;
                  }),
                  child: Center(
                    child: FittedBox(child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CuteMascot(
                            kind: CuteMascotKind.expense,
                            color: !isIncome ? Colors.white : AppColors.expense,
                            size: 14),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            color: !isIncome ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          child: Text(service.t('expenses_tab')),
                        ),
                      ],
                    )),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numPad() => AmountKeypad(
    controller: _amountController,
  );
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;
  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.5,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
```

### 13.23 flutter_application_1/lib/screens/app_theme.dart

รวม AppColors, AppLayout, AppRadius, AppTextStyles และธีมมืด รวม widget กลาง เช่น AppHeader, AppCard, PrimaryButton, AppTextField, MessageBanner, EmptyState และ mascot ที่วาดด้วย CustomPainter

โครงสร้างที่ประกาศ: class AppColors (L15); class AppLayout (L57); class AppRadius (L69); class AppTextStyles (L97); class AppTheme (L120); class AppHeader extends StatelessWidget (L185); class AppCard extends StatelessWidget (L239); class PrimaryButton extends StatelessWidget (L284); class AppTextField extends StatelessWidget (L333); class MessageBanner extends StatelessWidget (L436); class HeaderIconBadge extends StatelessWidget (L467); enum CuteMascotKind (L491); class CuteMascot extends StatelessWidget (L493); class _CuteMascotPainter extends CustomPainter (L523); class EmptyState extends StatelessWidget (L603)

667 บรรทัด • SHA-256: 680f9e36fb3def80

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// สร้าง Route แบบไม่มีอนิเมชันสไลด์ (ใช้แทน MaterialPageRoute ทุกจุดในแอป
/// เพื่อให้การเปลี่ยนหน้าทุกที่ไม่มีเอฟเฟกต์เลื่อนจากขอบจอแบบ default ของ iOS)
PageRoute<T> noAnimationRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// ธีมกลางของแอป BUDGETMATE
class AppColors {
  AppColors._();

  static Brightness brightness = Brightness.light;
  static bool get _dark => brightness == Brightness.dark;

  static Color get ink => _dark ? const Color(0xFFC1E4F3) : const Color(0xFF3D568F);
  static Color get inkOn => Colors.white;
  static Color get accent => const Color(0xFFC1E4F3);
  static Color get accentAlt => const Color(0xFFFFE698);
  static Color get accentDeep => const Color(0xFF3D568F);
  static Color get accentPink => const Color.fromARGB(255, 234, 139, 171);

  static Color get accentBg => _dark ? const Color(0xFF223259) : const Color(0xFFDCEEF7);
  static Color get accentAltBg => _dark ? const Color(0xFF4A2A3C) : const Color(0xFFFBEED0);

  static Color get bg => _dark ? const Color(0xFF141A2C) : const Color(0xFFF6F9FF);
  static Color get surface => _dark ? const Color(0xFF1E2740) : const Color(0xFFEFF4FE);
  static Color get surfaceAlt => _dark ? const Color(0xFF262F4A) : const Color(0xFFFFF8FB);
  static Color get card => _dark ? const Color(0xFF1E2740) : const Color(0xFFFFFFFF);
  static Color get border => _dark ? const Color(0xFF2E3A5C) : const Color(0xFFE3EBFB);

  static Color get textPrimary => _dark ? const Color(0xFFEDF2FF) : const Color(0xFF283350);
  static Color get textSecondary => _dark ? const Color(0xFFAAB8DD) : const Color(0xFF8493B3);
  static Color get textMuted => _dark ? const Color(0xFFAAB8D5) : const Color(0xFFBCC8E2);

  static Color get success => _dark ? const Color(0xFF7FD9A8) : const Color(0xFF3D9E73);
  static Color get successBg => _dark ? const Color(0xFF1F3A2E) : const Color(0xFFE4F8ED);
  static Color get danger => _dark ? const Color(0xFFF0A0A0) : const Color(0xFFE0645F);
  static Color get dangerBg => _dark ? const Color(0xFF3E2429) : const Color(0xFFFFEAE8);
  static Color get income => _dark ? const Color(0xFFA0E4C0) : const Color(0xFF45AB7C);
  static Color get incomeBg => _dark ? const Color(0xFF1F3A2E) : const Color(0xFFE4F8ED);
  static Color get expense => _dark ? const Color(0xFFF6AFAA) : const Color(0xFFF0847A);
  static Color get expenseBg => _dark ? const Color(0xFF3E2429) : const Color(0xFFFFEAE8);

  static Color get shadow => const Color(0xFF80A1D4).withOpacity(_dark ? 0.30 : 0.10);

  static const List<Color> pinnedGoalBg = [Color(0xFFC1E4F3), Color(0xFFFFE698)];
  static Color get pinnedGoalIcon => const Color(0xFF3D568F);
}

/// Phone layout metrics in logical pixels; system text scaling stays intact.
class AppLayout {
  static double pageInset(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.04).clamp(14.0, 20.0);

  static double chartHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.52).clamp(180.0, 240.0);

  static double categoryHeight(BuildContext context, {bool compact = false}) =>
      (compact ? 52.0 : (MediaQuery.sizeOf(context).width * 0.16).clamp(58.0, 66.0)) +
      (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 48.0);
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

/// ฟอนต์กลางของแอป — 'Mali' (มะลิ) ฟอนต์ไทยลายเส้นกลมมนน่ารัก อ่านง่าย
///
/// เวอร์ชันนี้ "บันเดิลไฟล์ฟอนต์ไว้ในเครื่อง" (assets/fonts/) แทนการเรียกผ่าน
/// แพ็กเกจ google_fonts ที่ดาวน์โหลดไฟล์ฟอนต์จากเน็ตตอนรันครั้งแรก
///
/// เหตุผลที่เปลี่ยนมาบันเดิลเอง: เวลาใช้ google_fonts มันจะไปดาวน์โหลดไฟล์ฟอนต์
/// จริง (.ttf) แบบ asynchronous ตอนแอปเรียกใช้ครั้งแรก ถ้าเน็ตช้า/ตอนนั้นยังโหลด
/// ไม่เสร็จ หน้าที่ render ไปแล้วก่อนโหลดเสร็จจะค้างใช้ฟอนต์ระบบเดิม (fallback)
/// ไปก่อน ส่วนหน้าที่ถูกเปิดทีหลัง (หลังโหลดฟอนต์เสร็จแล้ว) จะได้ฟอนต์ใหม่ทันที
/// - นี่คือสาเหตุที่ "บางหน้าเปลี่ยนฟอนต์ บางหน้าไม่เปลี่ยน" แบบสุ่มๆ ตามจังหวะ
/// การโหลด ไม่เกี่ยวกับโค้ดหน้านั้นๆ เลย
///
/// การบันเดิลไฟล์ฟอนต์ไว้ในแอปเอง (ผ่าน pubspec.yaml) ทำให้ฟอนต์พร้อมใช้งาน
/// ทันทีตั้งแต่เฟรมแรกที่แอปเปิด ไม่ต้องพึ่งอินเทอร์เน็ต และแสดงผลสม่ำเสมอ
/// เหมือนกันทุกหน้า ทุกเครื่อง ทุกครั้งที่เปิดแอป
///
/// หมายเหตุ: ต้องประกาศฟอนต์ 6 น้ำหนัก (200-700) ใน pubspec.yaml (ดูท้ายไฟล์)
/// เพื่อให้ FontWeight.w200 ... FontWeight.w700 ที่ใช้อยู่ทั่วแอป (w600, w700,
/// FontWeight.bold ฯลฯ) เลือกไฟล์ฟอนต์น้ำหนักที่ถูกต้องได้อัตโนมัติ
const String appFontFamily = 'Mali';

class AppTextStyles {
  static TextStyle get title => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static TextStyle get heading => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static TextStyle get label => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static TextStyle get hint => TextStyle(
      fontFamily: appFontFamily, color: AppColors.textMuted, fontSize: 14);
  static TextStyle get caption => TextStyle(
      fontFamily: appFontFamily, color: AppColors.textSecondary, fontSize: 12.5);
}

/// สร้าง ThemeData ของแอปสำหรับ MaterialApp(theme:, darkTheme:, themeMode:)
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141A2C) : const Color(0xFFF6F9FF);
    final ink = isDark ? const Color(0xFFC1E4F3) : const Color(0xFF3D568F);
    final surface = isDark ? const Color(0xFF1E2740) : const Color(0xFFEFF4FE);
    final onSurface = isDark ? const Color(0xFFEDF2FF) : const Color(0xFF283350);

    // .apply(fontFamily:) เซ็ตฟอนต์ให้ทุก TextStyle มาตรฐานใน textTheme
    // (bodyMedium, titleLarge, labelSmall ฯลฯ) ที่ widget ต่างๆ ในแอปอาจใช้
    // แบบ implicit (ผ่าน Theme.of(context).textTheme หรือ Text('...') เฉยๆ)
    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final appTextTheme = baseTextTheme.apply(fontFamily: appFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dialogBackgroundColor: isDark ? const Color(0xFF1E2740) : Colors.white,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF80A1D4),
        onPrimary: Colors.white,
        secondary: const Color(0xFFC08B9D),
        onSecondary: Colors.white,
        error: isDark ? const Color(0xFFF0A0A0) : const Color(0xFFE0645F),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 48,
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            fontFamily: appFontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2740) : Colors.white,
        selectedItemColor: ink,
        unselectedItemColor: isDark ? const Color(0xFF69759A) : const Color(0xFFBCC8E2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? const Color(0xFFC1E4F3) : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? const Color(0xFF80A1D4) : null),
      ),
      textTheme: appTextTheme,
      // สำคัญ: เซ็ต fontFamily ตรงนี้ด้วย เผื่อ widget บางตัวอ้างอิง
      // ThemeData.fontFamily ตรงๆ แทนที่จะผ่าน textTheme
      fontFamily: appFontFamily,
    );
  }
}

/// Header พาสเทลโค้งมนด้านล่าง ใช้ซ้ำได้ทุกหน้า
class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppHeader({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(6, MediaQuery.of(context).padding.top + 2, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.brightness == Brightness.dark ? AppColors.surface : AppColors.accent,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
            onPressed: onBack ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: appFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 44,
            child: trailing ??
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.auto_awesome_rounded, color: AppColors.accentAlt, size: 20),
                ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดพื้นฐานที่ใช้ซ้ำได้ทั่วแอป
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoratedChild = Material(
      type: MaterialType.transparency,
      child: child,
    );
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: decoratedChild,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// ปุ่มหลักของแอป (พื้น ink ตัวอักษรตัดกัน มุมโค้ง)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.ink;
    final fg = AppColors.inkOn;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: appFontFamily,
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// ฟิลด์กรอกข้อความสไตล์เดียวกันทั้งแอป
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? toggleObscure;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final bool autofocus;
  final String? prefixText;
  final String? errorText;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.toggleObscure,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.autofocus = false,
    this.prefixText,
    this.errorText,
    this.style,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.onChanged,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofillHints: autofillHints,
      autocorrect: toggleObscure == null,
      enableSuggestions: toggleObscure == null,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      obscureText: obscureText,
      obscuringCharacter: '*',
      maxLines: obscureText ? 1 : maxLines,
      autofocus: autofocus,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: style ?? TextStyle(fontFamily: appFontFamily, fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        prefixText: prefixText,
        prefixStyle: style ?? TextStyle(fontFamily: appFontFamily, fontSize: 14, color: AppColors.textPrimary),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 21) : null,
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accentDeep, width: 1.4),
        ),
        errorText: errorText,
        errorStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.danger, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }
}

/// แบนเนอร์ error/success ใช้ซ้ำได้ทุกฟอร์ม
class MessageBanner extends StatelessWidget {
  final String text;
  final bool isError;

  const MessageBanner({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    final bg = isError ? AppColors.dangerBg : AppColors.successBg;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm + 2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontFamily: appFontFamily, color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// ไอคอนวงกลมหัวเรื่อง
class HeaderIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? iconColor;

  const HeaderIconBadge({super.key, required this.icon, this.background, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: background ?? AppColors.accentBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 28, color: iconColor ?? AppColors.ink),
      ),
    );
  }
}

/// ตัวการ์ตูนน่ารักๆ วาดด้วย CustomPainter
enum CuteMascotKind { bell, coin, star, flagTH, flagEN, flagUS, income, expense }

class CuteMascot extends StatelessWidget {
  final CuteMascotKind kind;
  final double size;
  final Color? color;

  const CuteMascot({super.key, required this.kind, this.size = 22, this.color});

  Color _defaultColor() {
    switch (kind) {
      case CuteMascotKind.income:
        return const Color(0xFFA9E0BC);
      case CuteMascotKind.expense:
        return const Color(0xFFF5C2B3);
      default:
        return AppColors.accentDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CuteMascotPainter(kind: kind, color: color ?? _defaultColor()),
      ),
    );
  }
}

class _CuteMascotPainter extends CustomPainter {
  final CuteMascotKind kind;
  final Color color;

  _CuteMascotPainter({required this.kind, required this.color});

  Color get _face => Color.lerp(color, Colors.black, 0.55)!;

  double get _tilt {
    switch (kind) {
      case CuteMascotKind.income:
        return -0.1;
      case CuteMascotKind.expense:
        return 0.1;
      default:
        return 0.0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_tilt);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.92), width: r * 1.3, height: r * 0.22),
      Paint()..color = Colors.black.withOpacity(0.05),
    );

    canvas.drawCircle(Offset.zero, r * 0.86, Paint()..color = color);

    final eyeR = r * 0.09;
    final eyeOffsetX = r * 0.28;
    final eyeY = -r * 0.08;
    canvas.drawCircle(Offset(-eyeOffsetX, eyeY), eyeR, Paint()..color = _face);
    canvas.drawCircle(Offset(eyeOffsetX, eyeY), eyeR, Paint()..color = _face);

    final smile = Path()
      ..moveTo(-r * 0.18, r * 0.2)
      ..quadraticBezierTo(0, r * 0.34, r * 0.18, r * 0.2);
    canvas.drawPath(
      smile,
      Paint()
        ..color = _face
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );

    if (kind == CuteMascotKind.flagTH ||
        kind == CuteMascotKind.flagEN ||
        kind == CuteMascotKind.flagUS) {
      final label = kind == CuteMascotKind.flagTH
          ? 'TH'
          : kind == CuteMascotKind.flagEN
              ? 'EN'
              : 'US';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontFamily: appFontFamily, fontSize: r * 0.36, fontWeight: FontWeight.w700, color: _face),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, r * 0.34));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CuteMascotPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/*
==================== วิธีติดตั้งฟอนต์ Mali (บันเดิลในเครื่อง) ====================
1) วางไฟล์ฟอนต์ทั้ง 6 ไฟล์ (แนบมาให้แล้วในโฟลเดอร์ fonts/) ไว้ที่:
     assets/fonts/Mali-ExtraLight.ttf
     assets/fonts/Mali-Light.ttf
     assets/fonts/Mali-Regular.ttf
     assets/fonts/Mali-Medium.ttf
     assets/fonts/Mali-SemiBold.ttf
     assets/fonts/Mali-Bold.ttf

2) เปิด pubspec.yaml แล้วเพิ่มส่วนนี้ใต้ flutter: (ลบ dependency
   google_fonts ออกจาก pubspec ได้เลยถ้าไม่ได้ใช้ที่อื่นในโปรเจกต์แล้ว):

   flutter:
     fonts:
       - family: Mali
         fonts:
           - asset: assets/fonts/Mali-ExtraLight.ttf
             weight: 200
           - asset: assets/fonts/Mali-Light.ttf
             weight: 300
           - asset: assets/fonts/Mali-Regular.ttf
             weight: 400
           - asset: assets/fonts/Mali-Medium.ttf
             weight: 500
           - asset: assets/fonts/Mali-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Mali-Bold.ttf
             weight: 700

3) รันคำสั่งนี้ในโปรเจกต์:
     flutter pub get

4) ทำ hot restart (ไม่ใช่แค่ hot reload) — สำคัญมาก เพราะการเพิ่ม/แก้ font
   assets ใน pubspec.yaml ต้อง restart แอปใหม่ทั้งหมด hot reload อย่างเดียว
   จะไม่ดึงฟอนต์ใหม่มาโหลด

การบันเดิลฟอนต์แบบนี้ทำให้ทุกหน้าในแอปได้ฟอนต์ Mali ทันทีตั้งแต่เปิดแอป
ไม่มีปัญหา "บางหน้าเปลี่ยน บางหน้าไม่เปลี่ยน" อีกต่อไป เพราะไม่ต้องพึ่ง
การดาวน์โหลดฟอนต์จากอินเทอร์เน็ตแบบที่ google_fonts package ทำ

ไฟล์ OFL.txt (สัญญาอนุญาต SIL Open Font License) แนบมาด้วย — ใช้งาน/แจกจ่าย
ในแอปได้ฟรีทั้งเชิงพาณิชย์และไม่เชิงพาณิชย์ ไม่ต้องขออนุญาตเพิ่มเติม
*/
```

### 13.24 flutter_application_1/lib/screens/change_password_screen.dart

รับรหัสเดิม รหัสใหม่ และยืนยัน ตรวจ policy/confirmation แล้วเรียก changePassword แสดงผลลัพธ์และสถานะกำลังบันทึก

โครงสร้างที่ประกาศ: class ChangePasswordScreen extends StatefulWidget (L10); class _ChangePasswordScreenState extends State<ChangePasswordScreen> (L17)

164 บรรทัด • SHA-256: 84027a2909088376

```dart
import '../widgets/password_requirements.dart';
import '../services/password_policy.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';


/// หน้า Password & Security - เปลี่ยนรหัสผ่าน (ต้องยืนยันรหัสผ่านเดิมก่อน)
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final service = context.read<DataService>();
    if (_currentCtrl.text.isEmpty) {
      setState(() {
        _error = service.t('enter_current_password');
        _success = null;
      });
      return;
    }
    final invalid = passwordValidationKey(_newCtrl.text);
    if (invalid != null) {
      setState(() {
        _error = service.t(invalid);
        _success = null;
      });
      return;
    }
    if (_confirmCtrl.text.isEmpty) {
      setState(() { _error = service.t('enter_confirm_password'); _success = null; });
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() {
        _error = service.t('password_mismatch');
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    String? error;
    try { error = await service.changePassword(_currentCtrl.text, _newCtrl.text); }
    catch (_) { error = service.t('save_failed'); }

    if (!mounted) return;
    if (error == null) {
      setState(() {
        _loading = false;
        _success = service.t('change_password_success');
      });
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('password_security'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeaderIconBadge(icon: Icons.shield_outlined),
              const SizedBox(height: 18),
              _label(service.t('current_password')),
              AppTextField(
                controller: _currentCtrl,
                autofillHints: const [AutofillHints.password],
                hint: service.t('current_password_hint'),
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureCurrent,
                toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 12),
              _label(service.t('new_password')),
              AppTextField(
                controller: _newCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                hint: service.t('new_password_hint'),
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureNew,
                toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 12),
              _label(service.t('confirm_new_password')),
              AppTextField(
                controller: _confirmCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                hint: service.t('confirm_new_password_hint'),
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirm,
                toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              PasswordRequirements(password: _newCtrl, confirmation: _confirmCtrl),
              if (_error != null) ...[
                const SizedBox(height: 12),
                MessageBanner(text: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                MessageBanner(text: _success!, isError: false),
              ],
              const SizedBox(height: 18),
              PrimaryButton(label: service.t('save_new_password'), loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
      );
}
```

### 13.25 flutter_application_1/lib/screens/currency_screen.dart

dropdown ของ supportedCurrencies บันทึกด้วย setCurrency และกลับหน้าก่อนหน้า; เป็นการเลือกกลุ่มรายการตามสกุลเงิน ไม่มี conversion

โครงสร้างที่ประกาศ: class CurrencyScreen extends StatefulWidget (L5); class _CurrencyScreenState extends State<CurrencyScreen> (L10)

42 บรรทัด • SHA-256: 1a1f0dcbe6a2ed8f

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});
  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}
class _CurrencyScreenState extends State<CurrencyScreen> {
  String? selected;
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final english = service.currentLanguage == 'English';
    return Scaffold(
      appBar: AppBar(title: Text(service.t('currency_label'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: selected ?? service.currentCurrency,
          decoration: InputDecoration(labelText: service.t('currency_label')),
          items: DataService.supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: saving ? null : (value) => setState(() => selected = value),
        ),
        const SizedBox(height: 16),
        Text(english ? 'New entries use the selected currency. Existing entries keep their original currency. Wallet, history and goals show the selected currency only; switch back to view earlier entries.'
          : 'รายการใหม่บันทึกตามสกุลเงินที่เลือก รายการเดิมคงสกุลเงินเดิม กระเป๋า ประวัติ และเป้าหมายแสดงเฉพาะสกุลเงินที่เลือก เปลี่ยนกลับเพื่อดูรายการเดิมได้'),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton(onPressed: saving ? null : () async {
          setState(() { saving = true; error = null; });
          try {
            await service.setCurrency(selected ?? service.currentCurrency);
            if (context.mounted) Navigator.pop(context);
          } catch (e) { if (mounted) setState(() { saving = false; error = '$e'; }); }
        }, child: Text(saving ? (english ? 'Saving…' : 'กำลังบันทึก…') : service.t('save'))),
      ]),
    );
  }
}
```

### 13.26 flutter_application_1/lib/screens/edit_transaction_screen.dart

sheet/หน้าแก้รายการ เติมค่าจาก object เดิม ใช้ addTransaction เมื่อทำซ้ำหรือ editTransaction เมื่อแก้ มี date picker และ keypad; บันทึกสำเร็จคืน true

โครงสร้างที่ประกาศ: class EditTransactionScreen extends StatefulWidget (L27); class _EditTransactionScreenState extends State<EditTransactionScreen> (L40)

326 บรรทัด • SHA-256: 99b4f321dc4be85d

```dart
import '../widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/transaction_sheet_style.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;
import '../widgets/pastel_artwork.dart';
import '../widgets/amount_keypad.dart';

Future<bool?> showEditTransactionSheet(
        BuildContext context, TransactionModel transaction,
        {bool duplicate = false}) =>
    showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black38,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => EditTransactionScreen(
            transaction: transaction, asSheet: true, duplicate: duplicate));

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen(
      {super.key,
      required this.transaction,
      this.asSheet = false,
      this.duplicate = false});
  final TransactionModel transaction;
  final bool asSheet;
  final bool duplicate;
  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late final _amount =
      TextEditingController(text: widget.transaction.amount.toString());
  late final _note = TextEditingController(text: widget.transaction.note ?? '');
  late CategoryType _type = widget.transaction.type;
  late CategoryModel? _category = widget.transaction.category;
  late DateTime _date =
      widget.duplicate ? DateTime.now() : widget.transaction.date;
  bool _saving = false;
  bool _showAmountKeypad = false;
  bool _showNote = true;
  String? _error;
  String _t(String th, String en) =>
      context.read<DataService>().currentLanguage == 'English' ? en : th;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _error = _t('กรอกจำนวนเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.duplicate) {
        final error = await service.addTransaction(
            type: _type,
            amount: amount,
            category: _category!,
            date: _date,
            note: _note.text.trim());
        if (error != null) throw StateError(error);
      } else {
        await service.editTransaction(widget.transaction.id,
            type: _type,
            amount: amount,
            category: _category,
            date: _date,
            note: _note.text.trim());
      }
      if (!mounted) return;
      showSuccessNotice(context,
          widget.duplicate ? 'transaction_duplicated' : 'transaction_updated');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = service.t('save_failed');
        });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDialog<DateTime>(
        context: context,
        builder: (_) => PastelCalendarDialog(
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2200),
            isThai: context.read<DataService>().currentLanguage != 'English'));
    if (date != null && mounted)
      setState(() => _date = DateTime(date.year, date.month, date.day,
          _date.hour, _date.minute, _date.second));
  }

  InputDecoration _field(String hint) => InputDecoration(
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        hintText: hint,
        hintStyle: const TextStyle(color: TransactionSheetColors.muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: TransactionSheetColors.accent, width: 2)),
      );

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: TransactionSheetColors.muted, fontSize: 14)));

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type);
    if (_category != null && !categories.any((c) => c.id == _category!.id))
      categories.add(_category!);
    final content = TransactionSheetFrame(
      title: widget.duplicate
          ? _t('ทำซ้ำรายการ', 'Duplicate transaction')
          : _t('แก้ไขรายการ', 'Edit transaction'),
      busy: _saving,
      actions: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_showAmountKeypad && MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            AmountKeypad(controller: _amount),
            const SizedBox(height: 8),
          ],
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  style: transactionActionStyle(primary: true),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.duplicate
                          ? _t('บันทึกรายการใหม่', 'Save new transaction')
                          : service.t('save')))),
      ]),
      child: AbsorbPointer(
          absorbing: _saving,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const PastelArtwork(categoryNumber: 14, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(service.t('wallet_title'),
                                style: const TextStyle(
                                    color: TransactionSheetColors.ink,
                                    fontWeight: FontWeight.w700)))
                      ]))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: TransactionSheetColors.muted, size: 18)),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      key: ValueKey(_type),
                      initialValue: _category?.id,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 320,
                      decoration: _field(_t('หมวดหมู่', 'Category')).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10)),
                      items: categories
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Row(children: [
                                CategoryIcon(category: c, size: 27),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(service.categoryName(c),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: TransactionSheetColors.ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)))
                              ])))
                          .toList(),
                      onChanged: (id) => setState(() => _category =
                          categories.firstWhere((c) => c.id == id)))),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<CategoryType>(
                segments: [
                  ButtonSegment(
                      value: CategoryType.income,
                      label: Text(service.t('income'))),
                  ButtonSegment(
                      value: CategoryType.expense,
                      label: Text(service.t('expense')))
                ],
                selected: {
                  _type
                },
                style: ButtonStyle(
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected)
                            ? TransactionSheetColors.accent
                            : Colors.white),
                    foregroundColor: const WidgetStatePropertyAll(
                        TransactionSheetColors.ink)),
                onSelectionChanged: (value) => setState(() {
                      _type = value.single;
                      if (_category?.type != _type) _category = null;
                    })),
            _label(_t('จำนวนเงิน', 'Amount')),
            TextField(
                controller: _amount,
                readOnly: true,
                showCursor: true,
                keyboardType: TextInputType.none,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _amount.selection = TextSelection(
                      baseOffset: 0, extentOffset: _amount.text.length);
                  setState(() => _showAmountKeypad = true);
                },
                style: const TextStyle(
                    color: TransactionSheetColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                decoration: _field('0.00')
                    .copyWith(suffixText: service.currentCurrency)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 10, children: [
              ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined,
                      color: TransactionSheetColors.muted, size: 20),
                  label: Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
                  onPressed: _pickDate,
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle:
                      const TextStyle(color: TransactionSheetColors.muted)),
              ActionChip(
                  avatar: const Icon(Icons.edit_note_rounded,
                      color: TransactionSheetColors.muted, size: 20),
                  label: Text(_t('บันทึกช่วยจำ', 'Note')),
                  onPressed: () => setState(() => _showNote = !_showNote),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle:
                      const TextStyle(color: TransactionSheetColors.muted)),
            ]),
            if (_showNote) ...[
              _label(_t('บันทึกช่วยจำ', 'Note')),
              TextField(
                  controller: _note,
                  onTap: () => setState(() => _showAmountKeypad = false),
                  minLines: 1,
                  maxLines: 6,
                  decoration: _field(_t('เพิ่มข้อความช่วยจำ…', 'Add a note…')),
                  style: const TextStyle(
                      color: TransactionSheetColors.ink, fontSize: 14)),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: TransactionSheetColors.red))),
            const SizedBox(height: 6),
          ])),
    );
    return PopScope(
        canPop: !_saving,
        child: widget.asSheet
            ? content
            : Scaffold(
                // The sheet frame owns keyboard insets, including in page mode.
                resizeToAvoidBottomInset: false,
                backgroundColor: TransactionSheetColors.background,
                body:
                    Align(alignment: Alignment.bottomCenter, child: content)));
  }
}
```

### 13.27 flutter_application_1/lib/screens/goal_saving_screen.dart

แสดงการ์ดเป้าหมายและเงินคงเหลือ พร้อมปักหมุด แก้ ลบ และ dialog ฝากเงิน _showDepositDialog จำกัดตัวเลือกตามส่วนที่ขาดและ balance แล้วเรียก transferToGoal

โครงสร้างที่ประกาศ: class GoalSavingScreen extends StatelessWidget (L32); class _GoalCard extends StatelessWidget (L168); class _InfoStat extends StatelessWidget (L706); class _QuickAmountChip extends StatelessWidget (L751)

795 บรรทัด • SHA-256: 9a53694ed042517c

```dart
import '../widgets/amount_keypad.dart';
import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'add_goal_saving_screen.dart';

// ชุดสีพาสเทลสลับให้การ์ดเป้าหมายแต่ละใบมีโทนต่างกัน (ไม่จืดซ้ำสีเดียวทั้งกริด)
const List<Color> _goalTint = [
  Color(0xFFDCEEF7), // ฟ้าอ่อน
  Color(0xFFFBEED0), // เหลืองพีชอ่อน
  Color(0xFFF6E1E7), // ชมพูอ่อน
  Color(0xFFE1EFF8), // ฟ้ากลางอ่อน
  Color(0xFFE8F3E3), // มินต์อ่อน
  Color(0xFFEFE7FA), // ม่วงลาเวนเดอร์อ่อน
];
const List<Color> _goalTintDeep = [
  Color(0xFF3D568F),
  Color(0xFFC79A3B),
  Color(0xFFC08B9D),
  Color(0xFF5C86C4),
  Color(0xFF4E9B6E),
  Color(0xFF8B6FC4),
];

/// หน้า Goal Saving (3.4.11) - กำหนดและติดตามเป้าหมายการออมเงิน
class GoalSavingScreen extends StatelessWidget {
  const GoalSavingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('goal_saving'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.accentDeep,
          backgroundColor: AppColors.card,
          onRefresh: () async {
            await refreshAppData(context);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 12),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentDeep, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -20,
                        top: -26,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        bottom: -30,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.account_balance_wallet_rounded,
                                    color: AppColors.accentDeep, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(service.t('ledger_balance'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(service.formatMoney(service.balance),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (service.goals.isEmpty)
                EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
              else
                LayoutBuilder(builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (var i = 0; i < service.goals.length; i++)
                      SizedBox(width: cardWidth, child: _GoalCard(
                        goal: service.goals[i],
                        tint: _goalTint[i % _goalTint.length],
                        tintDeep: _goalTintDeep[i % _goalTintDeep.length],
                        onTap: () => _showDepositDialog(context, service.goals[i]),
                      )),
                  ]);
                }),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentDeep,
        elevation: 0,
        onPressed: () => Navigator.push(context,
            noAnimationRoute(const AddGoalSavingScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}

/// การ์ดเป้าหมายการออมแบบพาสเทลน่ารัก
class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final Color tint;
  final Color tintDeep;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.tint,
    required this.tintDeep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 136),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: tintDeep.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -14,
                top: -18,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: tintDeep.withOpacity(0.10), shape: BoxShape.circle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: GoalArtwork(goal.icon, artworkNumber: goal.artworkNumber, color: tintDeep, size: 15),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: service.t(goal.isPinned ? 'unpin_goal' : 'pin_goal'),
                          icon: Icon(goal.isPinned ? Icons.push_pin_rounded : Icons.add_circle_outline_rounded,
                            color: tintDeep, size: 18),
                          onPressed: () async {
                            try { await service.setGoalPinned(goal.id, !goal.isPinned); }
                            catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(service.t('save_failed')))); }
                          },
                        ),
                        PopupMenuButton<String>(
                          tooltip: service.t('manage_goal'),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          iconColor: tintDeep,
                          color: AppColors.card,
                          surfaceTintColor: Colors.transparent,
                          shadowColor: AppColors.shadow,
                          elevation: 4,
                          position: PopupMenuPosition.under,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(color: AppColors.border),
                          ),
                          onSelected: (action) async {
                            if (action == 'edit') {
                              await Navigator.push(context, noAnimationRoute(AddGoalSavingScreen(goal: goal)));
                            } else {
                              final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.card,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  side: BorderSide(color: AppColors.border),
                                ),
                                titleTextStyle: AppTextStyles.heading,
                                contentTextStyle: AppTextStyles.caption.copyWith(
                                  fontSize: 14, height: 1.6, color: AppColors.textPrimary),
                                actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                                title: Text(service.t('delete_goal_confirm')),
                                content: Text('${goal.name}\n${service.t('delete_goal_notice')}'),
                                actions: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.ink,
                                      backgroundColor: AppColors.accentBg,
                                      minimumSize: const Size(88, 44),
                                      textStyle: AppTextStyles.label,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(service.t('cancel'))),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      backgroundColor: AppColors.dangerBg,
                                      minimumSize: const Size(88, 44),
                                      textStyle: AppTextStyles.label,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(service.t('delete'))),
                                ],
                              ));
                              if (confirmed != true || !context.mounted) return;
                              try { await service.deleteGoal(goal.id); }
                              catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(service.t('save_failed')))); }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.edit_rounded, size: 18, color: AppColors.ink),
                                ),
                                const SizedBox(width: 12),
                                Text(service.t('edit'), style: AppTextStyles.label),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                ),
                                const SizedBox(width: 12),
                                Text(service.t('delete'),
                                  style: AppTextStyles.label.copyWith(color: AppColors.danger)),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(goal.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (goal.note?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(goal.note!.trim(),
                            key: ValueKey('goal-note-${goal.id}'),
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Wrap(children: [
                      Text('${service.formatMoney(goal.savedAmount)} / ',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
                      Text(service.formatMoney(goal.targetAmount),
                        style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 7,
                        backgroundColor: Colors.white.withOpacity(0.7),
                        color: goal.progress >= 1 ? AppColors.success : tintDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// เปิด dialog ให้ผู้ใช้กรอกจำนวนเงินที่ต้องการ "โอนเงินจริง" เข้าเป้าหมาย [goal]
Future<void> _showDepositDialog(BuildContext context, GoalModel goal) async {
  final service = context.read<DataService>();
  final controller = TextEditingController();
  final remaining = (goal.targetAmount - goal.savedAmount).clamp(0, goal.targetAmount).toDouble();
  final maxTransferable = remaining < service.balance ? remaining : service.balance;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    barrierDismissible: false,
    builder: (dialogContext) {
      bool submitting = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void applyQuickAmount(double value) {
            if (value <= 0) return;
            controller.text = value == value.roundToDouble()
                ? value.toStringAsFixed(0)
                : value.toStringAsFixed(2);
            controller.selection =
                TextSelection.collapsed(offset: controller.text.length);
            setState(() => errorText = null);
          }

          Future<void> submit() async {
            if (submitting) return;
            final amount = double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
            if (!amount.isFinite || amount <= 0) {
              setState(() => errorText = service.t('enter_valid_amount'));
              return;
            }
            setState(() {
              submitting = true;
              errorText = null;
            });
            String? error;
            try { error = await service.transferToGoal(goal.id, amount); }
            catch (_) { error = service.t('save_failed'); }
            if (!dialogContext.mounted) return;
            if (error != null) {
              setState(() {
                submitting = false;
                errorText = error;
              });
              return;
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          }

          return PopScope(canPop: !submitting, child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDeep.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentDeep, AppColors.accent],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: GoalArtwork(goal.icon, artworkNumber: goal.artworkNumber, color: AppColors.accentDeep, size: 25),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(service.t('deposit_title'),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(goal.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: submitting ? null : () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: goal.progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.35),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(
                                '${context.watch<DataService>().formatMoney(goal.savedAmount)} / ${context.watch<DataService>().formatMoney(goal.targetAmount)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 8),
                            Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (goal.note?.trim().isNotEmpty == true) ...[
                          Text(service.currentLanguage == 'English' ? 'Note' : 'หมายเหตุ',
                            style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Text(goal.note!.trim(),
                            key: const Key('goal-note-detail'),
                            style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: _InfoStat(
                                icon: Icons.account_balance_wallet_rounded,
                                label: service.t('ledger_remaining'),
                                value: service.formatMoney(service.balance),
                                bg: AppColors.accentBg,
                                iconColor: AppColors.accentDeep,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoStat(
                                icon: Icons.flag_rounded,
                                label: service.t('needed_more'),
                                value: service.formatMoney(remaining),
                                bg: AppColors.accentAltBg,
                                iconColor: const Color(0xFFC79A3B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(service.t('deposit_title'),
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: controller,
                          hint: '0.00',
                          readOnly: true,
                          onTap: submitting ? null : () async {
                            await showAmountKeypad(dialogContext,
                              controller: controller,
                              title: service.t('deposit_title'));
                            if (dialogContext.mounted) setState(() => errorText = null);
                          },
                          prefixText: '${service.currentCurrency} ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
                          keyboardType: TextInputType.none,
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) =>
                              RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text) ? newValue : oldValue),
                          ],
                          errorText: errorText,
                          onChanged: (_) {
                            if (errorText != null) setState(() => errorText = null);
                          },
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (maxTransferable > 0) ...[
                              _QuickAmountChip(
                                label: service.t('quarter'),
                                onTap: () => applyQuickAmount(maxTransferable * 0.25),
                              ),
                              _QuickAmountChip(
                                label: service.t('half'),
                                onTap: () => applyQuickAmount(maxTransferable * 0.5),
                              ),
                              _QuickAmountChip(
                                label: service.t('full_remaining'),
                                icon: Icons.bolt_rounded,
                                onTap: () => applyQuickAmount(maxTransferable.toDouble()),
                                emphasized: true,
                              ),
                            ] else
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 15, color: AppColors.danger),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(service.t('insufficient_balance'),
                                      style: TextStyle(color: AppColors.danger, fontSize: 12.5))),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: AppColors.border, width: 1.3),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                                ),
                                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                                child: Text(service.t('cancel'),
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  gradient: LinearGradient(
                                    colors: [AppColors.accentDeep, AppColors.accentDeep.withOpacity(0.82)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentDeep.withOpacity(0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                                  ),
                                  onPressed: submitting ? null : submit,
                                  child: submitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.savings_rounded, size: 18, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text(service.t('transfer'),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )),
            ),
          ));
        },
      );
    },
  );
}

/// การ์ดข้อมูลเล็กๆ (Ledger คงเหลือ / ต้องการอีก)
class _InfoStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color iconColor;

  const _InfoStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// ชิปเลือกจำนวนเงินด่วน (25% / 50% / เต็มจำนวนที่ขาด)
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final IconData? icon;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.accentDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: emphasized ? Colors.white : AppColors.accentDeep),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: emphasized ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 13.28 flutter_application_1/lib/screens/history_screen.dart

หน้าประวัติรายการ ใช้ DataService.transactions และตัวกรองเพื่อสร้างรายการ เปิดรายละเอียดผ่าน showTransactionDetails และรองรับ refresh

โครงสร้างที่ประกาศ: class HistoryScreen extends StatefulWidget (L12); class _HistoryScreenState extends State<HistoryScreen> (L19)

157 บรรทัด • SHA-256: 057d4d05dfed3ef0

```dart
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';

/// หน้า History (3.4.7) - แสดงประวัติการทำรายการ พร้อมตัวกรอง All / Daily
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final all = service.transactions;
    final today = DateTime.now();
    final list = _showAll ? all : service.transactionsForDay(today);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('history'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filterChip(service.t('filter_all'), _showAll, () => setState(() => _showAll = true)),
                const SizedBox(width: 8),
                _filterChip(service.t('filter_daily'), !_showAll, () => setState(() => _showAll = false)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: list.isEmpty
                  // ListView ว่างเปล่ายังต้องใส่ physics แบบ Always... ไม่งั้นจะดึง
                  // เพื่อรีเฟรชไม่ได้เลยเพราะไม่มีเนื้อหาให้เลื่อน
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                            icon: Icons.receipt_long_outlined,
                            text: service.t('no_transactions')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = list[index];
                        return _transactionTile(context, t, service);
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDeep : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _transactionTile(
      BuildContext context, TransactionModel t, DataService service) {
    final isIncome = t.type == CategoryType.income;
    return Dismissible(
      key: ValueKey(t.id),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
                    try {
                      await service.deleteTransaction(t.id);
                      return true;
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${service.t('save_failed')}: $e')));
                      return false;
                    }
                  },
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
            child: CategoryIcon(category: t.category,
                color: isIncome ? AppColors.income : AppColors.expense),
          ),
          title: Text(service.categoryName(t.category),
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          subtitle: Text(
              '${DateFormat('d MMM yyyy').format(t.date)}${t.note != null ? ' • ${t.note}' : ''}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: Text(
            '${isIncome ? '+' : '-'}${service.formatMoney(t.amount)}',
            style: TextStyle(
              color: isIncome ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
```

### 13.29 flutter_application_1/lib/screens/home_screen.dart

หน้าภาพรวม สร้างชุดข้อมูลกราฟรายวัน/เดือน/ปีจาก DataService แสดงเป้าหมายที่ปักหมุดและทางลัด มีส่วน header และการรีเฟรชข้อมูล

โครงสร้างที่ประกาศ: class _IncomeExpensePoint (L28); class HomeScreen extends StatefulWidget (L38); class _HomeScreenState extends State<HomeScreen> (L45); class _LegendDot extends StatelessWidget (L431); class _SkyHeader extends StatelessWidget (L461); class _SkyTimeIcon extends StatelessWidget (L565); class _ActionButton extends StatelessWidget (L595); class _PinnedGoalCard extends StatelessWidget (L689)

742 บรรทัด • SHA-256: 572774f138241a01

```dart
import '../models/goal_model.dart';
import 'add_goal_saving_screen.dart';
import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/goal_saving_screen.dart';
import 'package:budgetmate/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'history_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// จุดข้อมูลสำหรับกราฟแท่งคู่ (รายรับ vs รายจ่าย) ต่อหนึ่งช่วงเวลา (วัน/เดือน/ปี)
class _IncomeExpensePoint {
  final String label;
  final double income;
  final double expense;
  const _IncomeExpensePoint(this.label, this.income, this.expense);
}

/// หน้า Home (3.4.6) - แสดงภาพรวมทางการเงินของผู้ใช้งาน
/// ดีไซน์ v3 "Sky Fintech": ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมน + Avatar/กระดิ่งแจ้งเตือน
/// และเพิ่มส่วน "Pinned Goals" แสดงเป้าหมายการออมล่าสุดแบบการ์ดสีพาสเทล
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  // สีของแท่งกราฟ "รายรับ" / "รายจ่าย" — ใช้สีจาก AppColors.income / AppColors.expense
  // ที่มีอยู่แล้วในธีม (app_theme.dart) ตรงกับสีที่ใช้แสดงรายรับ/รายจ่ายในหน้าอื่นๆ
  // ของแอปอยู่แล้ว (เช่นหน้า History/Statistic) ทำให้สีสื่อความหมายตรงกันทั้งแอป
  static Color get _incomeColorDeep => AppColors.income;
  static Color get _incomeColorLight => AppColors.income.withOpacity(0.55);
  static Color get _expenseColorDeep => AppColors.expense;
  static Color get _expenseColorLight => AppColors.expense.withOpacity(0.55);

  /// ดึงข้อมูลรายรับ-รายจ่ายตามช่วงเวลาที่เลือก (วัน/เดือน/ปี) สำหรับกราฟแท่งคู่
  List<_IncomeExpensePoint> _incomeExpenseSeries(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data
            .map((e) => _IncomeExpensePoint(
                  '${e.key.day}/${e.key.month}',
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data
            .map((e) => _IncomeExpensePoint(
                  months[e.key.month - 1],
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data
            .map((e) => _IncomeExpensePoint(
                  '${e.key}',
                  e.value['income'] ?? 0,
                  e.value['expense'] ?? 0,
                ))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final homeGoals = service.pinnedGoals;
    final series = _incomeExpenseSeries(service);
    final maxVal = series
        .expand((e) => [e.income, e.expense])
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      // _SkyHeader อยู่นอก RefreshIndicator/SingleChildScrollView โดยตั้งใจ เพื่อให้
      // Header ตรึงอยู่บนสุดเสมอ (เหมือนหน้า Statistic/History) — ถ้าเอา Header ไปไว้
      // เป็นลูกของเนื้อหาที่เลื่อนได้ ตอนดึงลงมารีเฟรชเนื้อหาทั้งหมด (รวม Header) จะถูก
      // ดันลงมาด้วย จะเห็นพื้นหลังเปล่าของ Scaffold (สีขาวอมฟ้าอ่อน) โผล่มาด้านบนแทน
      body: Column(
        children: [
          _SkyHeader(service: service),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                // ต้องใช้ AlwaysScrollableScrollPhysics ไม่งั้นถ้าเนื้อหาสั้นกว่าจอ
                // จะดึงเพื่อรีเฟรชไม่ได้เลย
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: EdgeInsets.zero,
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppLayout.pageInset(context), 12, AppLayout.pageInset(context), 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(service.t('expense_trend'), style: AppTextStyles.heading),
                      const SizedBox(width: 6),
                      Icon(Icons.show_chart_rounded, size: 15, color: AppColors.accentDeep),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PeriodFilterBar(
                    period: _period,
                    anchor: _anchor,
                    onPeriodChanged: (p) => setState(() => _period = p),
                    onAnchorChanged: (d) => setState(() => _anchor = d),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (maxVal != 0) ...[
                          Row(
                            children: [
                              const Spacer(),
                              _LegendDot(
                                color: _incomeColorDeep,
                                label: service.currentLanguage != 'English'
                                    ? 'รายรับ'
                                    : 'Income',
                              ),
                              const SizedBox(width: 14),
                              _LegendDot(
                                color: _expenseColorDeep,
                                label: service.currentLanguage != 'English'
                                    ? 'รายจ่าย'
                                    : 'Expense',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          height: AppLayout.chartHeight(context),
                          child: maxVal == 0
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CuteMascot(
                                          kind: CuteMascotKind.income,
                                          size: 30,
                                          color: AppColors.accent),
                                      const SizedBox(height: 10),
                                      Text(
                                        service.t('no_expense_data'),
                                        style: TextStyle(
                                            color: AppColors.textSecondary, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                )
                              : BarChart(
                            BarChartData(
                              maxY: maxVal == 0 ? 100 : maxVal * 1.2,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              groupsSpace: 18,
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= series.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(series[idx].label,
                                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(series.length, (i) {
                                final p = series[i];
                                return BarChartGroupData(
                                  x: i,
                                  barsSpace: 4,
                                  barRods: [
                                    BarChartRodData(
                                      toY: p.income,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [_incomeColorDeep, _incomeColorLight],
                                      ),
                                      width: 12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    BarChartRodData(
                                      toY: p.expense,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [_expenseColorDeep, _expenseColorLight],
                                      ),
                                      width: 12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== ปุ่มกระเป๋าตัง / กระปุกออมสิน =====
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.account_balance_wallet_rounded,
                          artwork: const PastelArtwork(categoryNumber: 14, size: 26),
                          label: service.t('wallet_title'),
                          iconBg: AppColors.accentDeep,
                          cardBg: AppColors.accentBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const WalletScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.savings_rounded,
                          artwork: const PastelArtwork(categoryNumber: 17, size: 26),
                          label: service.t('goal_saving'),
                          iconBg: AppColors.accentPink,
                          cardBg: AppColors.accentAltBg,
                          onTap: () => Navigator.push(
                            context,
                            noAnimationRoute(const GoalSavingScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  ...[
                    Row(
                      children: [
                        Expanded(
                          child: Row(children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(service.t('goal_saving'),
                                    style: AppTextStyles.heading, maxLines: 1, softWrap: false),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.push_pin_rounded, size: 15, color: AppColors.accentPink),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context, noAnimationRoute(const GoalSavingScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  service.currentLanguage != 'English' ? 'ดูทั้งหมด' : 'See all',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 15, color: AppColors.accentDeep),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (homeGoals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.push_pin_outlined,
                                size: 23, color: AppColors.ink),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  key: Key(service.goals.isEmpty
                                    ? 'home-add-goal' : 'home-pin-goal'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.ink,
                                    backgroundColor: AppColors.accentBg,
                                    side: BorderSide.none,
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    textStyle: AppTextStyles.label,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  ),
                                  onPressed: () => Navigator.push(context,
                                    noAnimationRoute(service.goals.isEmpty
                                      ? const AddGoalSavingScreen()
                                      : const GoalSavingScreen())),
                                  icon: Icon(service.goals.isEmpty
                                    ? Icons.add_rounded : Icons.push_pin_outlined, size: 17),
                                  label: Text(service.currentLanguage != 'English'
                                    ? (service.goals.isEmpty ? 'สร้างเป้าหมาย' : 'เลือกเป้าหมาย')
                                    : (service.goals.isEmpty ? 'Create a goal' : 'Choose a goal')),
                                ),
                              ],
                            )),
                          ],
                        ),
                      )
                    else Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(homeGoals.length, (i) => SizedBox(
                        width: (MediaQuery.sizeOf(context).width - AppLayout.pageInset(context) * 2 - 12) / 2,
                        child: _PinnedGoalCard(
                          goal: homeGoals[i],
                          bg: AppColors.pinnedGoalBg[i % AppColors.pinnedGoalBg.length],
                          onTap: () => Navigator.push(context, noAnimationRoute(const GoalSavingScreen())),
                        ),
                      )),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),



                ],
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }
}

/// จุดสีเล็กๆ พร้อม label ใช้เป็น legend อธิบายสีแท่งกราฟรายรับ/รายจ่าย
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// ส่วนหัวไล่เฉดฟ้าพาสเทลโค้งมนด้านล่าง: รูปโปรไฟล์ + คำทักทาย + กระดิ่งแจ้งเตือน (ไปหน้า History)
///
/// อัปเดต: รูปโปรไฟล์ตอนนี้ลอง decode จาก `service.currentUser.avatarBase64`
/// (Base64 string ที่เก็บอยู่ใน Firestore) ก่อนเป็นอันดับแรก เพราะเป็นแหล่งข้อมูลจริง
/// ที่ผูกกับบัญชีและตามไปทุกเครื่องที่ล็อกอิน ถ้ายังไม่มี (เช่นยังไม่เคยตั้งรูป) จะ
/// fallback ไปที่ไฟล์แคชในเครื่อง (avatarPath) แล้วค่อย fallback สุดท้ายเป็นไอคอนคน
/// default — เดิมโค้ดจุดนี้ดูแค่ avatarPath (ไฟล์ในเครื่อง) อย่างเดียว ทำให้เปลี่ยน
/// มือถือเครื่องใหม่แล้วเห็นแต่ไอคอน default เสมอ
class _SkyHeader extends StatelessWidget {
  final DataService service;
  const _SkyHeader({required this.service});

  @override
  Widget build(BuildContext context) {
    final avatarBase64 = service.currentUser?.avatarBase64;
    final avatarPath = service.avatarPath;
    final hasLocalImage = avatarPath != null && File(avatarPath).existsSync();

    ImageProvider? avatarImage;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarBase64));
      } catch (_) {
        avatarImage = null;
      }
    }
    if (avatarImage == null && hasLocalImage) {
      avatarImage = FileImage(File(avatarPath));
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 4, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentDeep.withOpacity(0.9), AppColors.accent, AppColors.bg],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ประกายดาวเล็กๆ ตกแต่งมุมบน ให้ดูสดใสมีชีวิตชีวาแบบภาพอ้างอิง
          Positioned(
            right: 70,
            top: 2,
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white.withOpacity(0.85)),
          ),
          Positioned(
            right: 96,
            top: 22,
            child: Icon(Icons.auto_awesome_rounded,
                size: 9, color: Colors.white.withOpacity(0.6)),
          ),
          // ไอคอนพระอาทิตย์ (กลางวัน) / พระจันทร์ (กลางคืน) เปลี่ยนตามเวลาจริงของเครื่อง
          // ให้ธีม "ท้องฟ้า" ของ Header มีความหมายจริงๆ ไม่ใช่แค่ไล่เฉดสีเฉยๆ
          const Positioned(
            right: 46,
            top: 4,
            child: _SkyTimeIcon(),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(Icons.person, color: AppColors.accentDeep, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${service.t('greeting')}, ${service.currentUser?.name ?? service.t('default_user')} 👋',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF3D568F)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Reserve room for the sky decoration instead of painting over names.
              const SizedBox(width: 42),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, noAnimationRoute(const HistoryScreen())),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.notifications_rounded, color: AppColors.accentDeep, size: 21),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ไอคอนพระอาทิตย์ (กลางวัน) หรือพระจันทร์ (กลางคืน) เปลี่ยนตามเวลาจริงของเครื่อง
/// เป็นรายละเอียดเล็กๆ ที่ทำให้ธีม "ท้องฟ้า" ของ Header มีความหมายจริงมากกว่า
/// แค่ไล่เฉดสีเฉยๆ — กลางวัน (06:00-18:00) โชว์พระอาทิตย์โทนเหลืองพาสเทล
/// นอกเวลานั้นโชว์พระจันทร์โทนม่วงลาเวนเดอร์พาสเทล
class _SkyTimeIcon extends StatelessWidget {
  const _SkyTimeIcon();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;
    final Color glow = isDay ? const Color(0xFFFFE698) : const Color(0xFFEFE7FA);
    final Color iconColor = isDay ? const Color(0xFFC79A3B) : const Color(0xFF8B6FC4);

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: glow.withOpacity(0.55), shape: BoxShape.circle),
          ),
          Icon(isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 18, color: iconColor),
        ],
      ),
    );
  }
}


class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Widget? artwork;
  final String label;
  final Color iconBg;
  final Color cardBg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.artwork,
    required this.label,
    required this.iconBg,
    required this.cardBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: iconBg.withOpacity(0.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ฟองสบู่ตกแต่งมุมขวาบน ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
                Positioned(
                  right: -14,
                  top: -16,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(color: iconBg.withOpacity(0.14), shape: BoxShape.circle),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      artwork ?? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(icon, size: 20, color: iconBg),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดเป้าหมายการออมแบบพาสเทล ใช้กับส่วน "Pinned Goals" ในหน้า Home
class _PinnedGoalCard extends StatelessWidget {
  final GoalModel goal;
  final Color bg;
  final VoidCallback onTap;
  const _PinnedGoalCard({required this.goal, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final bool near = goal.isNearTarget;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: GoalArtwork(goal.icon, artworkNumber: goal.artworkNumber, size: 14, color: AppColors.pinnedGoalIcon),
                ),
                const Spacer(),
                if (near)
                  Icon(Icons.star_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              ],
            ),
            const SizedBox(height: 6),
            Text(goal.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3D568F)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(service.formatMoney(goal.targetAmount),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6E7FA3))),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.6),
                color: AppColors.accentDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 13.30 flutter_application_1/lib/screens/income expense overview.dart

แสดงกราฟวงกลมและรายการจากตัวกรองเดียวกัน มีประเภทและปฏิทิน รวมยอดด้วย key ประเภท+หมวด และเปิดรายละเอียดรายการเมื่อเลือก

โครงสร้างที่ประกาศ: class IncomeExpenseOverview extends StatefulWidget (L30); class _IncomeExpenseOverviewState (L44); enum HistoryFilter (L856)

860 บรรทัด • SHA-256: 6dbeb4472057f343

```dart
import 'transaction_details_sheet.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;

const _palette = [
  Color(0xFF80A1D4),
  Color(0xFFC08B9D),
  Color(0xFFC1E4F3),
  Color(0xFFFFE698),
  Color(0xFF3D568F),
  Color(0xFFE3B8C4),
  Color(0xFF9BC4E0),
  Color(0xFFEAD9A0),
];

/// วิดเจ็ตแสดง
/// 1. Pie Chart สัดส่วนรายจ่าย
/// 2. ประวัติรายการ
/// 3. ตัวกรอง ทั้งหมด / รายรับ / รายจ่าย
/// 4. ปฏิทินสำหรับดูรายการรายรับ/รายจ่ายในแต่ละวัน
class IncomeExpenseOverview extends StatefulWidget {
  /// ตัวกรองเริ่มต้นตอนเปิดหน้า (ใช้ตอนกดมาจากกล่องรายรับ/รายจ่ายในหน้า Wallet)
  final HistoryFilter initialFilter;

  const IncomeExpenseOverview({
    super.key,
    this.initialFilter = HistoryFilter.all,
  });

  @override
  State<IncomeExpenseOverview> createState() =>
      _IncomeExpenseOverviewState();
}

class _IncomeExpenseOverviewState
    extends State<IncomeExpenseOverview> {
  // ============================================================
  // ประเภทของ History
  // ============================================================

  late HistoryFilter _historyFilter;

  // วันที่เลือกในปฏิทิน
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _historyFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    // ============================================================
    // PIE CHART
    // ============================================================

    // Aggregate exactly the transactions shown by the active type/date filter.
    final historyList = _getHistoryList(service.transactions);
    final byCategory = <String, MapEntry<CategoryModel, double>>{};
    for (final transaction in historyList) {
      final key = '${transaction.type.name}:${transaction.category.id}';
      final previous = byCategory[key]?.value ?? 0;
      byCategory[key] = MapEntry(transaction.category, previous + transaction.amount);
    }
    final entries = byCategory.values.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final isThai = service.currentLanguage != 'English';
    final chartTitle = switch (_historyFilter) {
      HistoryFilter.all => isThai ? 'สัดส่วนรายรับและรายจ่าย · ทุกวัน' : 'Income and expenses · All dates',
      HistoryFilter.income => isThai ? 'สัดส่วนรายรับ' : 'Income breakdown',
      HistoryFilter.expense => isThai ? 'สัดส่วนรายจ่าย' : 'Expense breakdown',
    };

    return Column(
      children: [
        // ========================================================
        // PIE CHART
        // ========================================================

        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              0,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chartTitle, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text('${isThai ? 'ยอดรวม' : 'Total'} ${service.formatMoney(total)}',
                  key: const Key('overview-chart-total'), style: AppTextStyles.caption),
                const SizedBox(height: 8),
                SizedBox(
                height: 128,
                child: Row(
                  children: [
                    // ==================================================
                    // PIE
                    // ==================================================

                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 22,

                          sections: List.generate(
                            entries.length,
                            (i) {
                              final e = entries[i];

                              final pct = total == 0
                                  ? 0.0
                                  : (e.value / total) * 100;

                              return PieChartSectionData(
                                color: _palette[
                                    i % _palette.length],

                                value: e.value,

                                title: pct < 3 ? '' : _percentage(pct),

                                radius: 44,

                                titleStyle:
                                    const TextStyle(
                                  color: Color(0xFF283350),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // LEGEND
                    // ==================================================

                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,

                        itemBuilder: (context, i) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _palette[
                                        i % _palette.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),

                                const SizedBox(width: 6),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(service.categoryName(entries[i].key),
                                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text('${entries[i].key.type == CategoryType.income ? '+' : '-'}${service.formatMoney(entries[i].value)}',
                                            style: AppTextStyles.caption),
                                          const SizedBox(width: 6),
                                          Text(_percentage(entries[i].value / total * 100),
                                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ]),
            ),
          )
        else
          EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            text: _historyFilter == HistoryFilter.all
              ? (isThai ? 'ยังไม่มีรายการ' : 'No transactions yet')
              : service.t(_historyFilter == HistoryFilter.income ? 'no_income_data' : 'no_expense_data'),
          ),

        const SizedBox(height: 10),

        // ========================================================
        // HISTORY HEADER + MENU
        // ========================================================

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.t('history'), style: AppTextStyles.heading),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: _historyMenu(service))),
          ]),
        ),

        const SizedBox(height: 10),

        // ========================================================
        // CONTENT
        // ========================================================

        Expanded(
          child: _historyFilter == HistoryFilter.all
              ? _buildAllHistory(
                  historyList,
                )
              : _buildFilteredHistory(
                  historyList,
                  service,
                ),
        ),
      ],
    );
  }

  // ==============================================================
  // HISTORY MENU
  // ==============================================================

  String _percentage(double value) => value < 0.1 ? '<0.1%' : '${value.toStringAsFixed(1)}%';

  Widget _historyMenu(DataService service) {
    return Container(
      padding: const EdgeInsets.all(3),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius: BorderRadius.circular(
          AppRadius.pill,
        ),

        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _historyMenuItem(
            label: service.t('all'),
            selected: _historyFilter == HistoryFilter.all,
            onTap: () {
              setState(() {
                _historyFilter = HistoryFilter.all;
              });
            },
          ),

          _historyMenuItem(
            label: service.t('income'),
            selected:
                _historyFilter == HistoryFilter.income,
            onTap: () {
              setState(() {
                _historyFilter =
                    HistoryFilter.income;

                // เมื่อเข้าเมนูรายรับ
                // ให้ใช้วันที่วันนี้เป็นค่าเริ่มต้น
                _selectedDate = DateTime.now();
              });
            },
          ),

          _historyMenuItem(
            label: service.t('expense'),
            selected:
                _historyFilter == HistoryFilter.expense,
            onTap: () {
              setState(() {
                _historyFilter =
                    HistoryFilter.expense;

                // เมื่อเข้าเมนูรายจ่าย
                // ให้ใช้วันที่วันนี้เป็นค่าเริ่มต้น
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // HISTORY MENU ITEM
  // ==============================================================

  Widget _historyMenuItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentDeep
              : Colors.transparent,

          borderRadius: BorderRadius.circular(
            AppRadius.pill,
          ),
        ),

        child: Text(
          label,

          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.textPrimary,

            fontWeight: FontWeight.w600,

            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // GET HISTORY LIST
  // ==============================================================

  List<TransactionModel> _getHistoryList(
    List<TransactionModel> transactions,
  ) {
    switch (_historyFilter) {
      case HistoryFilter.all:
        return transactions;

      case HistoryFilter.income:
        return transactions
            .where(
              (t) =>
                  t.type == CategoryType.income && _isSameDay(t.date, _selectedDate),
            )
            .toList();

      case HistoryFilter.expense:
        return transactions
            .where(
              (t) =>
                  t.type == CategoryType.expense && _isSameDay(t.date, _selectedDate),
            )
            .toList();
    }
  }

  // ==============================================================
  // ALL HISTORY
  // ==============================================================

  Widget _buildAllHistory(
    List<TransactionModel> list,
  ) {
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'ยังไม่มีรายการ',
      );
    }

    return RefreshIndicator(
      color: AppColors.accentDeep,
      backgroundColor: AppColors.card,
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),

        children: _buildGroupedHistory(
          list,
        ),
      ),
    );
  }

  // ==============================================================
  // FILTERED HISTORY
  //
  // รายรับ / รายจ่าย
  // แสดง Calendar + รายการของวันที่เลือก
  // ==============================================================

  Widget _buildFilteredHistory(
    List<TransactionModel> list,
    DataService service,
  ) {

    return RefreshIndicator(
      color: AppColors.accentDeep,
      backgroundColor: AppColors.card,
      onRefresh: _onRefresh,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),

      children: [
        // ====================================================
        // ปุ่มเลือกวันที่ (เม็ดยา) — กดแล้วเปิดปฏิทินป๊อปอัพ
        // สไตล์เดียวกับหน้าแรก/หน้าสถิติ (PeriodFilterBar._pickDay)
        // ====================================================

        _dateSelectorPill(service),

        const SizedBox(height: 10),

        if (list.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            text: 'ไม่มีรายการในวันนี้',
          )
        else
          ...list.map(
            (t) => Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: _historyTile(t),
            ),
          ),
      ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }

  // ==============================================================
  // ปุ่มเม็ดยาแสดงวันที่ที่เลือก (เหมือนหน้าแรก/หน้าสถิติ)
  // ==============================================================

  Widget _dateSelectorPill(DataService service) {
    final dateText = DateFormat(
      'd MMM yyyy',
      'th',
    ).format(_selectedDate);

    return GestureDetector(
      onTap: () => _pickDate(context, service),

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(
            AppRadius.pill,
          ),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),

            const SizedBox(width: 8),

            Text(
              dateText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(width: 6),

            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // ปฏิทินป๊อปอัพ — ใช้การ์ดพาสเทล "เลือกวันที่" ชุดเดียวกับหน้าแรก/สถิติ
  // (PastelCalendarDialog จาก widgets/period_selector.dart) เพื่อให้หน้าตา
  // เหมือนกันทุกจุดในแอป ไม่มีปฏิทินคนละแบบให้สับสน
  // ==============================================================

  Future<void> _pickDate(BuildContext context, DataService service) async {
    final isThai = service.currentLanguage != 'English';

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelCalendarDialog(
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ==============================================================
  // GROUPED HISTORY
  //
  // ใช้เฉพาะเมนู "ทั้งหมด"
  // ==============================================================

  List<Widget> _buildGroupedHistory(
    List<TransactionModel> list,
  ) {
    final widgets = <Widget>[];

    DateTime? currentDay;

    for (final t in list) {
      final day = DateTime(
        t.date.year,
        t.date.month,
        t.date.day,
      );

      if (currentDay == null ||
          day != currentDay) {
        if (currentDay != null) {
          widgets.add(
            const SizedBox(height: 8),
          );
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              top: 4,
            ),

            child: Text(
              _dayLabel(day),

              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );

        currentDay = day;
      }

      widgets.add(
        _historyTile(t),
      );

      widgets.add(
        const SizedBox(height: 8),
      );
    }

    return widgets;
  }

  // ==============================================================
  // DAY LABEL
  // ==============================================================

  String _dayLabel(
    DateTime day,
  ) {
    final service =
        context.read<DataService>();

    final today = DateTime.now();

    final todayDay = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final yesterday =
        todayDay.subtract(
      const Duration(days: 1),
    );

    if (_isSameDay(day, todayDay)) {
      return service.t('today');
    }

    if (_isSameDay(day, yesterday)) {
      return service.t('yesterday');
    }

    return DateFormat(
      'd MMM yyyy',
    ).format(day).toUpperCase();
  }

  // ==============================================================
  // HISTORY TILE
  // ==============================================================

  Widget _historyTile(
    TransactionModel t,
  ) {
    final service =
        context.read<DataService>();

    final isIncome =
        t.type == CategoryType.income;

    // ============================================================
    // รายรับ = เขียว
    // รายจ่าย = แดง
    // ============================================================

    final accent = isIncome
        ? AppColors.income
        : AppColors.expense;

    final accentBg = isIncome
        ? AppColors.incomeBg
        : AppColors.expenseBg;

    return GestureDetector(
      onTap: () => showTransactionDetails(context, t),
      child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius: BorderRadius.circular(
          AppRadius.lg,
        ),

        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          // ======================================================
          // ICON
          // ======================================================

          CircleAvatar(
            radius: 15,

            backgroundColor: accentBg,

            child: CategoryIcon(
              category: t.category,
              color: accent,
              size: 15,
            ),
          ),

          const SizedBox(width: 10),

          // ======================================================
          // NAME + TIME
          // ======================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  service.categoryName(
                    t.category,
                  ),

                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),

                if (t.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(t.note!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 2),

                Text(
                  DateFormat(
                    'HH:mm',
                  ).format(t.date),

                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // AMOUNT
          // ======================================================

          Text(
            '${isIncome ? '+' : '-'}${context.watch<DataService>().formatMoney(t.amount)}',

            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: accent,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: service.currentLanguage == 'English' ? 'Manage transaction' : 'จัดการรายการ',
            onPressed: () => showTransactionDetails(context, t),
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.ink, size: 18),
          ),
        ],
      ),
    ));
  }

  // ==============================================================
  // SAME DAY
  // ==============================================================

  bool _isSameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

// ==================================================================
// HISTORY FILTER
// ==================================================================

enum HistoryFilter {
  all,
  income,
  expense,
}
```

### 13.31 flutter_application_1/lib/screens/income_expense_screen.dart

โครงหน้า Scaffold ครอบ IncomeExpenseOverview ส่ง initialFilter และจัดปุ่มกลับกับ BottomNav ตัวกราฟและประวัติอยู่ไฟล์ overview

โครงสร้างที่ประกาศ: class IncomeExpenseScreen extends StatelessWidget (L10)

45 บรรทัด • SHA-256: c74855a81cffdbea

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:budgetmate/screens/income%20expense%20overview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'wallet_screen.dart';

/// หน้า Income/Expense (3.4.9)
class IncomeExpenseScreen extends StatelessWidget {
  /// ตัวกรองเริ่มต้นตอนเปิดหน้า (ทั้งหมด / รายรับ / รายจ่าย)
  final HistoryFilter initialFilter;

  const IncomeExpenseScreen({
    super.key,
    this.initialFilter = HistoryFilter.all,
  });

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
          context, noAnimationRoute(const WalletScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: service.t('income_expense'),
            onBack: () => _handleBack(context),
          ),
          Expanded(child: IncomeExpenseOverview(initialFilter: initialFilter)),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
```

### 13.32 flutter_application_1/lib/screens/language_setup_screen.dart

อ่านค่าภาษา/สกุลเงินเดิม ให้ preview ก่อนบันทึก completeSetup แล้วไป Login หรือ Home ตาม session; ไม่เขียนค่าทุกครั้งที่เปลี่ยนตัวเลือก

โครงสร้างที่ประกาศ: class LanguageSetupScreen extends StatefulWidget (L13); class _LanguageSetupScreenState extends State<LanguageSetupScreen> (L20)

168 บรรทัด • SHA-256: 499589a1a3857f59

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/app_strings.dart';

const List<String> _languages = ['ไทย', 'English'];
const List<String> _currencies = ['THB'];

/// หน้า "My wallet" (3.4.2) - ตั้งค่าภาษาและสกุลเงินเริ่มต้นของแอป
class LanguageSetupScreen extends StatefulWidget {
  const LanguageSetupScreen({super.key});

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  String _language = 'ไทย';
  String _currency = 'THB';
  bool _saving = false;
  bool _loading = true;
  String? _error;

  String _t(String key) => AppStrings.of(_language)[key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final service = context.read<DataService>();
    try {
      final defaults = await service.getDefaultPreferences();
      if (!mounted) return;
      final language = service.currentUser?.language ?? defaults['language'];
      final currency = service.currentUser?.currency ?? defaults['currency'];
      setState(() {
        _language = _languages.contains(language) ? language! : 'ไทย';
        _currency = _currencies.contains(currency) ? currency! : 'THB';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _next() async {
    if (_saving || _loading) return;
    setState(() { _saving = true; _error = null; });
    final service = context.read<DataService>();
    try {
      await service.completeSetup(language: _language, currency: _currency);
      if (!mounted) return;
      Navigator.pushReplacement(context, noAnimationRoute(
        service.currentUser == null ? const LoginScreen() : const HomeScreen()));
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = '${_t('save_failed')}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HeaderIconBadge(icon: Icons.tune_rounded),
                const SizedBox(height: 16),
                Text(_t('setup_title'),
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(_t('setup_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 28),
                _dropdownRow(
                  icon: Icons.language_rounded,
                  label: _t('language_label'),
                  value: _language,
                  items: _languages,
                  onChanged: (v) {
                    if (v != null) setState(() => _language = v);
                  },
                ),
                const SizedBox(height: 12),
                _dropdownRow(
                  icon: Icons.payments_outlined,
                  label: _t('currency_label'),
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: _t('next'),
                    loading: _saving || _loading,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownRow({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                dropdownColor: AppColors.bg,
                style: TextStyle(color: AppColors.textPrimary),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _saving || _loading ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 13.33 flutter_application_1/lib/screens/loading_screen.dart

หน้าเริ่มต้นจริงจาก main เรียก DataService.init รอเวลาขั้นต่ำแล้วเลือก Home/Login; _LoadingDots เป็น animation ประกอบหน้า

โครงสร้างที่ประกาศ: class LoadingScreen extends StatefulWidget (L9); class _LoadingScreenState extends State<LoadingScreen> (L16); class _LoadingDots extends StatefulWidget (L109); class _LoadingDotsState extends State<_LoadingDots> (L116)

169 บรรทัด • SHA-256: 80e858cbb36d68b6

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// เตรียมข้อมูลและกู้คืนบัญชีก่อนเข้าสู่แอป
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = context.read<DataService>();
    final started = DateTime.now();

    await service.init(); // สร้างตาราง/seed หมวดหมู่ + กู้คืน session (จะตั้งค่า AppColors.brightness ให้ด้วย)

    final elapsed = DateTime.now().difference(started);
    final remain = const Duration(milliseconds: 1200) - elapsed;
    if (remain > Duration.zero) {
      await Future.delayed(remain);
    }

    if (!mounted) return;

    Widget nextScreen;
    if (service.currentUser != null) {
      nextScreen = const HomeScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      noAnimationRoute(nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 240,
                height: 232,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 218, height: 218,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFF6F9FF),
                        const Color(0xFFDCEEF7),
                        AppColors.accentBg.withValues(alpha: 0.15),
                      ], stops: const [0.35, 0.78, 1]),
                    ),
                  ),
                  Image.asset(
                    'assets/images/loading.gif',
                    width: 160, height: 160,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text(service.t('app_name'), textAlign: TextAlign.center,
                style: TextStyle(fontFamily: appFontFamily, fontSize: 21,
                  fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(isThai ? '' : 'Little savings, lovely possibilities',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(fontSize: 13)),
              const SizedBox(height: 22),
              Semantics(
                label: isThai ? 'กำลังเตรียมข้อมูล' : 'Loading your data',
                child: const ExcludeSemantics(child: _LoadingDots()),
              ),
              const SizedBox(height: 12),
              Text(isThai ? 'รอสักครู่นะ…' : 'Just a moment…',
                textAlign: TextAlign.center, style: AppTextStyles.caption),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = (_controller.value - index * 0.18) % 1.0;
          final opacity = reduceMotion ? 0.7 : 0.3 + 0.7 *
              Curves.easeInOut.transform(1 - (phase * 2 - 1).abs());
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.ink, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}
```

### 13.34 flutter_application_1/lib/screens/login_screen.dart

ฟอร์มอีเมล/รหัสผ่านและ Google Sign-In จัดการ loading/error เมื่อสำเร็จล้าง navigation stack; Google บัญชีใหม่ไปตั้งค่า ส่วนบัญชีเดิมไป Home มี AuthTabToggle ใช้ร่วมกับหน้าสมัคร

โครงสร้างที่ประกาศ: class LoginScreen extends StatefulWidget (L18); class _LoginScreenState extends State<LoginScreen> (L25); class _GlowBadge extends StatelessWidget (L250); class _PastelBlob extends StatelessWidget (L282); class AuthTabToggle extends StatefulWidget (L334); class _AuthTabToggleState extends State<AuthTabToggle> (L354)

451 บรรทัด • SHA-256: 7f364d90708c8598

```dart
import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'language_setup_screen.dart';

/// หน้า Login (3.4.3) - เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน (ตรวจสอบกับ SQLite จริง)
///
/// ปรับดีไซน์ให้เข้าชุดเดียวกับหน้า Register / Forgot Password:
/// - ใช้โครงหน้า HeaderIconBadge + title + subtitle เหมือนกันทั้ง 3 หน้า auth
/// - เปลี่ยนปุ่มสลับ "เข้าสู่ระบบ/สมัครสมาชิก" จากกล่องสีทึบ 2 กล่อง
///   มาเป็น pill segmented toggle แบบเดียวกับที่ใช้ทั่วแอป
///   (เทียบ _filterChip ใน history_screen.dart, _periodChip ใน period_selector.dart)
/// - ใช้ AppTextStyles.title ให้สัดส่วนตัวอักษรตรงกับหน้าอื่น
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;
  bool _googleLoading = false;

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
          context, noAnimationRoute(const HomeScreen()), (route) => false);
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.loginWithGoogle();

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
          context,
          noAnimationRoute(service.googleLoginCreatedAccount
              ? const LanguageSetupScreen()
              : const HomeScreen()),
          (route) => false);
    } else {
      setState(() {
        _googleLoading = false;
        _error = error;
      });
    }
  }

  void _goToRegister() {
    Navigator.push(context, noAnimationRoute(const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ก้อนสีพาสเทลลอยด้านหลัง เพิ่มความน่ารักให้พื้นหลัง
          const _PastelBlob(
            top: -60,
            right: -50,
            size: 170,
          ),
          const _PastelBlob(
            bottom: -70,
            left: -60,
            size: 190,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // ไอคอนหัวข้อพร้อมแสงเรืองสีพาสเทลด้านหลัง ให้ดูนุ่มนวลน่ารักขึ้น
                    Center(
                      child: _GlowBadge(
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('app_name'),
                        textAlign: TextAlign.center, style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(service.t('login_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                    const SizedBox(height: 26),

                    // การ์ดฟอร์มโค้งมนลอยตัว ให้ความรู้สึกนุ่มนวลอบอุ่นกว่าเดิม
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md + 8),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // สลับ เข้าสู่ระบบ/สมัครสมาชิก แบบ pill segmented ที่เลื่อนได้จริง
                          AuthTabToggle(
                            loginLabel: service.t('login'),
                            registerLabel: service.t('register'),
                            isLogin: true,
                            onLoginTap: () {},
                            onRegisterTap: _goToRegister,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: service.t('email_hint'),
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _passCtrl,
                            hint: service.t('password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            toggleObscure: () => setState(() => _obscure = !_obscure),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            MessageBanner(text: _error!),
                          ],
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: service.t('sign_in'),
                            loading: _loading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(isThai ? 'หรือ' : 'or',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 12.5)),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.bg,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                              ),
                              onPressed: _googleLoading ? null : _handleGoogleLogin,
                              icon: _googleLoading
                                  ? SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.textPrimary))
                                  : Image.asset('assets/images/google_logo.png',
                                      height: 20, width: 20,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Google'),
                              label: Text(
                                  isThai ? 'เข้าสู่ระบบด้วย Google' : 'Continue with Google',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                            context, noAnimationRoute(const ForgotPasswordScreen())),
                        child: Text(service.t('forgot_password_q'),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// วงกลมแสงพาสเทลนุ่ม ๆ วางไว้ที่ไอคอนหัวข้อ เพื่อเพิ่มมิติและความน่ารักให้หน้า auth
class _GlowBadge extends StatelessWidget {
  final IconData icon;
  const _GlowBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.accentDeep.withOpacity(0.20),
                AppColors.accentDeep.withOpacity(0.0),
              ],
            ),
          ),
        ),
        HeaderIconBadge(icon: icon),
      ],
    );
  }
}

/// ก้อนแสงพาสเทลลอยอยู่มุมจอ ใช้เป็นของแต่งพื้นหลังโทนนุ่มนวล
/// ใช้เทคนิค BoxShadow เบลอ (กล่องขนาด 0x0 แล้วให้เงาฟุ้งออกรอบทิศ) แทนการไล่สี
/// แบบ gradient เพราะเบลอจริงแบบนี้จะฟุ้งกลืนไปกับพื้นหลังได้เนียนทุกด้าน
/// ไม่มีขอบเส้นแข็ง ๆ ให้เห็นแม้จะโดนขอบจอตัดก็ตาม
class _PastelBlob extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;

  const _PastelBlob({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDeep.withOpacity(0.16),
                blurRadius: size * 0.55,
                spreadRadius: size * 0.12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill segmented toggle "เข้าสู่ระบบ / สมัครสมาชิก" — ใช้โทนสี/รูปแบบเดียวกับ
/// _typeToggle ใน add_income_expense_screen.dart (แถบพื้นหลัง AppColors.surface
/// มีเส้นขอบ + แท่งไฮไลต์ AppColors.accentDeep) เพื่อให้หน้า Login/Register
/// ใช้ภาษาภาพเดียวกับส่วนอื่นของแอป
///
/// เป็น toggle ที่ "เลื่อนได้" จริง ๆ: แท่งไฮไลต์จะ animate เลื่อนไปด้านที่แตะ
/// ก่อน แล้วค่อยเรียก callback นำทางไปหน้านั้น (ดีเลย์เท่ากับ duration ของ
/// แอนิเมชัน) ทำให้เห็นการสลับ tab ลื่นไหลก่อนเปลี่ยนหน้าจริง
/// ใช้ร่วมกันได้ทั้งหน้า Login (isLogin: true) และหน้า Register (isLogin: false)
class AuthTabToggle extends StatefulWidget {
  final String loginLabel;
  final String registerLabel;
  final bool isLogin;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  const AuthTabToggle({
    super.key,
    required this.loginLabel,
    required this.registerLabel,
    required this.isLogin,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  @override
  State<AuthTabToggle> createState() => _AuthTabToggleState();
}

class _AuthTabToggleState extends State<AuthTabToggle> {
  static const _duration = Duration(milliseconds: 260);
  late bool _isLogin = widget.isLogin;

  @override
  void didUpdateWidget(covariant AuthTabToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLogin != widget.isLogin) {
      setState(() => _isLogin = widget.isLogin);
    }
  }

  void _handleTap(bool tappedLogin) {
    if (tappedLogin == _isLogin) return;
    // เลื่อนแท่งไฮไลต์ไปด้านที่แตะก่อน แล้วค่อยนำทางไปหน้าใหม่
    setState(() => _isLogin = tappedLogin);
    Future.delayed(_duration, () {
      if (!mounted) return;
      tappedLogin ? widget.onLoginTap() : widget.onRegisterTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    const height = 46.0;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: _duration,
            curve: Curves.easeOutCubic,
            alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentDeep,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleTap(true),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      style: TextStyle(
                          color: _isLogin ? Colors.white : AppColors.textPrimary,
                          fontWeight: _isLogin ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14),
                      child: Text(widget.loginLabel),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleTap(false),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      style: TextStyle(
                          color: !_isLogin ? Colors.white : AppColors.textPrimary,
                          fontWeight: !_isLogin ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14),
                      child: Text(widget.registerLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 13.35 flutter_application_1/lib/screens/receipt_scan_screen.dart

ควบคุม pick→scan→review→save ตรวจชนิด/ขนาดภาพ รักษาบัญชีและสกุลเงินขณะสแกน จัดการ error หลายชนิดและลบไฟล์ orphan เมื่อบันทึกไม่สำเร็จ

โครงสร้างที่ประกาศ: class ReceiptScanScreen extends StatefulWidget (L20); class _ReceiptScanScreenState extends State<ReceiptScanScreen> (L26); class _ReceiptArtwork extends StatelessWidget (L753)

760 บรรทัด • SHA-256: bba8f2ffc2ea518f

```dart
import '../widgets/success_notice.dart';
import 'package:flutter/services.dart';
import '../services/local_receipt_store.dart';
import '../widgets/receipt_scan_error_dialog.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/receipt_category_picker.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../services/receipt_service.dart';
import '../widgets/pastel_artwork.dart';
import 'app_theme.dart';
import 'history_screen.dart'; // ปรับชื่อไฟล์/คลาสให้ตรงกับโปรเจกต์

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});
  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Uint8List? _image;
  String _contentType = 'image/jpeg';
  DateTime _date = DateTime.now();
  CategoryModel? _category;
  String? _localReceiptPath;
  String? _currency;
  String? _owner;
  String? _message;
  bool _busy = false;
  bool _scanSucceeded = false;
  bool get _thai => context.read<DataService>().currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      final bytes = await file.readAsBytes();
      final String contentType;
      if (bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff) {
        contentType = 'image/jpeg';
      } else if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        contentType = 'image/png';
      } else {
        if (mounted) {
          setState(() => _message = _t('กรุณาเลือกรูป JPG หรือ PNG',
              'Please select a JPG or PNG image.'));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _scanSucceeded = false;
        _image = bytes;
        _contentType = contentType;
        _localReceiptPath = null;
        _currency = context.read<DataService>().currentCurrency;
        _owner = FirebaseAuth.instance.currentUser?.uid;
        _amount.clear();
        _note.clear();
        _category = null;
        _date = DateTime.now();
      });
      await _scan();
    } catch (_) {
      if (mounted) {
        setState(() => _message = _t(
            'เปิดรูปไม่ได้ กรุณาอนุญาตกล้อง/คลังรูป และใช้รูปไม่เกิน 5 MB',
            'Cannot open image. Check permissions and use an image under 5 MB.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    try {
      final draft = await ReceiptService().scan(_image!);
      if (!mounted) return;
      setState(() {
        _scanSucceeded = true;
        _amount.text = draft.amount?.toStringAsFixed(2) ?? '';
        _note.text = draft.merchant;
        _date = draft.date ?? DateTime.now();
        _message = _t(
            'ตรวจยอดเงิน สกุลเงิน และวันที่ แล้วเลือกหมวดหมู่ก่อนบันทึก หากไม่พบวันที่จะใช้วันนี้',
            'Review amount, currency and date, then choose a category. Missing dates default to today.');
      });
    } catch (error) {
      if (!mounted) return;
      final serviceError = error is PlatformException ||
          error is MissingPluginException ||
          error is UnsupportedError;
      final timedOut = error is TimeoutException;
      final message = timedOut
          ? _t(
              'อ่านรูปใช้เวลานานเกินไป กรุณาลองใช้รูปที่ครอปเฉพาะสลิปหรือใบเสร็จ',
              'Reading took too long. Try a photo cropped to the slip or receipt.')
          : error is StateError
              ? _t('ตัวอ่านรูปยังทำงานอยู่ กรุณารอสักครู่แล้วลองใหม่',
                  'The previous scan is still finishing. Please wait and retry.')
              : error is UnsupportedError
                  ? _t(
                      'การสแกนออฟไลน์รองรับ Android และ iPhone กรุณาเปิดแอปบนมือถือ',
                      'Offline scanning supports Android and iPhone. Please use the mobile app.')
                  : serviceError
                      ? _t(
                          'ตัวอ่านรูปบนเครื่องไม่พร้อมใช้งาน กรุณาปิดแล้วเปิดแอปใหม่ หากยังไม่ได้ให้ติดตั้งแอปรุ่นล่าสุด',
                          'The on-device scanner is unavailable. Restart the app or install the latest version.')
                      : _t(
                          'อ่านยอดเงินจากรูปนี้ไม่ได้ กรุณาใช้ภาพใบเสร็จหรือสลิปที่ชัดเจน แล้วลองใหม่',
                          'Could not read a total. Choose a clear receipt or payment slip and try again.');
      setState(() {
        _scanSucceeded = false;
        _message = message;
      });
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.ink.withValues(alpha: 0.28),
        builder: (_) => ReceiptScanErrorDialog(
            isThai: _thai,
            timedOut: timedOut,
            serviceUnavailable: serviceError,
            message: message),
      );
    }
  }

  Future<void> _save() async {
    if (_busy || !_scanSucceeded) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _message = _t(
          'กรุณากรอกยอดเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != _owner || service.currentCurrency != _currency) {
      setState(() => _message = _t('บัญชีหรือสกุลเงินเปลี่ยน กรุณาเลือกรูปใหม่',
          'Account or currency changed. Select the image again.'));
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var saved = false;
    final receiptStore = LocalReceiptStore();
    try {
      _localReceiptPath ??= await receiptStore.save(_image!,
          owner: uid, isPng: _contentType == 'image/png');

      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          service.currentCurrency != _currency) {
        throw StateError('Account or currency changed');
      }
      final error = await service.addTransaction(
          type: CategoryType.expense,
          amount: amount,
          category: _category!,
          date: _date,
          note: _note.text.trim(),
          receiptPath: _localReceiptPath);
      saved = error == null;
      if (!mounted) return;
      if (error != null) {
        setState(() => _message = error);
        return;
      }
      showSuccessNotice(context, 'transaction_saved');
      // บันทึกสำเร็จ → ไปหน้าประวัติ (แทนที่หน้าสแกน กดย้อนกลับแล้วไม่วนกลับมาหน้าสแกน)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HistoryScreen()),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = _t(
            'บันทึกไม่สำเร็จ ตรวจพื้นที่ว่างและการเชื่อมต่อ แล้วลองอีกครั้ง ข้อมูลยังอยู่',
            'Could not save. Check free storage and your connection, then retry. Your details are retained.'));
      }
    } finally {
      if (!saved && _localReceiptPath != null) {
        final orphan = _localReceiptPath!;
        _localReceiptPath = null;
        try {
          await receiptStore.delete(orphan);
        } catch (_) {
          // Cleanup failure must not hide the original save error.
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  BoxDecoration _cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      );

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 21, color: AppColors.ink),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.ink, width: 1.5)),
      );

  Widget _pickButton(
      {required ImageSource source,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _busy ? null : () => _pick(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: AppColors.ink, size: 27)),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _step(String number, String label, bool active) => Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: active ? AppColors.ink : AppColors.surface,
                  shape: BoxShape.circle),
              child: Text(number,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          active ? AppColors.card : AppColors.textSecondary))),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color:
                          active ? AppColors.ink : AppColors.textSecondary))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(CategoryType.expense);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: AbsorbPointer(
          absorbing: _busy,
          child: Column(children: [
            AppHeader(title: _t('สลิป / ใบเสร็จ', 'Slip / receipt')),
            Expanded(
                child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Center(
                          child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                _step('1', _t('เลือกรูป', 'Choose'),
                                    _image == null),
                                Icon(Icons.chevron_right_rounded,
                                    size: 17, color: AppColors.textSecondary),
                                _step('2', _t('ตรวจข้อมูล', 'Review'),
                                    _scanSucceeded),
                                Icon(Icons.chevron_right_rounded,
                                    size: 17, color: AppColors.textSecondary),
                                _step('3', _t('บันทึก', 'Save'), false),
                              ]),
                              const SizedBox(height: 16),
                              Container(
                                decoration: _cardDecoration(),
                                padding: const EdgeInsets.all(12),
                                child: Column(children: [
                                  if (_image == null) ...[
                                    SizedBox(
                                        height: 88,
                                        width: 136,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                  width: 80,
                                                  height: 76,
                                                  decoration: BoxDecoration(
                                                      color: AppColors.accentBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              34))),
                                              const _ReceiptArtwork(),
                                              Positioned(
                                                  top: 5,
                                                  right: 14,
                                                  child: Icon(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      color:
                                                          AppColors.accentPink,
                                                      size: 26)),
                                              Positioned(
                                                  bottom: 10,
                                                  left: 14,
                                                  child: Icon(
                                                      Icons.favorite_rounded,
                                                      color:
                                                          AppColors.accentPink,
                                                      size: 18)),
                                            ])),
                                    const SizedBox(height: 12),
                                    Text(
                                        _t('เพิ่มรายจ่ายจากสลิปธนาคาร',
                                            'Add an expense from a bank slip'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                    const SizedBox(height: 8),
                                    Text(
                                        _t('เลือกรูปสลิปธนาคารหรือใบเสร็จ เพื่ออ่านยอดเงิน',
                                            'Choose a bank slip or receipt to read the amount'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary)),
                                  ] else ...[
                                    Row(children: [
                                      Icon(Icons.receipt_long_rounded,
                                          color: AppColors.ink, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              _t('สลิป / ใบเสร็จของคุณ',
                                                  'Your slip / receipt'),
                                              style: AppTextStyles.heading)),
                                      Icon(Icons.favorite_rounded,
                                          color: AppColors.accentPink,
                                          size: 18),
                                    ]),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                            width: double.infinity,
                                            color: AppColors.surface,
                                            child: Image.memory(_image!,
                                                height: 240,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            36),
                                                    child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        color: AppColors
                                                            .textSecondary))))),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: _pickButton(
                                                source: ImageSource.gallery,
                                                icon: Icons
                                                    .add_photo_alternate_outlined,
                                                title: _t(
                                                    _image == null
                                                        ? 'เลือกรูป'
                                                        : 'เปลี่ยนรูป',
                                                    _image == null
                                                        ? 'Choose photo'
                                                        : 'Change photo'),
                                                subtitle: _t('จากคลังรูปของคุณ',
                                                    'From your gallery'),
                                                color: AppColors.surfaceAlt)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: _pickButton(
                                                source: ImageSource.camera,
                                                icon: Icons.camera_alt_outlined,
                                                title: _t(
                                                    'ถ่ายรูป', 'Take a photo'),
                                                subtitle: _t(
                                                    'ถ่ายสลิป / ใบเสร็จ',
                                                    'Capture a slip or receipt'),
                                                color: AppColors.accentBg)),
                                      ]),
                                  const SizedBox(height: 12),
                                  Text(
                                      'JPG / PNG · ${_t('ไม่เกิน 5 MB', 'Up to 5 MB')}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ]),
                              ),
                              if (_busy && _message == null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: _cardDecoration(
                                            color: AppColors.accentBg),
                                        child: Row(children: [
                                          SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: AppColors.ink)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Text(
                                                  _t('กำลังดำเนินการ รอสักครู่นะ…',
                                                      'Working on it, one moment…'),
                                                  style: TextStyle(
                                                      color: AppColors.ink,
                                                      fontSize: 14))),
                                        ]))),
                              ],
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: _cardDecoration(
                                            color: AppColors.accentAltBg),
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.info_outline_rounded,
                                                  color: AppColors.ink,
                                                  size: 21),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(_message!,
                                                      key: const Key(
                                                          'receipt-message'),
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          height: 1.6,
                                                          color: AppColors
                                                              .textPrimary))),
                                            ]))),
                              ],
                              if (_image != null && _scanSucceeded) ...[
                                const SizedBox(height: 16),
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: _cardDecoration(),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              _t('เช็กอีกนิด ก่อนบันทึก',
                                                  'A quick check before saving'),
                                              style: AppTextStyles.heading),
                                          const SizedBox(height: 6),
                                          Text(
                                              _t('ตรวจยอดเงิน ชื่อผู้รับ และวันที่ให้ตรงกับรูป',
                                                  'Check the amount, recipient and date against your image'),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary)),
                                          const SizedBox(height: 16),
                                          TextField(
                                              controller: _amount,
                                              readOnly: true,
                                              keyboardType: TextInputType.none,
                                              onTap: () => showAmountKeypad(
                                                  context,
                                                  controller: _amount,
                                                  title: _t(
                                                      'ยอดเงิน ($_currency)',
                                                      'Amount ($_currency)')),
                                              decoration: _fieldDecoration(
                                                  _t('ยอดเงิน ($_currency)',
                                                      'Amount ($_currency)'),
                                                  Icons.payments_outlined)),
                                          const SizedBox(height: 14),
                                          TextField(
                                              controller: _note,
                                              decoration: _fieldDecoration(
                                                  _t('ร้านค้า / ผู้รับ / หมายเหตุ',
                                                      'Merchant / recipient / note'),
                                                  Icons.storefront_outlined)),
                                          const SizedBox(height: 14),
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: _busy
                                                ? null
                                                : () async {
                                                    final selected =
                                                        await showReceiptCategoryPicker(
                                                      context,
                                                      categories: categories,
                                                      selectedId: _category?.id,
                                                      thai: _thai,
                                                    );
                                                    if (selected != null &&
                                                        mounted) {
                                                      setState(() =>
                                                          _category = selected);
                                                    }
                                                  },
                                            child: InputDecorator(
                                              decoration: _fieldDecoration(
                                                  _t('หมวดรายจ่าย',
                                                      'Expense category'),
                                                  Icons.grid_view_rounded),
                                              child: Row(children: [
                                                if (_category != null) ...[
                                                  CategoryIcon(
                                                      category: _category!,
                                                      size: 30),
                                                  const SizedBox(width: 10),
                                                ],
                                                Expanded(
                                                    child: Text(
                                                        _category?.name ??
                                                            _t('เลือกหมวดหมู่',
                                                                'Choose a category'),
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textPrimary))),
                                                Icon(Icons.expand_more_rounded,
                                                    color: AppColors.ink),
                                              ]),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Material(
                                              color: AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: ListTile(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(
                                                          16)),
                                                  leading: Icon(Icons.calendar_month_rounded,
                                                      color: AppColors.ink),
                                                  title: Text(_t('วันที่ทำรายการ', 'Transaction date'),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .textSecondary)),
                                                  subtitle:
                                                      Text(DateFormat('dd/MM/yyyy').format(_date),
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .textPrimary,
                                                              fontSize: 14)),
                                                  trailing: Icon(Icons.edit_outlined,
                                                      color: AppColors.ink,
                                                      size: 19),
                                                  onTap: () async {
                                                    final date =
                                                        await showDatePicker(
                                                            context: context,
                                                            initialDate: _date,
                                                            firstDate:
                                                                DateTime(2000),
                                                            lastDate:
                                                                DateTime(2200));
                                                    if (date != null &&
                                                        mounted) {
                                                      setState(
                                                          () => _date = date);
                                                    }
                                                  })),
                                          const SizedBox(height: 18),
                                          FilledButton.icon(
                                              onPressed: _busy ? null : _save,
                                              style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.accentDeep,
                                                  foregroundColor: Colors.white,
                                                  minimumSize:
                                                      const Size.fromHeight(54),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18))),
                                              icon: const Icon(Icons.check_circle_outline_rounded,
                                                  size: 21),
                                              label: Text(
                                                  _t('ยืนยันและบันทึกรายจ่าย',
                                                      'Confirm and save expense'),
                                                  textAlign: TextAlign.center)),
                                        ])),
                              ] else ...[
                                const SizedBox(height: 16),
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: _cardDecoration(
                                        color: AppColors.accentAltBg),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.lightbulb_outline_rounded,
                                              color: AppColors.ink, size: 25),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    _t('รูปชัด อ่านง่ายกว่า',
                                                        'A clear photo works best'),
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 14)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    _t('ใช้รูปสลิปจากแอปธนาคาร หรือใบเสร็จที่เห็นยอดเงินครบ\nวางให้ตรง และหลีกเลี่ยงแสงสะท้อน',
                                                        'Use a bank app slip or a full receipt with the amount visible. Keep it straight and avoid glare.'),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        height: 1.6,
                                                        color: AppColors.ink)),
                                              ])),
                                        ])),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                  _t('อ่านรูปบนเครื่องฟรี ไม่ส่งรูปไปบริการสแกน\nรูปแนบเก็บเฉพาะเครื่องนี้และไม่ซิงก์ข้ามเครื่อง ตรวจข้อมูลก่อนบันทึก ระบบไม่ได้ยืนยันการโอนเงินจริง',
                                      'Scanned on your device for free. Attachments stay on this device and do not sync. Review before saving. This does not verify the bank transfer.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.6,
                                      color: AppColors.textSecondary)),
                            ]),
                      )),
                    ))),
          ]),
        ),
      ),
    );
  }
}

class _ReceiptArtwork extends StatelessWidget {
  const _ReceiptArtwork();
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.10,
        child: const GoalArtwork(Icons.receipt_long, size: 60),
      );
}
```

### 13.36 flutter_application_1/lib/screens/register_screen.dart

รับชื่อ อีเมล รหัสและการยืนยัน ตรวจช่องจำเป็น ความตรงกัน และ policy ก่อน register เมื่อสำเร็จนำไปขั้นตั้งค่า; dispose controller เพื่อคืนทรัพยากร

โครงสร้างที่ประกาศ: class RegisterScreen extends StatefulWidget (L10); class _RegisterScreenState extends State<RegisterScreen> (L17)

269 บรรทัด • SHA-256: 5064e9b66c42a1e1

```dart
import '../widgets/password_requirements.dart';
import '../services/password_policy.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'language_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_loading) return;
    final service = context.read<DataService>();

    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = service.t('fill_all_fields'));
      return;
    }
    if (_confirmCtrl.text.isEmpty) {
      setState(() => _error = service.t('enter_confirm_password'));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = service.t('password_mismatch'));
      return;
    }

    final invalid = passwordValidationKey(_passCtrl.text);
    if (invalid != null) {
      setState(() => _error = service.t(invalid));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? error;
    try {
      error = await service.register(
          _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      error = '${service.t('save_failed')}: $e';
    }

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        noAnimationRoute(const LanguageSetupScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
        context, noAnimationRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          // ก้อนสีพาสเทลลอยด้านหลัง เพิ่มความน่ารักให้พื้นหลัง
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.16),
                      blurRadius: 88,
                      spreadRadius: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.15),
                      blurRadius: 105,
                      spreadRadius: 23,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ไอคอนหัวข้อพร้อมแสงเรืองสีพาสเทลด้านหลัง
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.accentDeep.withOpacity(0.20),
                                  AppColors.accentDeep.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          const HeaderIconBadge(icon: Icons.person_add_alt_1_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('create_account'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(service.t('register_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                    const SizedBox(height: 26),

                    // การ์ดฟอร์มโค้งมนลอยตัว ให้ความรู้สึกนุ่มนวลอบอุ่นกว่าเดิม
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md + 8),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // สลับ เข้าสู่ระบบ/สมัครสมาชิก แบบ pill segmented ที่เลื่อนได้จริง
                          AuthTabToggle(
                            loginLabel: service.t('login'),
                            registerLabel: service.t('register'),
                            isLogin: false,
                            onLoginTap: _goToLogin,
                            onRegisterTap: () {},
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _nameCtrl,
                            hint: service.t('name_hint'),
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: service.t('email_hint'),
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _passCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                            hint: service.t('password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _confirmCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                            hint: service.t('confirm_password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirm,
                            toggleObscure: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
              PasswordRequirements(password: _passCtrl, confirmation: _confirmCtrl),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            MessageBanner(text: _error!),
                          ],
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: service.t('sign_up'),
                            loading: _loading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 13.37 flutter_application_1/lib/screens/statistic_screen.dart

สร้างชุดข้อมูลกราฟตาม ChartPeriod แสดงสัดส่วนรายรับรายจ่าย หมวดใช้จ่ายสูง และรายการเป้าหมาย/เป้าที่เด่นจาก progress; บางการ์ดใช้ยอดรวมทั้งหมดในสกุลเงิน

โครงสร้างที่ประกาศ: class StatisticScreen extends StatefulWidget (L43); class _StatisticScreenState extends State<StatisticScreen> (L50); class _FeaturedGoalCard extends StatelessWidget (L401)

492 บรรทัด • SHA-256: d9cee15bafdb8243

```dart
import '../widgets/pastel_artwork.dart';
import '../widgets/data_action.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/period_selector.dart';
import 'home_screen.dart';

const List<String> _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// ชุดสีพาสเทลสลับให้ไอคอนเป้าหมายแต่ละใบมีโทนต่างกัน (เทียบ _goalTint ใน
// goal_saving_screen.dart) เพื่อให้ลิสต์เป้าหมายในหน้าสถิติดูมีสีสันน่ารักขึ้น
// แทนที่จะเป็นวงกลมสีเดียวซ้ำๆ ทุกใบ
const List<Color> _statGoalTint = [
  Color(0xFFDCEEF7), // ฟ้าอ่อน
  Color(0xFFFBEED0), // เหลืองพีชอ่อน
  Color(0xFFF6E1E7), // ชมพูอ่อน
  Color(0xFFE1EFF8), // ฟ้ากลางอ่อน
  Color(0xFFE8F3E3), // มินต์อ่อน
  Color(0xFFEFE7FA), // ม่วงลาเวนเดอร์อ่อน
];
const List<Color> _statGoalTintIcon = [
  Color(0xFF3D568F),
  Color(0xFFC79A3B),
  Color(0xFFC08B9D),
  Color(0xFF5C86C4),
  Color(0xFF4E9B6E),
  Color(0xFF8B6FC4),
];

/// หน้า Statistic (3.4.8) - วิเคราะห์แนวโน้มรายรับ/รายจ่าย และความคืบหน้าการออม
class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  ChartPeriod _period = ChartPeriod.month;
  DateTime _anchor = DateTime.now();

  List<MapEntry<String, Map<String, double>>> _series(DataService service) {
    final isThai = service.currentLanguage != 'English';
    switch (_period) {
      case ChartPeriod.day:
        final data = service.dailySummary(days: 7, endDate: _anchor);
        return data.map((e) => MapEntry('${e.key.day}/${e.key.month}', e.value)).toList();
      case ChartPeriod.month:
        final data = service.monthlySummary(months: 6, endMonth: _anchor);
        final months = isThai ? _thaiMonthsShort : _enMonthsShort;
        return data.map((e) => MapEntry(months[e.key.month - 1], e.value)).toList();
      case ChartPeriod.year:
        final data = service.yearlySummary(years: 5, endYear: _anchor.year);
        return data.map((e) => MapEntry('${e.key}', e.value)).toList();
    }
  }

  dynamic _topGoal(DataService service) {
    if (service.goals.isEmpty) return null;
    final sorted = [...service.goals]..sort((a, b) => b.progress.compareTo(a.progress));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final series = _series(service);
    final mostSpent = service.mostSpentCategory;
    final pct = service.incomeExpensePercentage;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: service.t('statistic_title'),
            onBack: () => Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            ),
          ),
          Expanded(
            // ห่อด้วย RefreshIndicator กันไม่ให้ดึงหน้าจอเกินขอบบนแล้วเห็นพื้นที่ว่างสีขาว
            child: RefreshIndicator(
              color: AppColors.accentDeep,
              backgroundColor: AppColors.card,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                Text(service.t('income_expense'), style: AppTextStyles.heading),
                const SizedBox(width: 6),
                Icon(Icons.insights_rounded, size: 15, color: AppColors.accentDeep),
              ],
            ),
            const SizedBox(height: 10),
            PeriodFilterBar(
              period: _period,
              anchor: _anchor,
              onPeriodChanged: (p) => setState(() => _period = p),
              onAnchorChanged: (d) => setState(() => _anchor = d),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value != value.roundToDouble()) return const SizedBox.shrink();
                                final idx = value.toInt();
                                if (idx < 0 || idx >= series.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(series[idx].key,
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
            preventCurveOverShooting: true,
                            color: AppColors.accentDeep,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.accentDeep.withOpacity(0.16),
                                  AppColors.accentDeep.withOpacity(0.0),
                                ],
                              ),
                            ),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['income'] ?? 0)),
                          ),
                          LineChartBarData(
                            isCurved: true,
            preventCurveOverShooting: true,
                            color: AppColors.accentPink,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.accentPink.withOpacity(0.14),
                                  AppColors.accentPink.withOpacity(0.0),
                                ],
                              ),
                            ),
                            spots: List.generate(series.length,
                                (i) => FlSpot(i.toDouble(), series[i].value['expense'] ?? 0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendChip(AppColors.income, AppColors.incomeBg,
                          '${service.t('income')} ${pct['income']!.toStringAsFixed(0)}%', true),
                      const SizedBox(width: 8),
                      _legendChip(AppColors.expense, AppColors.expenseBg,
                          '${service.t('expense')} ${pct['expense']!.toStringAsFixed(0)}%', false),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (mostSpent != null)
              AppCard(
                color: AppColors.accentAltBg,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ฟองสบู่ตกแต่งมุมขวาบน ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
                      Positioned(
                        right: -14,
                        top: -18,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: const Color(0xFFC79A3B).withOpacity(0.14), shape: BoxShape.circle),
                        ),
                      ),
                      LayoutBuilder(builder: (context, constraints) => Wrap(
                        spacing: 10, runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CategoryIcon(category: mostSpent.key, size: 22, color: AppColors.accentDeep),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 44).clamp(0.0, double.infinity),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(service.t('most_spent_category'),
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                    const SizedBox(width: 4),
                                    const Text('🏆', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(service.categoryName(mostSpent.key),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(service.formatMoney(mostSpent.value),
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(service.t('goal_saving'), style: AppTextStyles.heading),
                const SizedBox(width: 6),
                const Text('🐷', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            if (service.goals.isNotEmpty) _FeaturedGoalCard(goal: _topGoal(service)!, service: service),
            if (service.goals.isNotEmpty) const SizedBox(height: 12),
            if (service.goals.isEmpty)
              EmptyState(icon: Icons.savings_outlined, text: service.t('no_goals'))
            else
              ...service.goals.asMap().entries.map((entry) {
                final i = entry.key;
                final g = entry.value;
                final tint = _statGoalTint[i % _statGoalTint.length];
                final tintIcon = _statGoalTintIcon[i % _statGoalTintIcon.length];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: GoalArtwork(g.icon, artworkNumber: g.artworkNumber, color: tintIcon, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(g.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ),
                              Text('${(g.progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              color: g.progress >= 1 ? AppColors.success : tintIcon,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '${service.formatMoney(g.savedAmount)} / ${service.formatMoney(g.targetAmount)}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (g.isNearTarget)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CuteMascot(kind: CuteMascotKind.bell, color: AppColors.ink, size: 16),
                                  const SizedBox(width: 4),
                                  Text(service.t('near_target'),
                                      style: TextStyle(color: AppColors.ink, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
              }),
            const SizedBox(height: 80),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Future<void> _onRefresh() async {
    await refreshAppData(context);
    if (mounted) setState(() {});
  }

  Widget _legendChip(Color color, Color bg, String label, bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CuteMascot(
              kind: isIncome ? CuteMascotKind.income : CuteMascotKind.expense, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// การ์ดไฮไลต์เป้าหมายที่คืบหน้ามากที่สุด (โทนมินต์) แทนที่จะแสดงแค่ในลิสต์ปกติ
/// ให้ผู้ใช้เห็นเป้าหมายที่ใกล้สำเร็จที่สุดเด่นชัดตั้งแต่แรก ตามดีไซน์อ้างอิง
class _FeaturedGoalCard extends StatelessWidget {
  final dynamic goal; // GoalModel
  final DataService service;
  const _FeaturedGoalCard({required this.goal, required this.service});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final near = goal.isNearTarget as bool;
    return Container(
      // Clip decorations at the card edge, not at the padded text bounds.
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ฟองสบู่ตกแต่งมุมล่างซ้าย ให้เข้าชุดกับการ์ดอื่นๆ ในแอป
            Positioned(
              left: -18,
              bottom: -22,
              child: Container(
                width: 60,
                height: 60,
                decoration:
                    BoxDecoration(color: AppColors.success.withOpacity(0.10), shape: BoxShape.circle),
              ),
            ),
          // มาสคอตตกแต่งมุมขวา (placeholder จนกว่าจะมี asset จริง) ไม่บังข้อความ/progress bar
          Positioned(
            right: 0,
            top: 4,
            child: Opacity(
              opacity: 0.9,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, color: AppColors.accentPink, size: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Goal Progress',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Text('🌸', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  near ? service.t('near_target') : goal.name,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$pct%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
    );
  }
}
```

### 13.38 flutter_application_1/lib/screens/transaction_details_sheet.dart

showTransactionDetails เปิดรายละเอียดและรับ action edit/duplicate/delete เรียก editor สำหรับสองอย่างแรก และ dialog ยืนยันก่อนลบ แสดงข้อมูลบัญชี หมวด วัน และยอด

โครงสร้างที่ประกาศ: enum _Action (L12); class _TransactionDetails extends StatelessWidget (L132)

258 บรรทัด • SHA-256: 661a5190647b6406

```dart
import '../widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/pastel_artwork.dart';
import '../widgets/transaction_sheet_style.dart';
import 'edit_transaction_screen.dart';

enum _Action { edit, duplicate, delete }

Future<void> showTransactionDetails(
    BuildContext context, TransactionModel transaction) async {
  final service = context.read<DataService>();
  final action = await showModalBottomSheet<_Action>(
      context: context,
      isScrollControlled: true,
        useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _TransactionDetails(transaction: transaction));
  if (action == null || !context.mounted) return;
  if (action != _Action.delete) {
    await showEditTransactionSheet(context, transaction,
        duplicate: action == _Action.duplicate);
    return;
  }
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            backgroundColor: TransactionSheetColors.background,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            titlePadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            icon: Center(
                child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFEAE8), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: TransactionSheetColors.red, size: 25))),
            title: Text(
                service.currentLanguage == 'English'
                    ? 'Delete transaction?'
                    : 'ลบรายการนี้ใช่ไหม?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: TransactionSheetColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  service.currentLanguage == 'English'
                      ? 'This transaction will be removed from your history.'
                      : 'รายการนี้จะถูกนำออกจากประวัติ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: TransactionSheetColors.muted)),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    CategoryIcon(category: transaction.category, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(service.categoryName(transaction.category),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: TransactionSheetColors.ink)),
                          const SizedBox(height: 4),
                          Text(service.formatMoney(transaction.amount),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TransactionSheetColors.ink)),
                        ])),
                  ])),
            ]),
            actions: [
              Row(children: [
                Expanded(
                    child: TextButton(
                        style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: TransactionSheetColors.ink,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(service.t('cancel')))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextButton(
                        style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEAE8),
                            foregroundColor: const Color(0xFFB74745),
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(service.t('delete')))),
              ])
            ],
          ));
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteTransaction(transaction.id);
    if (context.mounted) showSuccessNotice(context, 'transaction_deleted');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('save_failed'))));
  }
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    String t(String th, String en) =>
        service.currentLanguage == 'English' ? en : th;
    final isIncome = transaction.type == CategoryType.income;
    final amountColor =
        isIncome ? TransactionSheetColors.green : TransactionSheetColors.red;
    Widget line(String label, String value, {bool amount = false}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: TransactionSheetColors.muted, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color:
                          amount ? amountColor : TransactionSheetColors.muted,
                      fontSize: amount ? 23 : 14,
                      fontWeight: amount ? FontWeight.w700 : FontWeight.w500))),
        ]));
    return TransactionSheetFrame(
      title: t('รายละเอียด', 'Details'),
      actions: Row(children: [
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(destructive: true),
                onPressed: () => Navigator.pop(context, _Action.delete),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(service.t('delete')))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(),
                onPressed: () => Navigator.pop(context, _Action.duplicate),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(t('ทำซ้ำ', 'Copy')))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(primary: true),
                onPressed: () => Navigator.pop(context, _Action.edit),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(service.t('edit')))),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        transactionWhiteCard(
            child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF8FB), shape: BoxShape.circle),
              child: CategoryIcon(category: transaction.category, size: 38)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.categoryName(transaction.category),
                    style: const TextStyle(
                        color: TransactionSheetColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(
                    t('หมวดหมู่ ', 'Category: ') +
                        service.categoryName(transaction.category),
                    style: const TextStyle(
                        color: TransactionSheetColors.muted, fontSize: 14)),
              ])),
        ])),
        const SizedBox(height: 10),
        transactionWhiteCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('กระเป๋าเงิน', 'Wallet'),
              style: const TextStyle(
                  color: TransactionSheetColors.muted, fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: [
            const PastelArtwork(categoryNumber: 14, size: 40),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'BUDGETMATE - ${transaction.currency ?? service.currentCurrency}',
                    style: const TextStyle(
                        color: TransactionSheetColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)))
          ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFE3EBFB))),
          Text(t('บันทึกช่วยจำ', 'Note'),
              style: const TextStyle(
                  color: TransactionSheetColors.muted, fontSize: 14)),
          const SizedBox(height: 8),
          Text(transaction.note?.isNotEmpty == true ? transaction.note! : '—',
              style: const TextStyle(
                  color: TransactionSheetColors.ink, fontSize: 14)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFE3EBFB))),
          Text(t('รายละเอียด', 'Details'),
              style: const TextStyle(
                  color: TransactionSheetColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          line(t('วันที่ทำรายการ', 'Date'),
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)),
          line(t('ประเภทรายการ', 'Type'),
              service.t(isIncome ? 'income' : 'expense')),
          line(
              t('จำนวนเงิน', 'Amount'), service.formatMoney(transaction.amount),
              amount: true),
        ])),
      ]),
    );
  }
}
```

### 13.39 flutter_application_1/lib/screens/wallet_screen.dart

แสดงยอดคงเหลือ รายรับ รายจ่าย และทางไปประวัติ/หน้าสรุป/เป้าหมาย ปุ่มย้อนกลับจัดเส้นทางไป Home เพื่อไม่กลับไป Login โดยไม่ตั้งใจ

โครงสร้างที่ประกาศ: class WalletScreen extends StatelessWidget (L21); class _BalanceCard extends StatelessWidget (L265); class _GoalPreviewCard extends StatelessWidget (L300)

358 บรรทัด • SHA-256: 076c6e61c7944c74

```dart
import 'home_screen.dart';
import '../models/goal_model.dart';
import '../widgets/data_action.dart';
import '../widgets/pastel_artwork.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'income_expense_screen.dart';
import 'package:budgetmate/screens/income%20expense%20overview.dart' show HistoryFilter;
import 'goal_saving_screen.dart';

/// หน้า Wallet - ภาพรวมกระเป๋าเงิน, รายรับ-รายจ่าย และเป้าหมายการออม
///
/// ดีไซน์ "Pastel Piggy" — ยังคุมโทนสีพาสเทลเดิมของแอปทั้งหมด (AppColors)
/// แต่เพิ่มความน่ารักผ่าน:
/// - การ์ดยอดคงเหลือไล่เฉดสี + ฟองสบู่ตกแต่ง + การ์ตูนกระเป๋าเงินและเหรียญยิ้ม
/// - หัวข้อมีไอคอน/อิโมจิเล็กๆ ประกอบ ให้ดูอบอุ่นเป็นกันเอง
/// - การ์ดเป้าหมายออมเงินพาสเทล พร้อมป้าย "จำนวนเป้าหมาย" ทรงเม็ดยา
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    void backToHome() => Navigator.of(context).pushAndRemoveUntil(
      noAnimationRoute(const HomeScreen()), (route) => false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) backToHome();
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          key: const Key('wallet-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded), onPressed: backToHome),
        title: Text(service.t('wallet_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      // ห่อด้วย RefreshIndicator กันไม่ให้ดึงหน้าจอเกินขอบบนแล้วเห็นพื้นที่ว่างสีขาว
      body: RefreshIndicator(
        color: AppColors.accentDeep,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await refreshAppData(context);
        },
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 16),
        children: [
          _BalanceCard(service: service),
          const SizedBox(height: 22),
          Row(
            children: [
              const PastelArtwork(categoryNumber: 32, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(service.t('income_expense'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, noAnimationRoute(const IncomeExpenseScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(service.t('history'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accentDeep),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context: context,
                  label: service.t('income'),
                  value: service.totalIncome,
                  color: AppColors.income,
                  isIncome: true,
                  filter: HistoryFilter.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  context: context,
                  label: service.t('expense'),
                  value: service.totalExpense,
                  color: AppColors.expense,
                  isIncome: false,
                  filter: HistoryFilter.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GoalPreviewCard(service: service),
          const SizedBox(height: 16),
        ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    ));
  }

  /// กล่องสีรายรับ/รายจ่าย แตะเพื่อไปหน้าประวัติ (IncomeExpenseScreen)
  /// ดีไซน์น่ารัก: พื้นพาสเทลนวล + ฟองสบู่ตกแต่งมุม + การ์ตูนเหรียญและถุงช้อปปิ้ง
  /// + ชิปตัวเลขปุ่มมนแยกชั้นจากพื้นหลัง ให้ความรู้สึกนุ่มนวลเหมือนขนม
  Widget _statBox({
    required BuildContext context,
    required String label,
    required double value,
    required Color color,
    required bool isIncome,
    required HistoryFilter filter,
  }) {
    // โทนพาสเทลนวลๆ แบบขนมหวาน: มินต์ครีมสำหรับรายรับ / พีชโคชั่นสำหรับรายจ่าย
    final Color soft = isIncome ? const Color(0xFFDFF6E8) : const Color(0xFFFFE9E4);
    final Color mid = isIncome ? const Color(0xFF8FD6AE) : const Color(0xFFF3AA9C);
    final Color dark = isIncome ? const Color(0xFF3E9468) : const Color(0xFFD8695A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(context,
            noAnimationRoute(IncomeExpenseScreen(initialFilter: filter))),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 126),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: mid.withOpacity(0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: mid.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              children: [
                // ฟองสบู่ตกแต่งมุมขวาบน-ล่าง ให้ความรู้สึกน่ารักฟรุ้งฟริ้ง
                Positioned(
                  right: -18,
                  top: -18,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: mid.withOpacity(0.25), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: -22,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: mid.withOpacity(0.20), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 8,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 11, color: mid.withOpacity(0.55)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PastelArtwork(
                            categoryNumber: isIncome ? 21 : 6,
                            size: 30,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    color: dark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // ชิปตัวเลขพื้นขาวมนๆ แยกชั้นจากพื้นหลัง ดูเหมือนป้ายราคาขนม
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isIncome
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: dark,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(context.watch<DataService>().formatMoney(value),
                                  style: TextStyle(
                                      color: dark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: -0.2)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดยอดคงเหลือ — ไล่เฉดพาสเทล (accentDeep -> accent) แทนพื้นทึบเดิม
/// พร้อมฟองสบู่ตกแต่งและมาสคอตกระปุกออมสินยิ้มมุมขวาบน ให้รู้สึกอบอุ่นน่ารัก
/// มากกว่าการ์ดข้อมูลธนาคารทั่วไป แต่ยังอ่านตัวเลขยอดคงเหลือได้ชัดเจนเป็นจุดเด่น
class _BalanceCard extends StatelessWidget {
  final DataService service;
  const _BalanceCard({required this.service});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 132),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      gradient: LinearGradient(colors: [AppColors.accentDeep,
        Color.lerp(AppColors.accentDeep, AppColors.accent, 0.55)!]),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service.t('total_balance'),
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(service.formatMoney(service.balance),
              style: const TextStyle(color: Colors.white,
                fontSize: 28, fontWeight: FontWeight.w700))),
        ])),
      const SizedBox(width: 12),
      const PastelArtwork(categoryNumber: 14, size: 48),
    ]),
  );
}

/// การ์ดพรีวิวเป้าหมายการออม — พาสเทลอ่อนกว่าเดิม พร้อมป้ายทรงเม็ดยาบอกจำนวน
/// เป้าหมายที่กำลังดำเนินอยู่ และการ์ตูนกระปุกออมสิน ให้เข้าชุดกับ
/// การ์ดยอดคงเหลือ/สถิติรายรับ-รายจ่ายด้านบน
class _GoalPreviewCard extends StatelessWidget {
  final DataService service;
  const _GoalPreviewCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: AppColors.accentAltBg,
      onTap: () => Navigator.push(
          context, noAnimationRoute(const GoalSavingScreen())),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -14,
            child: Icon(Icons.favorite_rounded,
                size: 20, color: AppColors.accentPink.withOpacity(0.35)),
          ),
          Row(
            children: [
              const PastelArtwork(categoryNumber: 17, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.t('goal_saving'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brightness == Brightness.dark
                            ? AppColors.surface : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('${service.goals.where((goal) => goal.status == GoalStatus.inProgress).length} ${service.t('goals_in_progress')}',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.accentDeep, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 13.40 flutter_application_1/lib/services/app_strings.dart

พจนานุกรมข้อความภาษาไทยและอังกฤษ ใช้ key กลางร่วมกับ DataService.t รวมชื่อหมวด ข้อความฟอร์ม ปุ่ม และข้อผิดพลาด; การเพิ่มข้อความควรใส่ทั้งสองภาษา

โครงสร้างที่ประกาศ: class AppStrings (L1)

472 บรรทัด • SHA-256: 8712c1b19d83ea4c

```dart
class AppStrings {
  AppStrings._();

  static const Map<String, String> _th = {
    'password_max_length': 'รหัสผ่านยาวเกิน 128 ตัวอักษร กรุณาใช้รหัสที่สั้นลง',
    'password_lowercase': 'ตัวพิมพ์เล็ก a–z อย่างน้อย 1 ตัว',
    'password_uppercase': 'ตัวพิมพ์ใหญ่ A–Z อย่างน้อย 1 ตัว',
    'password_digit': 'ตัวเลข 0–9 อย่างน้อย 1 ตัว',
    'password_symbol': 'สัญลักษณ์ เช่น ! @ # อย่างน้อย 1 ตัว',
    'password_common': 'รหัสผ่านนี้เดาง่าย กรุณาเลือกวลีอื่นที่ไม่ซ้ำกับบัญชีอื่น',
    'password_valid': 'รหัสผ่านผ่านเงื่อนไขแล้ว',
    'password_confirmed': 'รหัสผ่านตรงกันแล้ว',

    'edit': 'แก้ไข',
    'delete': 'ลบ',
    'all': 'ทั้งหมด',
    'no_income_data': 'ยังไม่มีข้อมูลรายรับ',
    'edit_goal': 'แก้ไขเป้าหมาย',
    'pin_goal': 'ปักหมุดบนหน้าแรก',
    'unpin_goal': 'เลิกปักหมุด',
    'manage_goal': 'จัดการเป้าหมาย',
    'delete_goal_confirm': 'ลบเป้าหมายนี้หรือไม่?',
    'delete_goal_notice': 'ลบเฉพาะเป้าหมาย ประวัติการโอนเงินเดิมยังอยู่และยอดกระเป๋าเงินไม่เปลี่ยน',
    'enter_confirm_password': 'กรุณากรอกยืนยันรหัสผ่าน',
    'password_requirements': 'ใช้ 6 ตัวอักษรขึ้นไป และครบทุกเงื่อนไขด้านล่าง',
    'target_below_saved': 'ยอดเป้าหมายต้องไม่น้อยกว่าเงินที่ออมแล้ว',

    // ---------------- Bottom Nav ----------------
    'nav_home': 'หน้าหลัก',
    'nav_wallet': 'กระเป๋าเงิน',
    'nav_add': 'เพิ่มรายการ',
    'nav_stat': 'สถิติ',
    'nav_menu': 'เมนู',

    // ---------------- Home ----------------
    'greeting': 'สวัสดี',
    'default_user': 'ผู้ใช้งาน',
    'total_income': 'รายรับรวม',
    'total_expense': 'รายจ่ายรวม',
    'net_balance': 'คงเหลือสุทธิ',
    'total_expenses_6m': 'Total Expenses (6 เดือนล่าสุด)',

    // ---------------- History ----------------
    'history': 'ประวัติ',
    'filter_all': 'ทั้งหมด',
    'filter_daily': 'รายวัน',
    'no_transactions': 'ยังไม่มีรายการ',
    'no_expense_data': 'ยังไม่มีข้อมูลรายจ่าย',
    'today': 'วันนี้',
    'yesterday': 'เมื่อวาน',

    // ---------------- Wallet ----------------
    'wallet_title': 'กระเป๋าเงิน',
    'wallet_header': 'กระเป๋าเงิน BUDGETMATE',
    'total_balance': 'ยอดคงเหลือรวม',
    'income_expense': 'รายรับ-รายจ่าย',
    'income': 'รายรับ',
    'expense': 'รายจ่าย',
    'goal_saving': 'เป้าหมายการออม',
    'goals_in_progress': 'เป้าหมายที่กำลังดำเนินการ',

    // ---------------- Income/Expense Add ----------------
    'back_home': 'กลับหน้าหลัก',
    'incomes_tab': 'รายรับ',
    'expenses_tab': 'รายจ่าย',
    'save': 'บันทึก',
    'categories': 'หมวดหมู่',
    'note_optional': 'หมายเหตุ (ไม่บังคับ)',
    'items_added': 'จำนวนรายการที่เพิ่ม',
    'tap_to_edit': '(แตะเพื่อแก้ไข)',
    'editing': 'กำลังแก้ไข',
    'cancel_edit': 'ยกเลิก',
    'select_category_prompt': 'เลือกหมวดหมู่ด้านบน แล้วกรอกจำนวนเงิน',
    'selected_category': 'หมวดหมู่ที่เลือก',
    'no_categories_for_type': 'ยังไม่มีหมวดหมู่สำหรับประเภทนี้',
    'showing_categories': 'แสดงรายการทั้งหมด',
    'items_unit': 'รายการ',
    'enter_amount': 'กรุณาระบุจำนวนเงิน',
    'select_category': 'กรุณาเลือกหมวดหมู่',
    'add_at_least_one': 'กรุณาเพิ่มรายการอย่างน้อย 1 รายการ',
    'save_failed': 'บันทึกไม่สำเร็จ',

    // ---------------- Goal Saving ----------------
    'ledger_balance': 'ยอดคงเหลือ\nBUDGETMATE',
    'no_goals': 'ยังไม่มีเป้าหมายการออม',
    'deposit_title': 'เติมเงินเข้าเป้าหมาย',
    'ledger_remaining': 'Ledger คงเหลือ',
    'needed_more': 'ต้องการอีก',
    'quarter': '25%',
    'half': '50%',
    'full_remaining': 'เต็มจำนวนที่ขาด',
    'insufficient_balance': 'Ledger Balance ไม่พอสำหรับโอนเข้าเป้าหมายนี้',
    'cancel': 'ยกเลิก',
    'transfer': 'โอนเงิน',
    'enter_valid_amount': 'กรุณากรอกจำนวนเงินให้ถูกต้อง',

    // ---------------- Add Goal Saving ----------------
    'goal_name_hint': 'ชื่อเป้าหมาย',
    'target_date_label': 'วันที่ต้องการให้ถึงเป้าหมาย',
    'fill_name_and_amount': 'กรุณากรอกชื่อและจำนวนเงินเป้าหมาย',

    // ---------------- Statistic ----------------
    'statistic_title': 'สถิติ',
    'most_spent_category': 'หมวดหมู่ที่ใช้จ่ายมากที่สุด',
    'near_target': 'ใกล้ถึงเป้าหมายแล้ว!',

    // ---------------- Period Filter (Home / Statistic) ----------------
    'expense_trend': 'แนวโน้มรายจ่าย',
    'period_day': 'วัน',
    'period_month': 'เดือน',
    'period_year': 'ปี',

    // ---------------- Account Setting ----------------
    'account_setting_title': 'ตั้งค่าบัญชี',
    'account_section': 'บัญชี',
    'manage_profile': 'จัดการโปรไฟล์',
    'password_security': 'รหัสผ่านและความปลอดภัย',
    'language': 'ภาษา',
    'preferences_section': 'การตั้งค่า',
    'about_us': 'เกี่ยวกับเรา',
    'theme': 'ธีม',
    'theme_dark': 'มืด',
    'theme_light': 'สว่าง',
    'transaction_saved': 'บันทึกรายการสำเร็จ',
    'goal_saved': 'บันทึกเป้าหมายสำเร็จ',
    'goal_updated': 'แก้ไขเป้าหมายสำเร็จ',
    'transaction_updated': 'แก้ไขรายการสำเร็จ',
    'transaction_duplicated': 'ทำสำเนารายการสำเร็จ',
    'transaction_deleted': 'ลบรายการสำเร็จ',
    'success_notes': 'แจ้งเตือนเมื่อทำรายการสำเร็จ',
    'dismiss_success_notice': 'ปิดข้อความแจ้งเตือน',
    'enabled': 'เปิดใช้งาน',
    'disabled': 'ปิดใช้งาน',
    'logout': 'ออกจากระบบ',

    // ---------------- Default category names (by category id) ----------------
    'cat_c01': 'อาหาร',
    'cat_c02': 'เครื่องดื่ม',
    'cat_c03': 'ที่พัก',
    'cat_c04': 'ยานพาหนะ',
    'cat_c05': 'ภาษี',
    'cat_c06': 'ช้อปปิ้ง',
    'cat_c07': 'ของขวัญ',
    'cat_c08': 'ท่องเที่ยว',
    'cat_c09': 'ความงาม',
    'cat_c10': 'บันเทิง',
    'cat_c11': 'กีฬา',
    'cat_c12': 'สัตว์เลี้ยง',
    'cat_c13': 'การศึกษา',
    'cat_c14': 'เงินเดือน',
    'cat_c15': 'รายได้เสริม',
    'cat_c16': 'โบนัส',
    'cat_c17': 'เงินออม',

    // ---------------- Custom category (Other) ----------------
    'other_category': 'อื่นๆ',
    'add_custom_category_title': 'เพิ่มหมวดหมู่ใหม่',
    'category_name_hint': 'ชื่อหมวดหมู่',
    'please_enter_category_name': 'กรุณากรอกชื่อหมวดหมู่',
    'choose_icon': 'เลือกไอคอน',
    'add': 'เพิ่ม',
    'edit_username': 'แก้ไขชื่อผู้ใช้',
    'display_name': 'ชื่อที่แสดง',
    'username_hint': 'ชื่อผู้ใช้',
    'enter_username': 'กรุณากรอกชื่อผู้ใช้',
    'save_action': 'บันทึก',
    'choose_language': 'เลือกภาษา',
    'about_title': 'เกี่ยวกับ BUDGETMATE',
    'about_body':
        'BUDGETMATE คือแอปช่วยจัดการรายรับ-รายจ่ายและเป้าหมายการออมเงินส่วนตัว '
            'พัฒนาโดยนิสิตคณะวิศวกรรมศาสตร์ มหาวิทยาลัยเกษตรศาสตร์\n\nเวอร์ชัน 1.0.0',
    'close': 'ปิด',
    'take_photo': 'ถ่ายรูปใหม่',
    'choose_from_gallery': 'เลือกจากคลังภาพ',
    'remove_photo': 'ลบรูปโปรไฟล์',

    // ---------------- Change Password ----------------
    'current_password': 'รหัสผ่านเดิม',
    'current_password_hint': 'กรอกรหัสผ่านปัจจุบัน',
    'new_password': 'รหัสผ่านใหม่',
    'new_password_hint': 'อย่างน้อย 6 ตัวอักษร',
    'confirm_new_password': 'ยืนยันรหัสผ่านใหม่',
    'confirm_new_password_hint': 'กรอกรหัสผ่านใหม่อีกครั้ง',
    'enter_current_password': 'กรุณากรอกรหัสผ่านเดิม',
    'password_min_length': 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
    'password_mismatch': 'รหัสผ่านใหม่ไม่ตรงกัน',
    'change_password_success': 'เปลี่ยนรหัสผ่านสำเร็จ',
    'save_new_password': 'บันทึกรหัสผ่านใหม่',

    // ---------------- Forgot Password ----------------
    'forgot_password_title': 'ลืมรหัสผ่าน',
    'reset_password_heading': 'รีเซ็ตรหัสผ่าน',
    'reset_password_desc':
        'กรอกอีเมลที่ใช้สมัครสมาชิก ระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้ทางอีเมล',
    'email': 'อีเมล',
    'enter_email': 'กรุณากรอกอีเมล',
    'enter_new_password': 'กรุณากรอกรหัสผ่านใหม่',
    'password_not_match': 'รหัสผ่านไม่ตรงกัน',
    'reset_success': 'ตั้งรหัสผ่านใหม่สำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่',
    'reset_email_sent':
        'ส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปยังอีเมลของคุณแล้ว กรุณาตรวจสอบกล่องจดหมาย',
    'back_to_login': 'กลับไปหน้าเข้าสู่ระบบ',

    // ---------------- Login ----------------
    'app_name': 'BUDGETMATE',
    'login_subtitle': 'เข้าสู่ระบบเพื่อจัดการเงินของคุณ',
    'login': 'เข้าสู่ระบบ',
    'register': 'สมัครสมาชิก',
    'email_hint': 'อีเมล',
    'password_hint': 'รหัสผ่าน',
    'sign_in': 'เข้าสู่ระบบ',
    'forgot_password_q': 'ลืมรหัสผ่าน?',
    'login_error': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',

    // ---------------- Register ----------------
    'create_account': 'สร้างบัญชีใหม่',
    'register_subtitle': 'เริ่มจัดการเงินของคุณกับ BUDGETMATE',
    'name_hint': 'ชื่อ',
    'confirm_password_hint': 'ยืนยันรหัสผ่าน',
    'sign_up': 'สมัครสมาชิก',
    'already_have_account': 'มีบัญชีอยู่แล้ว? ',
    'fill_all_fields': 'กรุณากรอกข้อมูลให้ครบถ้วน',
    'email_in_use': 'อีเมลนี้ถูกใช้งานแล้ว',

    // ---------------- Language Setup ----------------
    'setup_title': 'ตั้งค่าเริ่มต้น',
    'setup_desc': 'เลือกภาษาและสกุลเงินที่คุณต้องการใช้',
    'language_label': 'ภาษา',
    'currency_label': 'สกุลเงิน',
    'next': 'ถัดไป',

    // ---------------- Splash / Loading ----------------
    'splash_tagline': 'จัดการเงินของคุณให้เป็นเรื่องง่าย',

    // ---------------- DataService error messages ----------------
    'please_login_first': 'กรุณาเข้าสู่ระบบก่อน',
    'account_not_found': 'ไม่พบบัญชีที่ใช้อีเมลนี้ในระบบ',
    'wrong_current_password': 'รหัสผ่านเดิมไม่ถูกต้อง',
    'goal_not_found': 'ไม่พบเป้าหมายนี้',
    'transfer_failed': 'เกิดข้อผิดพลาด ไม่สามารถโอนเงินได้ กรุณาลองใหม่อีกครั้ง',
    'insufficient_ledger_prefix': 'ยอดเงินคงเหลือใน Ledger ไม่เพียงพอ (คงเหลือ',
    'amount_exceeds_prefix': 'จำนวนเงินเกินยอดที่ต้องการอีก (ต้องการอีก',
  };

  static const Map<String, String> _en = {
    'password_max_length': 'Password exceeds the 128-character limit. Choose a shorter password.',
    'password_lowercase': 'At least 1 lowercase letter (a–z)',
    'password_uppercase': 'At least 1 uppercase letter (A–Z)',
    'password_digit': 'At least 1 number (0–9)',
    'password_symbol': 'At least 1 symbol, such as ! @ #',
    'password_common': 'This password is too common. Choose a different, unique passphrase.',
    'password_valid': 'Password meets the requirements',
    'password_confirmed': 'Passwords match',

    'edit': 'Edit',
    'delete': 'Delete',
    'all': 'All',
    'no_income_data': 'No income data',
    'edit_goal': 'Edit goal',
    'pin_goal': 'Pin to home',
    'unpin_goal': 'Unpin from home',
    'manage_goal': 'Manage goal',
    'delete_goal_confirm': 'Delete this goal?',
    'delete_goal_notice': 'Only the goal is deleted. Past transfers and your wallet balance stay unchanged.',
    'enter_confirm_password': 'Please confirm your password',
    'password_requirements': 'Use at least 6 characters and meet each requirement below',
    'target_below_saved': 'Target cannot be less than current savings',

    'nav_home': 'Home',
    'nav_wallet': 'Wallet',
    'nav_add': 'Add',
    'nav_stat': 'Stats',
    'nav_menu': 'Menu',

    'greeting': 'Hello',
    'default_user': 'User',
    'total_income': 'Total Income',
    'total_expense': 'Total Expense',
    'net_balance': 'Net Balance',
    'total_expenses_6m': 'Total Expenses (Last 6 Months)',

    'history': 'History',
    'filter_all': 'All',
    'filter_daily': 'Daily',
    'no_transactions': 'No transactions yet',
    'no_expense_data': 'No expense data yet',
    'today': 'TODAY',
    'yesterday': 'YESTERDAY',

    'wallet_title': 'Wallet',
    'wallet_header': 'BUDGETMATE WALLET',
    'total_balance': 'Total Balance',
    'income_expense': 'Income/Expense',
    'income': 'Income',
    'expense': 'Expense',
    'goal_saving': 'Goal Saving',
    'goals_in_progress': 'goals in progress',

    'back_home': 'Back to Home',
    'incomes_tab': 'Incomes',
    'expenses_tab': 'Expenses',
    'save': 'SAVE',
    'categories': 'Categories',
    'note_optional': 'Note (optional)',
    'items_added': 'Items added',
    'tap_to_edit': '(tap to edit)',
    'editing': 'Editing',
    'cancel_edit': 'Cancel',
    'select_category_prompt': 'Select a category above, then enter the amount',
    'selected_category': 'Selected category',
    'no_categories_for_type': 'No categories for this type yet',
    'showing_categories': 'Showing all',
    'items_unit': 'items',
    'enter_amount': 'Please enter an amount',
    'select_category': 'Please select a category',
    'add_at_least_one': 'Please add at least one item',
    'save_failed': 'Save failed',

    'ledger_balance': 'BUDGETMATE\nLedger Balance',
    'no_goals': 'No savings goals yet',
    'deposit_title': 'Deposit to goal',
    'ledger_remaining': 'Ledger balance',
    'needed_more': 'Needed',
    'quarter': '25%',
    'half': '50%',
    'full_remaining': 'Full remaining',
    'insufficient_balance': 'Ledger balance is insufficient to transfer to this goal',
    'cancel': 'Cancel',
    'transfer': 'Transfer',
    'enter_valid_amount': 'Please enter a valid amount',

    'goal_name_hint': 'Goal name',
    'target_date_label': 'Target date',
    'fill_name_and_amount': 'Please enter goal name and target amount',

    'statistic_title': 'Statistic',
    'most_spent_category': 'Most spent category',
    'near_target': 'Almost there!',

    // ---------------- Period Filter (Home / Statistic) ----------------
    'expense_trend': 'Expense Trend',
    'period_day': 'Day',
    'period_month': 'Month',
    'period_year': 'Year',

    'account_setting_title': 'Account Setting',
    'account_section': 'Account',
    'manage_profile': 'Manage Profile',
    'password_security': 'Password & Security',
    'language': 'Language',
    'preferences_section': 'Preferences',
    'about_us': 'About Us',
    'theme': 'Theme',
    'theme_dark': 'Dark',
    'theme_light': 'Light',
    'transaction_saved': 'Transaction saved successfully',
    'goal_saved': 'Goal saved successfully',
    'goal_updated': 'Goal updated successfully',
    'transaction_updated': 'Transaction updated successfully',
    'transaction_duplicated': 'Transaction duplicated successfully',
    'transaction_deleted': 'Transaction deleted successfully',
    'success_notes': 'Success Notes',
    'dismiss_success_notice': 'Dismiss notification',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'logout': 'Log out',

    // ---------------- Default category names (by category id) ----------------
    'cat_c01': 'Food',
    'cat_c02': 'Drinks',
    'cat_c03': 'Housing',
    'cat_c04': 'Transport',
    'cat_c05': 'Tax',
    'cat_c06': 'Shopping',
    'cat_c07': 'Gifts',
    'cat_c08': 'Travel',
    'cat_c09': 'Beauty',
    'cat_c10': 'Entertainment',
    'cat_c11': 'Sports',
    'cat_c12': 'Pets',
    'cat_c13': 'Education',
    'cat_c14': 'Salary',
    'cat_c15': 'Side Income',
    'cat_c16': 'Bonus',
    'cat_c17': 'Savings',

    // ---------------- Custom category (Other) ----------------
    'other_category': 'Other',
    'add_custom_category_title': 'Add new category',
    'category_name_hint': 'Category name',
    'please_enter_category_name': 'Please enter a category name',
    'choose_icon': 'Choose icon',
    'add': 'Add',
    'edit_username': 'Edit username',
    'display_name': 'Display name',
    'username_hint': 'Username',
    'enter_username': 'Please enter a username',
    'save_action': 'Save',
    'choose_language': 'Choose language',
    'about_title': 'About BUDGETMATE',
    'about_body':
        'BUDGETMATE is an app that helps you manage income, expenses, and personal savings goals. '
            'Developed by engineering students at Kasetsart University.\n\nVersion 1.0.0',
    'close': 'Close',
    'take_photo': 'Take a new photo',
    'choose_from_gallery': 'Choose from gallery',
    'remove_photo': 'Remove photo',

    'current_password': 'Current password',
    'current_password_hint': 'Enter current password',
    'new_password': 'New password',
    'new_password_hint': 'At least 6 characters',
    'confirm_new_password': 'Confirm new password',
    'confirm_new_password_hint': 'Re-enter new password',
    'enter_current_password': 'Please enter your current password',
    'password_min_length': 'Password must be at least 6 characters',
    'password_mismatch': 'New passwords do not match',
    'change_password_success': 'Password changed successfully',
    'save_new_password': 'Save new password',

    'forgot_password_title': 'Forgot Password',
    'reset_password_heading': 'Reset password',
    'reset_password_desc':
        'Enter the email you registered with and we will send you a link to set a new password',
    'email': 'Email',
    'enter_email': 'Please enter your email',
    'enter_new_password': 'Please enter a new password',
    'password_not_match': 'Passwords do not match',
    'reset_success': 'Password reset successful, please log in with your new password',
    'reset_email_sent': 'We\'ve sent a password reset link to your email. Please check your inbox.',
    'back_to_login': 'Back to login',

    'app_name': 'BUDGETMATE',
    'login_subtitle': 'Log in to manage your money',
    'login': 'Login',
    'register': 'Register',
    'email_hint': 'Email',
    'password_hint': 'Password',
    'sign_in': 'Sign In',
    'forgot_password_q': 'Forgot password?',
    'login_error': 'Invalid email or password',

    'create_account': 'Create a new account',
    'register_subtitle': 'Start managing your money with BUDGETMATE',
    'name_hint': 'Name',
    'confirm_password_hint': 'Confirm Password',
    'sign_up': 'Sign Up',
    'already_have_account': 'Already have an account? ',
    'fill_all_fields': 'Please fill in all fields',
    'email_in_use': 'This email is already in use',

    'setup_title': 'Initial Setup',
    'setup_desc': 'Choose your preferred language and currency',
    'language_label': 'Language',
    'currency_label': 'Currency',
    'next': 'Next',

    'splash_tagline': 'Managing your money made easy',

    // ---------------- DataService error messages ----------------
    'please_login_first': 'Please log in first',
    'account_not_found': 'No account found with this email',
    'wrong_current_password': 'Current password is incorrect',
    'goal_not_found': 'Goal not found',
    'transfer_failed': 'Something went wrong. Could not transfer. Please try again.',
    'insufficient_ledger_prefix': 'Insufficient ledger balance (balance',
    'amount_exceeds_prefix': 'Amount exceeds what is still needed (needed',
  };

  static Map<String, String> of(String? language) =>
      language == 'English' ? _en : _th;
}
```

### 13.41 flutter_application_1/lib/services/data_service.dart

ศูนย์กลางบัญชี สถานะในหน่วยความจำ การบันทึก/แก้/ลบ กฎยอดออม การรวมยอด และค่าตั้ง; เขียนฐานข้อมูลก่อนอัปเดต list แล้ว notifyListeners เพื่อให้หน้าจอสะท้อนผลสำเร็จ

โครงสร้างที่ประกาศ: class DataService extends ChangeNotifier (L40)

1,008 บรรทัด • SHA-256: 5ee0575e1c5d2f7c

```dart
import 'password_policy.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
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
import 'app_strings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _setupDoneKey = 'budgetmate_setup_completed';
const _defaultLangKey = 'budgetmate_default_language';
const _defaultCurrencyKey = 'budgetmate_default_currency';
const _themeModeKey = 'budgetmate_theme_mode'; // 'light' | 'dark'
const _successNotesKey = 'budgetmate_success_notes_enabled';

/// DataService รวบรวมการทำงานของระบบทั้งหมดตามขอบเขตโครงงาน (1.3.1 - 1.3.4)
/// เวอร์ชันนี้เก็บข้อมูลจริงลง Firestore ผ่าน DBHelper ทุกจุดแล้ว (แก้บั๊ก
/// offlineMode เดิมที่ทำให้รายการรายรับ-รายจ่ายไม่ถูกบันทึกจริง และแก้บั๊ก
/// หมวดหมู่ที่ไม่เคยซิงก์กับ Firestore)
/// - รายการ/เป้าหมายจะถูกโหลดเฉพาะของผู้ใช้ที่ล็อกอินอยู่ (currentUser)
/// - การยืนยันตัวตนทั้งหมด (สมัครสมาชิก/ล็อกอินด้วยอีเมล/ล็อกอินด้วย Google/ลืมรหัสผ่าน/
///   เปลี่ยนรหัสผ่าน) เชื่อมต่อกับ Firebase Authentication โดยตรง ไม่มีการเก็บรหัสผ่าน
///   หรือทำ hash เองในแอปอีกต่อไป ส่วนข้อมูลโปรไฟล์ (ชื่อ/ภาษา/สกุลเงิน/รูปโปรไฟล์ ฯลฯ)
///   เก็บใน Firestore โดยใช้ uid จาก Firebase Auth เป็น document id
/// - สถานะล็อกอินถูกจำไว้โดย Firebase Authentication เองโดยอัตโนมัติ จึงไม่ต้อง
///   ล็อกอินใหม่ทุกครั้งที่เปิดแอป
/// - รูปโปรไฟล์เก็บเป็น Base64 string ลง Firestore โดยตรง (ไม่ใช้ Firebase Storage
///   เพราะ Storage บังคับต้องอัปเกรดเป็นแผน Blaze/ผูกบัตรเครดิต ส่วนโปรเจกต์นี้
///   อยู่บนแผน Spark ฟรี) รูปจะถูกย่อ/บีบอัดให้เล็กก่อนเก็บเสมอ เพื่อไม่ให้เกิน
///   ขีดจำกัด 1 MiB ต่อเอกสารที่ Firestore กำหนดไว้
class DataService extends ChangeNotifier {
  final _uuid = const Uuid();
  final DBHelper _db;

  DataService({DBHelper? database}) : _db = database ?? DBHelper.instance;

  Map<String, dynamic> _toStored(Map<String, dynamic> data) => data;
  Map<String, dynamic> _toDisplay(Map<String, dynamic> data) => {
    ...data, 'currency': data['currency'] ?? currentUser?.ledgerCurrency ?? 'THB',
  };
  Future<void> setCurrency(String currency) async {
    if (!supportedCurrencies.contains(currency)) throw ArgumentError('Unsupported currency');
    final user = currentUser;
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultCurrencyKey, currency);
      _defaultCurrency = currency;
    } else {
      await _db.update('users', {
        'currency': currency, 'ledger_currency': user.ledgerCurrency,
      }, 'id = ?', [user.id]);
      user.currency = currency;
    }
    notifyListeners();
  }
  Iterable<TransactionModel> get _activeTransactions => _transactions.where(
    (entry) => (entry.currency ?? currentUser?.ledgerCurrency ?? 'THB') == currentCurrency);

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ---------------- User session ----------------
  UserModel? currentUser;
  bool isReady = false;
  bool _googleLoginCreatedAccount = false;
  bool get googleLoginCreatedAccount => _googleLoginCreatedAccount;

  // ---------------- Profile picture (แคชไฟล์ในเครื่องไว้แสดงผลเร็วในเซสชันนี้) ----------------
  // แหล่งข้อมูลจริงคือ currentUser.avatarBase64 (มาจาก Firestore) ซึ่งตามบัญชีไป
  // ทุกเครื่อง — avatarPath นี้เป็นแค่แคชไฟล์ในเครื่องเพื่อความเร็ว ไม่ใช่แหล่งข้อมูลหลัก
  String? avatarPath;

  // ---------------- ธีมของแอป (Light/Dark) ----------------
  ThemeMode themeMode = ThemeMode.light;

  // ---------------- ภาษาปัจจุบันของแอป ----------------
  // ใช้ currentUser?.language ถ้าล็อกอินอยู่ ไม่งั้น fallback ไปที่ค่า default
  // ที่ตั้งไว้ตอน setup (หน้า My wallet) เพื่อให้หน้าก่อนล็อกอิน (Login/Register/
  // Language Setup) เปลี่ยนภาษาได้เช่นกัน
  String _defaultLanguage = 'ไทย';
  String _defaultCurrency = 'THB';
  static const supportedCurrencies = ['THB', 'USD', 'EUR', 'JPY', 'GBP'];
  String get currentCurrency => currentUser?.currency ?? _defaultCurrency;
  String get currencySymbol => const {'THB':'฿','USD':'\$','EUR':'€','JPY':'¥','GBP':'£'}[currentCurrency] ?? currentCurrency;
  String formatMoney(num amount) => NumberFormat.currency(
    locale: currentLanguage == 'English' ? 'en_US' : 'th_TH',
    name: currentCurrency, symbol: currencySymbol, decimalDigits: 2,
  ).format(amount);

  String get currentLanguage => currentUser?.language ?? _defaultLanguage;

  /// แปลข้อความตาม key จาก AppStrings ตามภาษาปัจจุบันของแอป
  /// เรียกใช้ผ่าน context.watch<DataService>().t('key') ในทุกหน้า
  /// เพื่อให้ UI รีเฟรชเป็นภาษาใหม่ทันทีเมื่อ notifyListeners() ถูกเรียก
  String t(String key) => AppStrings.of(currentLanguage)[key] ?? key;

  /// แปลชื่อหมวดหมู่ตามภาษาปัจจุบัน สำหรับหมวดหมู่เริ่มต้นของระบบ (c01-c17)
  /// ซึ่งชื่อถูก seed ไว้เป็นภาษาไทยตายตัวใน Firestore ตั้งแต่แรก (ไม่ได้ผูกกับภาษา UI)
  /// จึงต้องแปลผ่าน key 'cat_<id>' แทนการอ่านชื่อจากฐานข้อมูลตรงๆ
  /// หมวดหมู่ที่ผู้ใช้สร้างเองเพิ่มเติม (id ไม่ตรงกับ c01-c17) จะใช้ชื่อเดิมตามที่ผู้ใช้ตั้งไว้
  String categoryName(CategoryModel category) {
    final strings = AppStrings.of(currentLanguage);
    return strings['cat_${category.id}'] ?? category.name;
  }

  /// เปลี่ยนภาษาทั้งแอปทันที ใช้ได้ทั้งก่อนและหลังล็อกอิน
  /// - ถ้าล็อกอินอยู่: บันทึกลงโปรไฟล์ผู้ใช้ใน Firestore ผ่าน updateProfile
  /// - ถ้ายังไม่ล็อกอิน: บันทึกเป็นค่า default ใน SharedPreferences
  Future<void> setLanguage(String language) async {
    if (currentUser != null) {
      await updateProfile(language: language);
    } else {
      _defaultLanguage = language;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultLangKey, language);
      notifyListeners();
    }
  }

  // ---------------- การแจ้งเตือนเมื่อทำรายการสำเร็จ (Success Notes) ----------------
  bool successNotesEnabled = true;

  // ---------------- Category (โหลดจาก Firestore ครั้งเดียวตอนเริ่มแอป) ----------------
  final List<CategoryModel> categories = [];

  // ---------------- Transaction (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions {
    final sorted = [..._activeTransactions]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  // ---------------- Goal Saving (เฉพาะของผู้ใช้ที่ล็อกอินอยู่) ----------------
  final List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals.where((g) => (g.currency ?? currentUser?.ledgerCurrency ?? 'THB') == currentCurrency));

  // =========================================================
  // เริ่มต้นระบบ: seed หมวดหมู่เริ่มต้น + กู้คืน session ที่ล็อกอินค้างไว้
  // เรียกครั้งเดียวจาก LoadingScreen ก่อนเข้าแอป
  // =========================================================
  Future<void> init() async {
    categories
      ..clear()
      ..addAll(defaultCategories);

    final prefs = await SharedPreferences.getInstance();
    themeMode = (prefs.getString(_themeModeKey) ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    successNotesEnabled = prefs.getBool(_successNotesKey) ?? true;
    _defaultLanguage = prefs.getString(_defaultLangKey) ?? 'ไทย';
    _defaultCurrency = prefs.getString(_defaultCurrencyKey) ?? 'THB';

    // Firebase Authentication จำสถานะล็อกอินไว้ให้เองอยู่แล้ว (persistent session)
    // จึงเช็คแค่ว่ามีผู้ใช้ที่ล็อกอินค้างอยู่หรือไม่ แล้วโหลดโปรไฟล์ที่ตรงกันจาก Firestore
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      try {
        final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);
        if (rows.isNotEmpty) {
          currentUser = UserModel.fromMap(rows.first);
          avatarPath = prefs.getString('avatar_path_${currentUser!.id}');
          await _loadUserData();
        }
      } catch (e) {
        // เชื่อมต่อ Firestore ไม่ได้ตอนเปิดแอป (เน็ตช้า/หลุด) - ปล่อยให้เข้าหน้า Login
        // ตามปกติแทนที่จะค้างที่ Loading ตลอดไป ผู้ใช้ล็อกอินใหม่ได้เองเมื่อเน็ตกลับมา
        currentUser = null;
      }
    }
    isReady = true;
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    final rows = await _db.query('categories');
    categories
      ..clear()
      ..addAll(defaultCategories)
      ..addAll(rows.map(CategoryModel.fromMap).expand((c) => [c, ...c.childCategories]));
  }

  CategoryModel _categoryById(String id) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories.isNotEmpty ? categories.first : defaultCategories.first,
    );
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    await _loadCategories();
    final txRows = await _db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
      orderBy: 'date ASC',
    );
    final goalRows = await _db.query(
      'goals',
      where: 'user_id = ?',
      whereArgs: [currentUser!.id],
    );
    _transactions
      ..clear()
      ..addAll(txRows.map(
          (r) => TransactionModel.fromMap(_toDisplay(r), _categoryById(r['category_id'] as String))));

    _goals
      ..clear()
      ..addAll(goalRows.map((r) => GoalModel.fromMap(_toDisplay(r))));
  }

  Future<void> refreshData() async {
    await _loadUserData();
    notifyListeners();
  }

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
    if (currentUser != null) {
      await updateProfile(language: language, currency: currency);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultLangKey, language);
    await prefs.setString(_defaultCurrencyKey, currency);
    await prefs.setBool(_setupDoneKey, true);
    _defaultLanguage = language;
    _defaultCurrency = currency;
    notifyListeners();
  }

  Future<Map<String, String>> getDefaultPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'language': prefs.getString(_defaultLangKey) ?? 'ไทย',
      'currency': prefs.getString(_defaultCurrencyKey) ?? 'THB',
    };
  }

  // =========================================================
  // AUTHENTICATION (หน้า Login / Register) - เชื่อมต่อกับ Firebase Authentication
  // =========================================================
  /// สมัครสมาชิกด้วยอีเมล/รหัสผ่านผ่าน Firebase Authentication โดยตรง
  /// (Firebase เป็นผู้ตรวจสอบอีเมลซ้ำ/ความยาวรหัสผ่านให้ ไม่ต้องเช็คเองในแอปอีก)
  /// จากนั้นจึงบันทึกข้อมูลโปรไฟล์ (ชื่อ/ภาษา/สกุลเงิน) ลง Firestore โดยใช้ uid เป็น id
  Future<String?> register(String name, String email, String password) async {
    final invalid = passwordValidationKey(password);
    if (invalid != null) return t(invalid);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw FirebaseAuthException(
          code: 'network-timeout',
          message: 'เชื่อมต่อ Firebase ไม่ได้ (หมดเวลา 15 วินาที) - เช็คการเชื่อมต่ออินเทอร์เน็ต',
        ),
      );
      final fbUser = cred.user;
      if (fbUser == null) return t('save_failed');
      await fbUser.updateDisplayName(name);

      final defaults = await getDefaultPreferences();
      final user = UserModel(
        id: fbUser.uid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        language: defaults['language']!,
        currency: defaults['currency']!,
      );
      await _db.insert('users', user.toMap());

      currentUser = user;
      _transactions.clear();
      _goals.clear();
      avatarPath = null;
      categories..clear()..addAll(defaultCategories);

      notifyListeners();
      return null; // สำเร็จ
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return t('email_in_use');
        case 'weak-password':
          return t('password_min_length');
        default:
          return e.message ?? t('save_failed');
      }
    } catch (e) {
      // เผื่อกรณี error ที่ไม่ใช่ FirebaseAuthException โดยตรง เช่น เขียน Firestore
      // ไม่สำเร็จ หรือเน็ตหลุด - ต้อง return ข้อความเสมอ ไม่ปล่อยให้ throw หลุดออกไป
      // ไม่งั้นหน้าสมัครสมาชิกจะค้างสถานะ loading ตลอดไปเพราะ setState ไม่ถูกเรียก
      return '${t('save_failed')}: $e';
    }
  }

  /// เข้าสู่ระบบด้วยอีเมล/รหัสผ่านผ่าน Firebase Authentication โดยตรง
  Future<String?> login(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) return t('login_error');

      final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);
      UserModel user;
      if (rows.isEmpty) {
        // เผื่อกรณีมีบัญชีใน Firebase Auth อยู่แล้วแต่ยังไม่มีโปรไฟล์ใน Firestore
        final defaults = await getDefaultPreferences();
        user = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? email.split('@').first,
          email: email,
          createdAt: DateTime.now(),
          language: defaults['language']!,
          currency: defaults['currency']!,
        );
        await _db.insert('users', user.toMap());
      } else {
        user = UserModel.fromMap(rows.first);
      }

      currentUser = user;
      await _loadUserData();

      final prefs = await SharedPreferences.getInstance();
      avatarPath = prefs.getString('avatar_path_${user.id}');

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (_) {
      return t('login_error');
    } catch (e) {
      return '${t('login_error')}: $e';
    }
  }

  /// เข้าสู่ระบบ/สมัครสมาชิกอัตโนมัติด้วยบัญชี Google
  /// คืนค่า null หากสำเร็จ หรือข้อความ error หากไม่สำเร็จ/ผู้ใช้ยกเลิก
  Future<String?> loginWithGoogle() async {
    _googleLoginCreatedAccount = false;
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return t('login_error'); // ผู้ใช้กดยกเลิก

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCred.user;
      if (fbUser == null || fbUser.email == null) return t('login_error');

      // ใช้ uid ของ Firebase Auth เป็น document id เสมอ (แหล่งอ้างอิงเดียวกับ
      // register/login แบบอีเมล-รหัสผ่าน) เพื่อไม่ให้บัญชี Google กับบัญชีอีเมลชนกัน
      final rows = await _db.query('users', where: 'id = ?', whereArgs: [fbUser.uid]);

      UserModel user;
      if (rows.isEmpty) {
        // ยังไม่เคยมีโปรไฟล์ -> สร้างให้อัตโนมัติ (Firebase Auth ดูแลเรื่องรหัสผ่านให้แล้ว)
        final defaults = await getDefaultPreferences();
        user = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? fbUser.email!.split('@').first,
          email: fbUser.email!,
          createdAt: DateTime.now(),
          language: defaults['language']!,
          currency: defaults['currency']!,
        );
        await _db.insert('users', user.toMap());
      } else {
        user = UserModel.fromMap(rows.first);
      }

      currentUser = user;
      await _loadUserData();

      final prefs = await SharedPreferences.getInstance();
      avatarPath = prefs.getString('avatar_path_${user.id}');

      _googleLoginCreatedAccount = rows.isEmpty;
      notifyListeners();
      return null;
    } catch (e) {
      return '${t('login_error')}: $e';
    }
  }

  /// รีเซ็ตรหัสผ่านด้วยอีเมล (หน้า Forgot Password)
  /// ส่งอีเมลลิงก์รีเซ็ตรหัสผ่านผ่าน Firebase Authentication โดยตรง (sendPasswordResetEmail)
  /// ผู้ใช้จะตั้งรหัสผ่านใหม่จากลิงก์ในอีเมล ไม่ใช่กรอกในแอปอีกต่อไป
  /// คืนค่า null หากส่งอีเมลสำเร็จ หรือข้อความ error หากไม่พบบัญชีที่ใช้อีเมลนี้
  Future<String?> resetPassword(String email) async {
    try {
      final lang = currentLanguage == 'English' ? 'en' : 'th';
      await FirebaseAuth.instance.setLanguageCode(lang);
      final actionCodeSettings = ActionCodeSettings(
        url:
            'https://budgetmate-app-a94da.web.app/reset_password.html?lang=$lang',
        handleCodeInApp: false,
      );
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          return t('account_not_found');
        default:
          return e.message ?? t('account_not_found');
      }
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    currentUser = null;
    avatarPath = null;
    categories..clear()..addAll(defaultCategories);
    _transactions.clear();
    _goals.clear();
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? language, String? currency}) async {
    if (currentUser == null) return;
    final user = currentUser!;
    if (currency != null && currency != user.currency) {
      await setCurrency(currency);
    }
    final changes = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (language != null) 'language': language,
      
    };
    if (name != null && name.trim().isEmpty) throw ArgumentError(t('enter_username'));
    await _db.update('users', changes, 'id = ?', [user.id]);
    if (name != null) user.name = name.trim();
    if (language != null) user.language = language;

    notifyListeners();
  }

  /// เปิดตัวเลือกรูปภาพ (กล้อง/คลังภาพ) แล้วเข้ารหัสเป็น Base64 บันทึกลง Firestore
  /// โดยตรง (ฟิลด์ avatar_base64 ในเอกสาร users/{uid}) เพื่อให้รูปโปรไฟล์ "ตามไปทุก
  /// เครื่อง" ที่ล็อกอินด้วยบัญชีเดียวกัน โดยไม่ต้องใช้ Firebase Storage (ซึ่งบังคับ
  /// ต้องอัปเกรดเป็นแผน Blaze/ผูกบัตรเครดิต — โปรเจกต์นี้อยู่บนแผน Spark ฟรี)
  ///
  /// ย่อขนาดรูป (maxWidth 480px) และบีบอัดคุณภาพ (imageQuality 60) ตั้งแต่ตอนเลือก
  /// รูป เพื่อให้ไฟล์เล็กพอที่จะเก็บเป็น Base64 ในเอกสาร Firestore เดียวได้โดยไม่เกิน
  /// ขีดจำกัด 1 MiB ต่อเอกสาร (รูปโปรไฟล์วงกลมเล็กๆ ไม่จำเป็นต้องมีความละเอียดสูง)
  ///
  /// ยังคงแคชไฟล์ไว้ในเครื่องด้วย (avatarPath) เพื่อความเร็ว แต่แหล่งข้อมูลจริงคือ
  /// avatarBase64 ใน Firestore
  Future<bool> pickAvatar({required bool fromCamera}) async {
    if (currentUser == null) return false;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 480,
      imageQuality: 60,
    );
    if (picked == null) return false;

    final bytes = await picked.readAsBytes();

    const maxRawBytes = 700 * 1024;
    if (bytes.length > maxRawBytes) {
      throw StateError('รูปภาพใหญ่เกินไป กรุณาเลือกรูปที่เล็กลง');
    }
    final user = currentUser!;
    final encoded = base64Encode(bytes);
    await _db.update('users', {'avatar_base64': encoded}, 'id = ?', [user.id]);
    user.avatarBase64 = encoded;
    avatarPath = null;
    notifyListeners();
    // Cache is optional; a local file error must not undo a successful cloud save.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savedPath = '${dir.path}/avatar_${user.id}.jpg';
      await File(savedPath).writeAsBytes(bytes);
      avatarPath = savedPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path_${user.id}', savedPath);
    } catch (e) {
      debugPrint('Avatar cache unavailable: $e');
    }
    notifyListeners();
    return true;
  }

  Future<void> removeAvatar() async {
    final user = currentUser;
    if (user == null) return;
    await _db.update('users', {'avatar_base64': null}, 'id = ?', [user.id]);
    user.avatarBase64 = null;
    avatarPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('avatar_path_${user.id}');
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
  /// ยืนยันตัวตนซ้ำ (reauthenticate) กับ Firebase Authentication ด้วยรหัสผ่านเดิม
  /// ก่อนอัปเดตเป็นรหัสผ่านใหม่ (ผู้ใช้ที่ล็อกอินด้วย Google เท่านั้นที่จะไม่มีรหัสผ่านให้เปลี่ยน)
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final invalid = passwordValidationKey(newPassword);
    if (invalid != null) return t(invalid);
    if (currentUser == null) return t('please_login_first');
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.email == null) return t('please_login_first');

    try {
      final credential = EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return t('wrong_current_password');
        case 'weak-password':
          return t('password_min_length');
        default:
          return e.message ?? t('wrong_current_password');
      }
    }
  }

  // =========================================================
  // 1.3.1 ระบบฟังก์ชันบันทึกรายรับ-รายจ่าย
  // =========================================================
  /// บันทึกรายการรายรับ/รายจ่ายใหม่ลง Firestore จริงเสมอ
  ///
  /// แก้บั๊กเดิม: มีแฟล็ก `offlineMode` ที่ทำให้โค้ดข้ามการเขียนลง Firestore
  /// (`if (!offlineMode) await _db.insert(...)`) ผลคือรายการที่เพิ่มผ่านหน้า
  /// Add Income/Expense ถูกเก็บไว้แค่ใน memory เท่านั้น พอปิดแอปแล้วเปิดใหม่
  /// (หรือ logout/login ใหม่) รายการทั้งหมดจะหายไป ทั้งที่ผู้ใช้เห็นว่า "บันทึกสำเร็จ"
  /// แล้วก็ตาม — ตอนนี้เขียนลง Firestore เสมอเหมือน editTransaction/deleteTransaction/
  /// addGoal/transferToGoal ที่เขียนจริงอยู่แล้ว และคืนค่า error เป็น String แทนการ
  /// ปล่อยให้ exception หลุดออกไป (เพื่อให้หน้าจอที่เรียกใช้แสดงข้อความ error ได้ตรงจุด)
  Future<String?> addTransaction({
    required CategoryType type,
    required double amount,
    required CategoryModel category,
    required DateTime date,
    String? note,
    String? description,
    String? receiptPath,
  }) async {
    if (currentUser == null) return t('please_login_first');
    if (!amount.isFinite || amount <= 0) return t('enter_valid_amount');
    final tx = TransactionModel(
      id: _uuid.v4(),
      currency: currentCurrency,
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
      receiptPath: receiptPath,
    );
    try {
      await _db.insert('transactions', _toStored(tx.toMap(currentUser!.id)));
    } catch (e) {
      // ไม่เพิ่มเข้า _transactions ถ้าบันทึกลง Firestore ไม่สำเร็จ กัน state
      // ในหน่วยความจำกับข้อมูลจริงใน Firestore ไม่ตรงกัน
      return '${t('save_failed')}: $e';
    }
    _transactions.add(tx);
    notifyListeners();
    return null;
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
    if (currentUser == null) throw StateError(t('please_login_first'));
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) throw StateError('Transaction not found');
    if (amount != null && (!amount.isFinite || amount <= 0)) {
      throw ArgumentError(t('enter_valid_amount'));
    }
    final original = _transactions[index];
    if ((category ?? original.category).type != (type ?? original.type)) {
      throw ArgumentError(t('select_category'));
    }
    final updated = original.copyWith(
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
      description: description,
    );
    if (_transactions[index].description?.startsWith('goal_transfer:') == true) {
      _applyUpdatedGoal(await _db.changeGoalTransfer(id, _toStored(updated.toMap(currentUser!.id))));
    } else {
      await _db.update('transactions', _toStored(updated.toMap(currentUser!.id)), 'id = ?', [id]);
    }
    _transactions[index] = updated;
    notifyListeners();
  }

  void _applyUpdatedGoal(Map<String, dynamic>? data) {
    if (data == null) return;
    final index = _goals.indexWhere((g) => g.id == data['id']);
    if (index != -1) _goals[index] = GoalModel.fromMap(_toDisplay(data));
  }

  Future<void> deleteTransaction(String id) async {
    if (currentUser == null) throw StateError(t('please_login_first'));
    final index = _transactions.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    if (_transactions[index].description?.startsWith('goal_transfer:') == true) {
      _applyUpdatedGoal(await _db.changeGoalTransfer(id, null));
    } else {
      await _db.delete('transactions', 'id = ?', [id]);
    }
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<CategoryModel> addCategory(String name, CategoryType type, IconData icon, {
    int? colorValue, int? artworkNumber, List<String> subcategories = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Category name is required');
    final children = subcategories.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (children.map((s) => s.toLowerCase()).toSet().length != children.length) {
      throw ArgumentError('Duplicate subcategory names');
    }
    final category = CategoryModel(id: _uuid.v4(), name: trimmed, type: type, icon: icon,
      colorValue: colorValue, artworkNumber: artworkNumber,
      subcategories: List.unmodifiable(children));
    await _db.insert('categories', category.toMap());
    categories.addAll([category, ...category.childCategories]);
    notifyListeners();
    return category;
  }

  List<CategoryModel> categoriesByType(CategoryType type) =>
      categories.where((c) => c.type == type).toList();

  // =========================================================
  // 1.3.2 ระบบตั้งเป้าหมายการออม (Goal Saving)
  // =========================================================
  /// คืนค่า null หากบันทึกสำเร็จ หรือข้อความ error หากบันทึกไม่สำเร็จ (เช่น
  /// เชื่อมต่อฐานข้อมูลไม่ได้/หมดเวลา) เดิมเมธอดนี้ปล่อยให้ exception จาก _db.insert
  /// หลุดออกไปแบบ unhandled ทำให้แอป crash และหน้าจอผู้เรียกค้างสถานะ loading ตลอดไป
  Future<String?> addGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    required IconData icon,
    double savedAmount = 0,
    String? note,
    int? artworkNumber,
  }) async {
    if (currentUser == null) return t('please_login_first');
    if (!targetAmount.isFinite || targetAmount <= 0 ||
        !savedAmount.isFinite || savedAmount < 0 || savedAmount > targetAmount) {
      return t('enter_valid_amount');
    }
    final goal = GoalModel(
      id: _uuid.v4(),
      currency: currentCurrency,
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      startDate: DateTime.now(),
      targetDate: targetDate,
      icon: icon,
      artworkNumber: artworkNumber,
      note: note,
      status: savedAmount >= targetAmount ? GoalStatus.completed : GoalStatus.inProgress,
    );
    try {
      await _db.insert('goals', _toStored(goal.toMap(currentUser!.id)));
    } catch (e) {
      return '${t('save_failed')}: $e';
    }
    _goals.add(goal);
    notifyListeners();
    return null;
  }

  /// เพิ่มเงินออมเข้าเป้าหมาย และอัปเดตสถานะอัตโนมัติเมื่อถึงเป้าหมาย
  /// หมายเหตุ: เมธอดนี้ไม่กระทบ Ledger Balance (ไม่สร้างรายจ่าย) — เก็บไว้เพื่อความเข้ากันได้ย้อนหลัง
  /// สำหรับการ "โอนเงินจริง" ที่ต้องหักยอดคงเหลือด้วย ให้ใช้ [transferToGoal] แทน
  Future<void> contributeToGoal(String goalId, double amount) async {
    if (currentUser == null) throw StateError(t('please_login_first'));
    if (!amount.isFinite || amount <= 0) throw ArgumentError(t('enter_valid_amount'));
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) throw StateError(t('goal_not_found'));
    final goal = _goals[index];
    final saved = (goal.savedAmount + amount).clamp(0, goal.targetAmount).toDouble();
    final updated = goal.copyWith(savedAmount: saved,
      status: saved >= goal.targetAmount ? GoalStatus.completed : GoalStatus.inProgress);
    await _db.update('goals', _toStored(updated.toMap(currentUser!.id)), 'id = ?', [goal.id]);
    _goals[index] = updated;
    notifyListeners();
  }

  static const _goalSavingCategoryId = 'c17';

  /// หาหมวดหมู่ "เงินออม" ที่ใช้บันทึกรายจ่ายอัตโนมัติเมื่อโอนเงินเข้าเป้าหมาย
  /// สร้างให้อัตโนมัติถ้ายังไม่มี (เผื่อฐานข้อมูลเก่าที่ seed ไปก่อนเพิ่มหมวดนี้)
  Future<CategoryModel> _ensureGoalSavingCategory() async {
    final existing = categories.where(
        (c) => c.id == _goalSavingCategoryId || c.name == 'เงินออม');
    if (existing.isNotEmpty) return existing.first;

    const category = CategoryModel(
      id: _goalSavingCategoryId,
      name: 'เงินออม',
      type: CategoryType.expense,
      icon: Icons.savings,
      description: 'หมวดหมู่รายจ่ายสำหรับการโอนเงินเข้าเป้าหมายการออม (สร้างอัตโนมัติ)',
      imagePath: 'assets/images/categories/c17.png',
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
    if (currentUser == null) return t('please_login_first');
    if (!amount.isFinite || amount <= 0) return t('enter_valid_amount');

    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) return t('goal_not_found');
    final goal = _goals[goalIndex];

    if (amount > balance) {
      return '${t('insufficient_ledger_prefix')} ${formatMoney(balance)})';
    }

    // แก้บั๊ก: เดิมเมธอดนี้ไม่ตรวจว่าจำนวนที่โอนเกินยอดที่ยังขาดอยู่ของเป้าหมายหรือไม่
    // (ต่างจาก contributeToGoal ที่ clamp ค่า saved_amount ไว้) ทำให้ saved_amount
    // สามารถเกิน target_amount ได้แบบเงียบๆ เมื่อผู้ใช้กรอกจำนวนเกินที่ต้องการอีก
    final remaining = goal.targetAmount - goal.savedAmount;
    if (amount > remaining) {
      return '${t('amount_exceeds_prefix')} ${formatMoney(remaining)})';
    }

    final category = await _ensureGoalSavingCategory();
    final tx = TransactionModel(
      id: _uuid.v4(),
      currency: currentCurrency,
      type: CategoryType.expense,
      amount: amount,
      category: category,
      date: DateTime.now(),
      note: note ?? 'โอนเงินเข้าเป้าหมาย: ${goal.name}',
      description: 'goal_transfer:${goal.id}',
    );

    try {
      final updated = await _db.transferToGoal(
        goal.id, amount, _toStored(tx.toMap(currentUser!.id)),
      );
      _goals[goalIndex] = GoalModel.fromMap(_toDisplay(updated));
      _transactions.add(tx);
    } catch (e) {
      return '${t('transfer_failed')}: $e';
    }

    notifyListeners();
    return null;
  }

  List<GoalModel> get pinnedGoals => goals.where((g) => g.isPinned).toList();

  Future<String?> editGoal(String id, {required String name, required double targetAmount,
      required DateTime targetDate, required IconData icon, String? note, int? artworkNumber}) async {
    if (currentUser == null) return t('please_login_first');
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return t('goal_not_found');
    final goal = _goals[index];
    if (name.trim().isEmpty || !targetAmount.isFinite || targetAmount <= 0) return t('fill_name_and_amount');
    if (targetAmount < goal.savedAmount) return t('target_below_saved');
    final updated = goal.copyWith(name: name.trim(), targetAmount: targetAmount,
      targetDate: targetDate, icon: icon, note: note, artworkNumber: artworkNumber,
      status: goal.savedAmount >= targetAmount ? GoalStatus.completed : GoalStatus.inProgress);
    try {
      await _db.update('goals', _toStored(updated.toMap(currentUser!.id)), 'id = ?', [id]);
    } catch (_) { return t('save_failed'); }
    _goals[index] = updated;
    notifyListeners();
    return null;
  }

  Future<void> setGoalPinned(String id, bool pinned) async {
    if (currentUser == null) throw StateError(t('please_login_first'));
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) throw StateError(t('goal_not_found'));
    final updated = _goals[index].copyWith(isPinned: pinned);
    await _db.update('goals', {'is_pinned': pinned}, 'id = ?', [id]);
    _goals[index] = updated;
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await _db.delete('goals', 'id = ?', [id]);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  /// เป้าหมายที่ใกล้ถึงเป้า (ใช้แจ้งเตือนตามข้อ 1.3.2.2)
  List<GoalModel> get nearingGoals => _goals.where((g) => g.isNearTarget).toList();

  // =========================================================
  // 1.3.3 การแสดงผลข้อมูลทางการเงิน (คำนวณจากข้อมูลที่โหลดไว้ในหน่วยความจำ)
  // =========================================================
  double get totalIncome => _activeTransactions
      .where((t) => t.type == CategoryType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _activeTransactions
      .where((t) => t.type == CategoryType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  double monthlyTotal(CategoryType type, DateTime month) {
    return _activeTransactions
        .where((t) =>
            t.type == type && t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// ยอดรวมของวันใดวันหนึ่ง (ใช้กับกราฟที่เลือกดูแบบ "วัน")
  double dailyTotal(CategoryType type, DateTime day) {
    return _activeTransactions
        .where((t) =>
            t.type == type &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// ยอดรวมของปีใดปีหนึ่ง (ใช้กับกราฟที่เลือกดูแบบ "ปี")
  double yearlyTotal(CategoryType type, int year) {
    return _activeTransactions
        .where((t) => t.type == type && t.date.year == year)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// สรุปรายรับ-รายจ่ายรายวัน ย้อนหลัง [days] วัน นับจาก [endDate] (ค่าเริ่มต้นคือวันนี้)
  /// ใช้เมื่อผู้ใช้เลือกดูกราฟแบบ "วัน" ในหน้า Home / Statistic
  List<MapEntry<DateTime, Map<String, double>>> dailySummary({int days = 7, DateTime? endDate}) {
    final end = endDate ?? DateTime.now();
    final result = <MapEntry<DateTime, Map<String, double>>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(end.year, end.month, end.day - i);
      result.add(MapEntry(day, {
        'income': dailyTotal(CategoryType.income, day),
        'expense': dailyTotal(CategoryType.expense, day),
      }));
    }
    return result;
  }

  /// สรุปรายรับ-รายจ่ายรายเดือน ย้อนหลัง [months] เดือน นับจาก [endMonth] (ข้อ 1.3.3.1)
  /// [endMonth] ใช้แค่เดือน/ปีเป็นตัวอ้างอิง (ไม่สนใจวัน) ค่าเริ่มต้นคือเดือนปัจจุบัน
  /// เพิ่มพารามิเตอร์นี้เพื่อรองรับการ "เลือกเดือน/ปี" ย้อนหลังจากหน้า Home / Statistic
  List<MapEntry<DateTime, Map<String, double>>> monthlySummary({int months = 6, DateTime? endMonth}) {
    final now = endMonth ?? DateTime.now();
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

  /// สรุปรายรับ-รายจ่ายรายปี ย้อนหลัง [years] ปี นับจาก [endYear] (ค่าเริ่มต้นคือปีปัจจุบัน)
  /// ใช้เมื่อผู้ใช้เลือกดูกราฟแบบ "ปี" ในหน้า Home / Statistic
  List<MapEntry<int, Map<String, double>>> yearlySummary({int years = 5, int? endYear}) {
    final end = endYear ?? DateTime.now().year;
    final result = <MapEntry<int, Map<String, double>>>[];
    for (int i = years - 1; i >= 0; i--) {
      final year = end - i;
      result.add(MapEntry(year, {
        'income': yearlyTotal(CategoryType.income, year),
        'expense': yearlyTotal(CategoryType.expense, year),
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
  Map<CategoryModel, double> expenseByCategory({DateTime? month}) =>
      totalsByCategory(type: CategoryType.expense, month: month);

  Map<CategoryModel, double> totalsByCategory({required CategoryType type, DateTime? month}) {
    final Map<CategoryModel, double> map = {};
    for (final t in _activeTransactions.where((t) => t.type == type)) {
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
```

### 13.42 flutter_application_1/lib/services/db_helper.dart

ตัวเชื่อม Firestore แบบ singleton รองรับ CRUD, batch, query, count และ transaction สำหรับยอดออม พร้อมแปลงข้อผิดพลาดเป็นข้อความ; ไม่มีการเปิด SQLite ในไฟล์นี้

โครงสร้างที่ประกาศ: class DBHelper (L10)

229 บรรทัด • SHA-256: 297c0354d7f07f43

```dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const _dbTimeout = Duration(seconds: 10);

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  // The existing database is named 'default', without parentheses.
  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  CollectionReference<Map<String, dynamic>> _col(String table) {
    if (table == 'categories') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      return _fs.collection('users').doc(uid).collection('categories');
    }
    return _fs.collection(table);
  }

  /// Commit both records together and re-read the goal on concurrent updates.
  Future<Map<String, dynamic>> transferToGoal(
    String goalId, double amount, Map<String, dynamic> entry,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || entry['user_id'] != uid || !amount.isFinite || amount <= 0) {
      throw StateError('ข้อมูลการโอนไม่ถูกต้อง');
    }
    final goalRef = _col('goals').doc(goalId);
    return _fs.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      final data = snapshot.data();
      if (data == null || data['user_id'] != uid) {
        throw StateError('ไม่พบเป้าหมาย');
      }
      final saved = (data['saved_amount'] as num).toDouble() + amount;
      final target = (data['target_amount'] as num).toDouble();
      if (saved > target) throw StateError('จำนวนเงินเกินเป้าหมาย');
      final updated = {...data, 'saved_amount': saved,
        'status': saved >= target ? 'completed' : 'inProgress'};
      transaction.update(goalRef, updated);
      transaction.set(_col('transactions').doc(entry['id'] as String), entry);
      return updated;
    });
  }

 
  /// Keep an edited/deleted savings transfer and its goal in one commit.
  Future<Map<String, dynamic>?> changeGoalTransfer(
      String id, Map<String, dynamic>? replacement) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
    final entryRef = _col('transactions').doc(id);
    return _fs.runTransaction((transaction) async {
      final old = (await transaction.get(entryRef)).data();
      if (old == null || old['user_id'] != uid) throw StateError('ไม่พบรายการ');
      final description = old['description'] as String? ?? '';
      if (!description.startsWith('goal_transfer:')) throw StateError('ไม่ใช่รายการโอน');
      final goalRef = _col('goals').doc(description.substring('goal_transfer:'.length));
      final goal = (await transaction.get(goalRef)).data();
      Map<String, dynamic>? updatedGoal;
      if (goal != null) {
        if (goal['user_id'] != uid) throw StateError('ไม่พบเป้าหมาย');
        double contribution(Map<String, dynamic>? row) => row != null &&
            row['type'] == 'expense' && row['category_id'] == 'c17'
            ? (row['amount'] as num).toDouble() : 0;
        final saved = (goal['saved_amount'] as num).toDouble()
            - contribution(old) + contribution(replacement);
        final target = (goal['target_amount'] as num).toDouble();
        if (!saved.isFinite || saved < 0 || saved > target) {
          throw StateError('ยอดเงินออมหลังแก้ไขต้องอยู่ระหว่าง 0 ถึงยอดเป้าหมาย');
        }
        updatedGoal = {...goal, 'saved_amount': saved,
          'status': saved >= target ? 'completed' : 'inProgress'};
        transaction.update(goalRef, updatedGoal);
      }
      if (replacement == null) {
        transaction.delete(entryRef);
      } else {
        transaction.update(entryRef, replacement);
      }
      return updatedGoal;
    });
  }

  Never _handleError(Object e, StackTrace st, String fallbackMessage) {
  
    debugPrint('[DBHelper] RAW ERROR TYPE=${e.runtimeType} VALUE=$e');
    if (e is TimeoutException) {
      debugPrint('[DBHelper] TIMEOUT after ${_dbTimeout.inSeconds}s: $fallbackMessage');
      throw Exception('$fallbackMessage (หมดเวลา) - เช็คอินเทอร์เน็ต');
    }
    if (e is FirebaseException) {
      debugPrint('[DBHelper] FirebaseException code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'permission-denied':
          throw Exception('$fallbackMessage (ไม่มีสิทธิ์เข้าถึงข้อมูล - ตรวจสอบ Firestore Security Rules)');
        case 'unavailable':
          throw Exception('$fallbackMessage (เชื่อมต่อ Firestore ไม่ได้ - เช็คอินเทอร์เน็ต/สถานะ Firebase)');
        case 'failed-precondition':
          // เกิดเมื่อ query ใช้ where + orderBy คนละ field กัน (เช่น where('user_id')
          // ร่วมกับ orderBy('date')) ซึ่ง Firestore บังคับให้ต้องสร้าง Composite Index
          // ก่อนใช้งานจริง ข้อความ e.message ของ Firebase จะมีลิงก์สำหรับกดสร้าง index
          // อัตโนมัติแนบมาด้วย ให้เปิดลิงก์นั้นในเบราว์เซอร์แล้วกด "Create Index" ได้เลย
          throw Exception(
              '$fallbackMessage (ต้องสร้าง Firestore Index ก่อนใช้งาน query นี้ - '
              'เปิดลิงก์ในข้อความต่อไปนี้เพื่อสร้าง index อัตโนมัติ: ${e.message})');
        default:
          throw Exception('$fallbackMessage (${e.code}: ${e.message})');
      }
    }
    debugPrint('[DBHelper] Unexpected error: $e\n$st');
    throw Exception('$fallbackMessage ($e)');
  }

  // ---------------- Generic CRUD helpers ----------------
  // ใช้ data['id'] เป็น document id เสมอ (โค้ดเดิมสร้าง id ด้วย uuid อยู่แล้ว)
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    try {
      await _col(table).doc(id).set(data);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  // เพิ่มหลายรายการในครั้งเดียวด้วย WriteBatch (1 round-trip แทนที่จะยิงทีละรายการ)
  // Firestore batch รองรับสูงสุด 500 operations ต่อ batch จึงแบ่งเป็นชุดๆ ถ้าเผื่อไว้
  Future<void> insertBatch(String table, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    const chunkSize = 450;
    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
      final batch = _fs.batch();
      for (final data in chunk) {
        final id = data['id'] as String;
        batch.set(_col(table).doc(id), data);
      }
      try {
        await batch.commit();
      } catch (e, st) {
        _handleError(e, st, 'บันทึกไม่สำเร็จ');
      }
    }
  }

  // รองรับเฉพาะ where แบบ 'field = ?' กับ whereArgs 1 ค่า (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    if (where?.trim() == 'id = ?' && whereArgs?.length == 1) {
      try {
        final snapshot = await _col(table).doc(whereArgs!.first.toString())
            .get().timeout(_dbTimeout);
        final data = snapshot.data();
        return data == null ? [] : [data];
      } catch (e, st) {
        _handleError(e, st, 'โหลดข้อมูลไม่สำเร็จ');
      }
    }
    Query<Map<String, dynamic>> q = _col(table);

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      final field = where.split('=').first.trim();
      q = q.where(field, isEqualTo: whereArgs.first);
    }

    if (orderBy != null && orderBy.trim().isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final field = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      q = q.orderBy(field, descending: desc);
    }

    try {
      final snap = await q.get().timeout(_dbTimeout);
      return snap.docs.map((d) => d.data()).toList();
    } catch (e, st) {
      _handleError(e, st, 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  // รองรับเฉพาะ where = 'id = ?' (ตรงกับที่ใช้ทั้งโปรเจกต์)
  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<Object?> whereArgs,
  ) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).update(data);
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'บันทึกไม่สำเร็จ');
    }
  }

  Future<int> delete(String table, String where, List<Object?> whereArgs) async {
    final id = whereArgs.first.toString();
    try {
      await _col(table).doc(id).delete();
      return 1;
    } catch (e, st) {
      _handleError(e, st, 'ลบไม่สำเร็จ');
    }
  }

  Future<int> count(String table) async {
    try {
      final agg = await _col(table).count().get().timeout(_dbTimeout);
      return agg.count ?? 0;
    } catch (e, st) {
      _handleError(e, st, 'นับจำนวนรายการไม่สำเร็จ');
    }
  }
}
```

### 13.43 flutter_application_1/lib/services/local_receipt_store.dart

บันทึก bytes ของภาพในเครื่องภายใต้โฟลเดอร์ hash เจ้าของและชื่อ UUID คืน local-receipt marker; delete ตรวจรูปแบบ marker ก่อนลบเพื่อกัน path ที่ไม่ตรงรูปแบบ

โครงสร้างที่ประกาศ: class LocalReceiptStore (L10)

40 บรรทัด • SHA-256: dd06b7ed9945f8f0

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Device-local attachments. The marker can be synced, but the image cannot.
class LocalReceiptStore {
  LocalReceiptStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;

  Future<String> save(Uint8List bytes,
      {required String owner, required bool isPng}) async {
    final account = sha256.convert(utf8.encode(owner)).toString();
    final relative = '$account/${const Uuid().v4()}.${isPng ? 'png' : 'jpg'}';
    final root = await _directory();
    final file = File(p.join(root.path, 'receipts', relative));
    await file.parent.create(recursive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return 'local-receipt:$relative';
  }

  Future<void> delete(String marker) async {
    final match =
        RegExp(r'^local-receipt:([a-f0-9]{64}/[a-f0-9-]{36}\.(?:jpg|png))$')
            .firstMatch(marker);
    if (match == null) throw ArgumentError('Invalid local receipt marker');
    final root = await _directory();
    final file = File(p.join(root.path, 'receipts', match[1]!));
    if (await file.exists()) await file.delete();
  }
}
```

### 13.44 flutter_application_1/lib/services/password_policy.dart

ไฟล์ Dart ที่สร้างจาก JSON กลาง คืน translation key เมื่อรหัสไม่ผ่าน และ null เมื่อผ่าน ใช้สมัครสมาชิก/เปลี่ยนรหัส; ควรแก้ต้นฉบับ config ไม่แก้ไฟล์ generated เพียงตัวเดียว

35 บรรทัด • SHA-256: b8062399736983df

```dart
// Generated by scripts/generate_password_policy.py. Edit config/password_policy.json.
const passwordMinLength = 6;
const passwordMaxLength = 128;
const _blockedPasswords = <String>{
  "123456789012345",
  "1234567890123456",
  "12345678901234567890",
  "passwordpassword",
  "password123456789",
  "password12345678",
  "qwertyuiopasdfgh",
  "qwertyuiopasdfghjkl",
  "qwerty1234567890",
  "aaaaaaaaaaaaaaa",
  "111111111111111",
  "000000000000000",
  "budgetmate123456",
  "budgetmatepassword",
  "budgetmatebudgetmate"
};

/// New passwords only. Never trim, truncate or rewrite a user's secret.
/// Minimum counts Unicode code points; maximum uses Firebase-compatible UTF-16 units.
String? passwordValidationKey(String password) {
  if (password.runes.length < passwordMinLength) return 'password_min_length';
  if (password.length > passwordMaxLength) return 'password_max_length';
  if (password.trim().isEmpty || _blockedPasswords.contains(password.toLowerCase())) {
    return 'password_common';
  }
  if (!RegExp("[a-z]").hasMatch(password)) return 'password_lowercase';
  if (!RegExp("[A-Z]").hasMatch(password)) return 'password_uppercase';
  if (!RegExp("[0-9]").hasMatch(password)) return 'password_digit';
  if (!RegExp("[\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E]").hasMatch(password)) return 'password_symbol';
  return null;
}
```

### 13.45 flutter_application_1/lib/services/receipt_parser.dart

ReceiptDraft แยกยอด วัน และชื่อผู้รับจากข้อความ OCR ด้วย regex และหลักฐานหลายแบบ รองรับไทย/อังกฤษและปฏิเสธยอดกำกวม ไม่บันทึกฐานข้อมูลเอง

โครงสร้างที่ประกาศ: class ReceiptDraft (L2)

262 บรรทัด • SHA-256: 5494c4be798d1760

```dart
/// Bank-independent OCR suggestions. Always review before saving an expense.
class ReceiptDraft {
  final double? amount;
  final DateTime? date;
  final String merchant;
  const ReceiptDraft({this.amount, this.date, required this.merchant});

  static final _excluded = RegExp(
      r'sub\s*total|ยอดก่อน|เงินทอน|change|cash|เงินสด|vat|ภาษี|ค่าธรรมเนียม|fees?\b|balance|ยอดคงเหลือ|เลขที่|เลขอ้างอิง|รหัสอ้างอิง|reference|account|บัญชี',
      caseSensitive: false);
  // Longer labels precede shorter labels, including bilingual slip labels.
  static final _labels = RegExp(
      r'จำนวนเงินที่โอน|ยอดเงินที่โอน|ยอดเงินโอน|ยอดโอน|transfer\s*amount|amount\s*transferred|'
      r'grand\s*total|net\s*total|amount\s*due|ยอดเงินสุทธิ|ยอดสุทธิ|ยอดชำระสุทธิ|รวมสุทธิ|รวมทั้งสิ้น|'
      r'จำนวนเงินที่ชำระ|ยอดเงินที่ชำระ|ยอดที่ชำระ|ยอดชำระ|จำนวนเงิน|ยอดเงิน|ยอดรวม|รวมเงิน|'
      r'payment\s*amount|amount\s*paid|\btotal\b|\bamount\b',
      caseSensitive: false);
  static final _transferLabels = RegExp(
      r'จำนวนเงินที่โอน|ยอดเงินที่โอน|ยอดเงินโอน|ยอดโอน|transfer\s*amount|amount\s*transferred',
      caseSensitive: false);
  static final _netLabels = RegExp(
      r'grand\s*total|net\s*total|amount\s*due|ยอดเงินสุทธิ|ยอดสุทธิ|ยอดชำระสุทธิ|รวมสุทธิ|รวมทั้งสิ้น',
      caseSensitive: false);
  static final _transferContext = RegExp(
      r'โอนเงินสำเร็จ|โอนสำเร็จ|โอนเงิน|ชำระเงินสำเร็จ|ชำระสำเร็จ|จ่ายเงินสำเร็จ|ทำรายการสำเร็จ|'
      r'transfer\s*(?:successful|completed)|successful\s*transfer|payment\s*(?:successful|completed)|successful\s*payment',
      caseSensitive: false);
  static final _currency = RegExp(r'บาท(?:ไทย)?|THB|฿', caseSensitive: false);

  static String _normalize(String text) {
    const thai = '๐๑๒๓๔๕๖๗๘๙';
    for (var i = 0; i < thai.length; i++) {
      text = text.replaceAll(thai[i], '$i');
    }
    text = text
        .replaceAll('\u0e4d\u0e32', '\u0e33')
        .replaceAll(RegExp('[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('\u00a0', ' ');
    return text.replaceAllMapped(
        RegExp(r'([\u0E00-\u0E7F])[ \t]+(?=[\u0E00-\u0E7F])'),
        (match) => match[1]!);
  }

  factory ReceiptDraft.fromText(String text) {
    final displayLines = text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final normalized = _normalize(text);
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    var bestPriority = 0;
    final candidates = <double>{};
    for (var i = 0; i < lines.length; i++) {
      final exclusion = _excluded.firstMatch(lines[i]);
      // A fee may follow the amount in the same OCR row. Never use the fee
      // itself, or look below an excluded label for a replacement amount.
      final line =
          exclusion == null ? lines[i] : lines[i].substring(0, exclusion.start);
      final labels = _labels.allMatches(line).toList();
      if (labels.isEmpty) continue;
      for (var labelIndex = 0; labelIndex < labels.length; labelIndex++) {
        final label = labels[labelIndex];
        final name = label.group(0)!;
        final priority = _transferLabels.hasMatch(name)
            ? 3
            : _netLabels.hasMatch(name)
                ? 2
                : 1;
        if (priority < bestPriority) continue;
        final tail = line.substring(
            label.end,
            labelIndex + 1 < labels.length
                ? labels[labelIndex + 1].start
                : line.length);
        double? value = _moneyValue(tail);
        if (value == null &&
            exclusion == null &&
            labelIndex == labels.length - 1 &&
            _onlyCurrencyOrSeparator(tail)) {
          // Currency can be printed on its own line between label and value.
          for (var next = i + 1; next < lines.length && next <= i + 2; next++) {
            value = _moneyValue(lines[next]);
            if (value != null || !_onlyCurrencyOrSeparator(lines[next])) break;
          }
        }
        if (value != null && value > 0) {
          if (priority > bestPriority) candidates.clear();
          candidates.add(value);
          bestPriority = priority;
        }
      }
    }

    // Never silently choose one of multiple conflicting labelled totals.
    double? amount = candidates.length == 1 ? candidates.single : null;
    if (candidates.isEmpty && _transferContext.hasMatch(normalized)) {
      final currencyAmounts = <double>{};
      for (var i = 0; i < lines.length; i++) {
        if (_excluded.hasMatch(lines[i])) continue;
        var previous = i - 1;
        if (previous >= 0 && _onlyCurrencyOrSeparator(lines[previous])) {
          previous--;
        }
        if (previous >= 0 && _excluded.hasMatch(lines[previous])) continue;
        final hasCurrency = _currency.hasMatch(lines[i]) ||
            (i > 0 &&
                _currency.hasMatch(lines[i - 1]) &&
                _onlyCurrencyOrSeparator(lines[i - 1])) ||
            (i + 1 < lines.length &&
                _currency.hasMatch(lines[i + 1]) &&
                _onlyCurrencyOrSeparator(lines[i + 1]));
        if (!hasCurrency) continue;
        final value = _moneyValue(lines[i]);
        if (value != null && value > 0) currencyAmounts.add(value);
      }
      if (currencyAmounts.length == 1) amount = currencyAmounts.single;
    }
    return ReceiptDraft(
        amount: amount,
        date: _date(normalized),
        merchant: _merchant(displayLines, normalized));
  }

  static String _merchant(List<String> lines, String normalized) {
    if (lines.isEmpty) return '';
    final recipientLabel = RegExp(
        r'^(?:ชื่อผู้รับ(?:เงิน)?|ผู้รับ(?:เงิน)?|โอนไปยัง|โอนไป|ปลายทาง|recipient|beneficiary|to)(?:\s*[:：\-]\s*|\s+|$)',
        caseSensitive: false);
    final account = RegExp(
        r'(?:[xX*•●][\s\-]*){2,}[\d xX*•●\-]*\d[\d xX*•●\-]*|\b\d{3}-\d-\d{4,5}-\d\b');
    bool isName(String value) {
      final compact = _normalize(value);
      return RegExp(r'[ก-๙a-zA-Z]').hasMatch(value) &&
          !RegExp(r'\d|[xX*•●]{2,}').hasMatch(value) &&
          !_transferContext.hasMatch(compact) &&
          !_excluded.hasMatch(compact) &&
          !_labels.hasMatch(compact) &&
          !RegExp(r'ธนาคาร|กสิกร|ไทยพาณิชย์|กรุงไทย|กรุงเทพ|พร้อมเพย์|promptpay|bank|^make$|^scb$|^k\s*plus$|^จำนวน$|ค่าธรรมเนียม|สแกน|โอนแล้ว',
                  caseSensitive: false)
              .hasMatch(compact);
    }

    final labelled = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final match = recipientLabel.firstMatch(lines[i]);
      if (match == null) continue;
      final tail = lines[i].substring(match.end).trim();
      if (tail.isNotEmpty) {
        if (isName(tail)) labelled.add(tail);
      } else if (i + 1 < lines.length && isName(lines[i + 1])) {
        labelled.add(lines[i + 1]);
      }
    }
    if (labelled.length == 1) return labelled.single;
    if (labelled.length > 1) return '';
    if (_transferContext.hasMatch(normalized)) {
      // Unlabelled slips (including MAKE) print sender then recipient, each
      // followed by a masked account. Require exactly two complete pairs.
      final names = <String>[];
      var accountCount = 0;
      for (var i = 0; i < lines.length; i++) {
        final match = account.firstMatch(lines[i]);
        if (match == null) continue;
        accountCount++;
        final prefix = lines[i].substring(0, match.start).trim();
        if (isName(prefix)) {
          names.add(prefix);
        } else if (i > 0 && isName(lines[i - 1])) {
          names.add(lines[i - 1]);
        }
      }
      return accountCount == 2 && names.length == 2 ? names.last : '';
    }
    return lines.first;
  }

  static bool _onlyCurrencyOrSeparator(String text) =>
      RegExp(r'^[\s:：/()\[\]]*(?:(?:บาท(?:ไทย)?|THB|฿)[\s:：/()\[\]]*)?$',
              caseSensitive: false)
          .hasMatch(text);

  static double? _moneyValue(String text) {
    // Join OCR spaces around numeric punctuation without inventing digits.
    text = text.replaceAllMapped(
        RegExp(r'(\d)\s*([,.])\s*(?=\d)'), (m) => '${m[1]}${m[2]}');
    final match = RegExp(
            r'^[\s:：/]*(?:(?:\(?(?:THB|บาท(?:ไทย)?)\)?|฿|\$)\s*)?'
            r'((?:\d{1,3}(?:,\d{3})+|\d{1,7})(?:\.\d{2}|\.-)?)'
            r'\s*(?:\(?(?:บาท(?:ไทย)?|THB)\)?|฿)?\s*$',
            caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    return double.tryParse(
        match[1]!.replaceAll(',', '').replaceAll('.-', '.00'));
  }

  static DateTime? _validDate(int day, int month, int year) {
    if (year >= 2400) year -= 543;
    if (year < 2000 ||
        year > 2200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static DateTime? _date(String text) {
    final numeric = RegExp(
        r'(?<!\d)(\d{4}|\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{4}|\d{2})(?!\d)');
    for (final m in numeric.allMatches(text)) {
      final iso = m[1]!.length == 4;
      final day = int.parse(m[iso ? 3 : 1]!);
      final month = int.parse(m[2]!);
      var year = int.parse(m[iso ? 1 : 3]!);
      if (year < 100) year += year >= 50 ? 2500 : 2000;
      final date = _validDate(day, month, year);
      if (date != null) return date;
    }
    const months = [
      ['มค', 'มกราคม', 'jan', 'january'],
      ['กพ', 'กุมภาพันธ์', 'feb', 'february'],
      ['มีค', 'มีนาคม', 'mar', 'march'],
      ['เมย', 'เมษายน', 'apr', 'april'],
      ['พค', 'พฤษภาคม', 'may'],
      ['มิย', 'มิถุนายน', 'jun', 'june'],
      ['กค', 'กรกฎาคม', 'jul', 'july'],
      ['สค', 'สิงหาคม', 'aug', 'august'],
      ['กย', 'กันยายน', 'sep', 'sept', 'september'],
      ['ตค', 'ตุลาคม', 'oct', 'october'],
      ['พย', 'พฤศจิกายน', 'nov', 'november'],
      ['ธค', 'ธันวาคม', 'dec', 'december'],
    ];
    final compact = _normalize(text.replaceAll('.', '')).toLowerCase();
    final names = months.expand((m) => m).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
        '(?<!\\d)(\\d{1,2})\\s*(${names.join('|')})\\s*(พศ|คศ)?\\s*(\\d{4}|\\d{2})(?!\\d)');
    for (final m in pattern.allMatches(compact)) {
      final month = months.indexWhere((names) => names.contains(m[2])) + 1;
      var year = int.parse(m[4]!);
      if (year < 100) {
        final buddhist =
            m[3] == 'พศ' || (m[3] != 'คศ' && RegExp(r'[ก-๙]').hasMatch(m[2]!));
        year += buddhist ? 2500 : 2000;
      }
      final date = _validDate(int.parse(m[1]!), month, year);
      if (date != null) return date;
    }
    return null;
  }
}
```

### 13.46 flutter_application_1/lib/services/receipt_service.dart

เรียก OCR native ในเครื่องและแปลงเป็น ReceiptDraft ใช้ Apple Vision ก่อนบน iOS แล้ว fallback Tesseract ป้องกัน scan ซ้อนและมี timeout; constructor รับตัวอ่านทดแทนสำหรับ test

โครงสร้างที่ประกาศ: class ReceiptService (L8)

69 บรรทัด • SHA-256: e67b5494e0320153

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'receipt_parser.dart';

class ReceiptService {
  ReceiptService(
      {Future<String> Function(Uint8List)? readText,
      this.timeout = const Duration(seconds: 55)})
      : _readText = readText ?? _localRead;
  final Future<String> Function(Uint8List) _readText;
  final Duration timeout;

  static bool _nativeBusy = false;

  static Future<String> _localRead(Uint8List bytes) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError('Offline scanning requires Android or iOS');
    }
    if (_nativeBusy) {
      throw StateError('The previous native scan is still finishing');
    }
    _nativeBusy = true;
    try {
      String? appleText;
      if (Platform.isIOS) {
        try {
          appleText = await const MethodChannel('budgetmate/receipt_ocr')
              .invokeMethod<String>('readText', bytes);
          if (appleText != null &&
              ReceiptDraft.fromText(appleText).amount != null) {
            return appleText;
          }
        } on PlatformException {
          // Older systems and native errors can still use bundled Tesseract.
        } on MissingPluginException {
          // A full native rebuild registers the Apple OCR channel.
        }
      }
      final root = await getTemporaryDirectory();
      final directory =
          await Directory('${root.path}/receipt-ocr-').createTemp();
      final image = File('${directory.path}/receipt');
      try {
        await image.writeAsBytes(bytes, flush: true);
        final text = await FlutterTesseractOcr.extractText(image.path,
            language: 'tha+eng', args: {'psm': '4'});
        if (ReceiptDraft.fromText(text).amount != null) return text;
        return appleText ?? text;
      } finally {
        // Keep the input until native OCR completes, even if scan() times out.
        await directory.delete(recursive: true);
      }
    } finally {
      _nativeBusy = false;
    }
  }

  Future<ReceiptDraft> scan(Uint8List bytes) async {
    final text = await _readText(bytes).timeout(timeout);
    final draft = ReceiptDraft.fromText(text);
    if (draft.amount == null) {
      throw const FormatException('No readable receipt or slip amount');
    }
    return draft;
  }
}
```

### 13.47 flutter_application_1/lib/widgets/additional_category_artwork.dart

ชุดข้อมูลชื่อไทย/อังกฤษ/กลุ่มของภาพหมวดเพิ่มเติม เป็น catalog ไม่ใช่ตรรกะการคำนวณเงิน

415 บรรทัด • SHA-256: da26bca63726a846

```dart
/// 3D clay illustrations, in persisted artwork-number order (136 onwards).
/// Images live in pastel_collection_00.png through pastel_collection_11.png.
/// Append only: saved categories refer to these positions.
const additionalCategoryArtwork = <(String, String, String)>[
  ('องุ่น', 'Grapes', 'food'),
  ('เมลอน', 'Melon', 'food'),
  ('แตงโม', 'Watermelon', 'food'),
  ('ส้ม', 'Orange', 'food'),
  ('เลมอน', 'Lemon', 'food'),
  ('กล้วย', 'Banana', 'food'),
  ('สับปะรด', 'Pineapple', 'food'),
  ('มะม่วง', 'Mango', 'food'),
  ('แอปเปิลแดง', 'Red apple', 'food'),
  ('ลูกแพร์', 'Pear', 'food'),
  ('ลูกพีช', 'Peach', 'food'),
  ('เชอร์รี', 'Cherries', 'food'),
  ('สตรอว์เบอร์รี', 'Strawberry', 'food'),
  ('บลูเบอร์รี', 'Blueberries', 'food'),
  ('กีวี', 'Kiwi', 'food'),
  ('มะเขือเทศ', 'Tomato', 'food'),
  ('มะกอก', 'Olives', 'food'),
  ('มะพร้าว', 'Coconut', 'food'),
  ('อะโวคาโด', 'Avocado', 'food'),
  ('มะเขือม่วง', 'Eggplant', 'food'),
  ('มันฝรั่ง', 'Potato', 'food'),
  ('แครอต', 'Carrot', 'food'),
  ('ข้าวโพด', 'Corn', 'food'),
  ('พริก', 'Chili', 'food'),
  ('พริกหวาน', 'Bell pepper', 'food'),
  ('แตงกวา', 'Cucumber', 'food'),
  ('ผักใบเขียว', 'Leafy greens', 'food'),
  ('บรอกโคลี', 'Broccoli', 'food'),
  ('กระเทียม', 'Garlic', 'food'),
  ('หัวหอม', 'Onion', 'food'),
  ('เห็ด', 'Mushroom', 'food'),
  ('ถั่วลิสง', 'Peanuts', 'food'),
  ('เกาลัด', 'Chestnut', 'food'),
  ('ขนมปัง', 'Bread', 'food'),
  ('บาแก็ต', 'Baguette', 'food'),
  ('ขนมปังแผ่น', 'Flatbread', 'food'),
  ('เพรตเซล', 'Pretzel', 'food'),
  ('เบเกิล', 'Bagel', 'food'),
  ('แพนเค้ก', 'Pancakes', 'food'),
  ('วาฟเฟิล', 'Waffle', 'food'),
  ('ชีส', 'Cheese', 'food'),
  ('เนื้อติดกระดูก', 'Meat on bone', 'food'),
  ('น่องไก่', 'Chicken leg', 'food'),
  ('สเต๊ก', 'Steak', 'food'),
  ('เบคอน', 'Bacon', 'food'),
  ('แฮมเบอร์เกอร์', 'Hamburger', 'food'),
  ('เฟรนช์ฟรายส์', 'French fries', 'food'),
  ('ฮอตดอก', 'Hot dog', 'food'),
  ('แซนด์วิช', 'Sandwich', 'food'),
  ('ทาโก้', 'Taco', 'food'),
  ('เบอร์ริโต', 'Burrito', 'food'),
  ('ทามาเล', 'Tamale', 'food'),
  ('พิตา', 'Stuffed pita', 'food'),
  ('ฟาลาเฟล', 'Falafel', 'food'),
  ('ไข่ไก่', 'Egg', 'food'),
  ('ไข่ดาว', 'Fried egg', 'food'),
  ('อาหารกระทะ', 'Paella', 'food'),
  ('สตูว์', 'Stew', 'food'),
  ('ฟองดู', 'Fondue', 'food'),
  ('ซีเรียล', 'Cereal', 'food'),
  ('สลัด', 'Salad', 'food'),
  ('ป๊อปคอร์น', 'Popcorn', 'food'),
  ('เนย', 'Butter', 'food'),
  ('เกลือ', 'Salt', 'food'),
  ('อาหารกระป๋อง', 'Canned food', 'food'),
  ('เบนโตะ', 'Bento', 'food'),
  ('ข้าวเกรียบ', 'Rice cracker', 'food'),
  ('ข้าวปั้น', 'Rice ball', 'food'),
  ('ข้าวสวย', 'Cooked rice', 'food'),
  ('ข้าวแกงกะหรี่', 'Curry rice', 'food'),
  ('ก๋วยเตี๋ยว', 'Noodles', 'food'),
  ('สปาเกตตี', 'Spaghetti', 'food'),
  ('มันเผา', 'Roasted sweet potato', 'food'),
  ('โอเด้ง', 'Oden', 'food'),
  ('กุ้งทอด', 'Fried shrimp', 'food'),
  ('ลูกชิ้นปลา', 'Fish cake', 'food'),
  ('ขนมไหว้พระจันทร์', 'Mooncake', 'food'),
  ('ดังโงะ', 'Dango', 'food'),
  ('เกี๊ยว', 'Dumpling', 'food'),
  ('คุกกี้เสี่ยงทาย', 'Fortune cookie', 'food'),
  ('อาหารกลับบ้าน', 'Takeout', 'food'),
  ('หอยนางรม', 'Oyster', 'food'),
  ('น้ำแข็งไส', 'Shaved ice', 'food'),
  ('พาย', 'Pie', 'food'),
  ('คัพเค้ก', 'Cupcake', 'food'),
  ('คุกกี้', 'Cookie', 'food'),
  ('ช็อกโกแลต', 'Chocolate', 'food'),
  ('ลูกอม', 'Candy', 'food'),
  ('อมยิ้ม', 'Lollipop', 'food'),
  ('คัสตาร์ด', 'Custard', 'food'),
  ('น้ำผึ้ง', 'Honey', 'food'),
  ('นมสด', 'Milk', 'food'),
  ('กาน้ำชา', 'Teapot', 'food'),
  ('ชาเขียว', 'Green tea', 'food'),
  ('สาเก', 'Sake', 'food'),
  ('แชมเปญ', 'Champagne', 'food'),
  ('ไวน์', 'Wine', 'food'),
  ('มาร์ตินี', 'Martini', 'food'),
  ('น้ำผลไม้ค็อกเทล', 'Tropical drink', 'food'),
  ('เบียร์', 'Beer', 'food'),
  ('วิสกี้', 'Whisky', 'food'),
  ('ชานมไข่มุก', 'Bubble tea', 'food'),
  ('น้ำผลไม้กล่อง', 'Juice box', 'food'),
  ('ชามาเต', 'Mate', 'food'),
  ('น้ำแข็ง', 'Ice cube', 'food'),
  ('ตะเกียบ', 'Chopsticks', 'food'),
  ('ช้อนส้อม', 'Cutlery', 'food'),
  ('ช้อน', 'Spoon', 'food'),
  ('มีดทำครัว', 'Kitchen knife', 'food'),
  ('โถดินเผา', 'Amphora', 'food'),
  ('คอมพิวเตอร์ตั้งโต๊ะ', 'Desktop computer', 'tech'),
  ('เมาส์', 'Mouse', 'tech'),
  ('แทร็กบอล', 'Trackball', 'tech'),
  ('จอยสติ๊ก', 'Joystick', 'tech'),
  ('มินิดิสก์', 'Minidisc', 'tech'),
  ('ฟลอปปีดิสก์', 'Floppy disk', 'tech'),
  ('แผ่นซีดี', 'Compact disc', 'tech'),
  ('วิดีโอเทป', 'Videotape', 'tech'),
  ('กล้องวิดีโอ', 'Video camera', 'tech'),
  ('เครื่องฉายภาพ', 'Film projector', 'tech'),
  ('โทรทัศน์', 'Television', 'tech'),
  ('วิทยุ', 'Radio', 'tech'),
  ('เพจเจอร์', 'Pager', 'tech'),
  ('แฟกซ์', 'Fax', 'tech'),
  ('โทรศัพท์บ้าน', 'Telephone', 'tech'),
  ('แบตเตอรี่', 'Battery', 'tech'),
  ('ปลั๊กไฟ', 'Electric plug', 'tech'),
  ('ดาวเทียม', 'Satellite', 'tech'),
  ('จานรับสัญญาณ', 'Satellite dish', 'tech'),
  ('ลูกคิด', 'Abacus', 'tech'),
  ('หลอดไฟ', 'Light bulb', 'tech'),
  ('ไฟฉาย', 'Flashlight', 'tech'),
  ('เทียน', 'Candle', 'tech'),
  ('กล้องจุลทรรศน์', 'Microscope', 'tech'),
  ('กล้องโทรทรรศน์', 'Telescope', 'tech'),
  ('เฟือง', 'Gear', 'tech'),
  ('แม่เหล็ก', 'Magnet', 'tech'),
  ('หุ่นยนต์', 'Robot', 'tech'),
  ('ดีเอ็นเอ', 'DNA', 'tech'),
  ('หลอดทดลอง', 'Test tube', 'tech'),
  ('จานเพาะเชื้อ', 'Petri dish', 'tech'),
  ('เครื่องกลั่น', 'Alembic', 'tech'),
  ('นาฬิกาจับเวลา', 'Stopwatch', 'tech'),
  ('รับสายมือถือ', 'Incoming call', 'tech'),
  ('กระดิ่งแจ้งเตือน', 'Notification bell', 'tech'),
  ('รถเมล์', 'Bus', 'travel'),
  ('รถรางไฟฟ้า', 'Trolleybus', 'travel'),
  ('รถแข่ง', 'Racing car', 'travel'),
  ('รถตำรวจ', 'Police car', 'travel'),
  ('รถพยาบาล', 'Ambulance', 'travel'),
  ('รถดับเพลิง', 'Fire engine', 'travel'),
  ('รถตู้', 'Minibus', 'travel'),
  ('รถกระบะ', 'Pickup truck', 'travel'),
  ('รถส่งของ', 'Delivery truck', 'travel'),
  ('รถบรรทุกพ่วง', 'Articulated truck', 'travel'),
  ('รถแทรกเตอร์', 'Tractor', 'travel'),
  ('มอเตอร์ไซค์', 'Motorcycle', 'travel'),
  ('รถเข็นผู้ป่วย', 'Wheelchair', 'travel'),
  ('รถเข็นไฟฟ้า', 'Motorized wheelchair', 'travel'),
  ('รถตุ๊กตุ๊ก', 'Auto rickshaw', 'travel'),
  ('กระเช้าลอยฟ้า', 'Cable car', 'travel'),
  ('รถไฟแขวน', 'Suspension railway', 'travel'),
  ('ตู้รถไฟ', 'Railway carriage', 'travel'),
  ('รถไฟความเร็วสูง', 'Bullet train', 'travel'),
  ('รถไฟใต้ดิน', 'Metro', 'travel'),
  ('รถจักรไอน้ำ', 'Steam locomotive', 'travel'),
  ('เฮลิคอปเตอร์', 'Helicopter', 'travel'),
  ('เครื่องบินเล็ก', 'Small airplane', 'travel'),
  ('ร่มชูชีพ', 'Parachute', 'travel'),
  ('จรวด', 'Rocket', 'travel'),
  ('จานบิน', 'Flying saucer', 'travel'),
  ('เรือใบ', 'Sailboat', 'travel'),
  ('เรือแคนู', 'Canoe', 'travel'),
  ('เรือเร็ว', 'Speedboat', 'travel'),
  ('เรือสำราญ', 'Cruise ship', 'travel'),
  ('เรือเฟอร์รี', 'Ferry', 'travel'),
  ('สมอเรือ', 'Anchor', 'travel'),
  ('ไฟจราจร', 'Traffic light', 'travel'),
  ('เขตก่อสร้าง', 'Construction barrier', 'travel'),
  ('แผนที่โลก', 'World map', 'travel'),
  ('เข็มทิศ', 'Compass', 'travel'),
  ('โมอาย', 'Moai statue', 'travel'),
  ('เทพีเสรีภาพ', 'Statue of Liberty', 'travel'),
  ('โตเกียวทาวเวอร์', 'Tokyo tower', 'travel'),
  ('ปราสาท', 'Castle', 'travel'),
  ('ปราสาทญี่ปุ่น', 'Japanese castle', 'travel'),
  ('สนามกีฬา', 'Stadium', 'travel'),
  ('ชิงช้าสวรรค์', 'Ferris wheel', 'travel'),
  ('รถไฟเหาะ', 'Roller coaster', 'travel'),
  ('ม้าหมุน', 'Carousel', 'travel'),
  ('น้ำพุ', 'Fountain', 'travel'),
  ('ภูเขา', 'Mountain', 'travel'),
  ('ภูเขาไฟ', 'Volcano', 'travel'),
  ('ทะเลทราย', 'Desert', 'travel'),
  ('เกาะ', 'Island', 'travel'),
  ('อุทยานแห่งชาติ', 'National park', 'travel'),
  ('พระอาทิตย์ขึ้น', 'Sunrise', 'travel'),
  ('สะพานยามค่ำ', 'Bridge at night', 'travel'),
  ('โบสถ์', 'Church', 'travel'),
  ('รางรถไฟ', 'Railway track', 'travel'),
  ('ทางด่วน', 'Motorway', 'travel'),
  ('โรงแรม', 'Hotel', 'travel'),
  ('พิพิธภัณฑ์', 'Museum', 'travel'),
  ('ประตูศาลเจ้า', 'Shrine gate', 'travel'),
  ('มัสยิด', 'Mosque', 'travel'),
  ('หมวกปีก', 'Sun hat', 'fashion'),
  ('หมวกทรงสูง', 'Top hat', 'fashion'),
  ('หมวกแก๊ป', 'Cap', 'fashion'),
  ('หมวกรับปริญญา', 'Graduation cap', 'fashion'),
  ('หมวกกู้ภัย', 'Rescue helmet', 'fashion'),
  ('มงกุฎ', 'Crown', 'fashion'),
  ('ชุดเดรส', 'Dress', 'fashion'),
  ('กิโมโน', 'Kimono', 'fashion'),
  ('ส่าหรี', 'Sari', 'fashion'),
  ('ชุดว่ายน้ำ', 'Swimsuit', 'fashion'),
  ('บิกินี', 'Bikini', 'fashion'),
  ('กางเกงขาสั้น', 'Shorts', 'fashion'),
  ('กางเกงยีนส์', 'Jeans', 'fashion'),
  ('เนกไท', 'Necktie', 'fashion'),
  ('เสื้อยืด', 'T-shirt', 'fashion'),
  ('เสื้อโค้ต', 'Coat', 'fashion'),
  ('เสื้อกาวน์', 'Lab coat', 'fashion'),
  ('เสื้อสะท้อนแสง', 'Safety vest', 'fashion'),
  ('ผ้าพันคอ', 'Scarf', 'fashion'),
  ('ถุงมือ', 'Gloves', 'fashion'),
  ('ถุงเท้า', 'Socks', 'fashion'),
  ('รองเท้าส้นสูง', 'High heels', 'fashion'),
  ('รองเท้าแตะผู้หญิง', 'Sandal', 'fashion'),
  ('รองเท้าแตะหนีบ', 'Flip-flop', 'fashion'),
  ('รองเท้าบูต', 'Boots', 'fashion'),
  ('รองเท้าบัลเลต์', 'Flat shoes', 'fashion'),
  ('รองเท้าเดินป่า', 'Hiking boots', 'fashion'),
  ('รองเท้าเต้นบัลเลต์', 'Pointe shoes', 'fashion'),
  ('รองเท้าหนัง', 'Dress shoes', 'fashion'),
  ('กระเป๋าสตางค์', 'Purse', 'fashion'),
  ('กระเป๋าคลัตช์', 'Clutch', 'fashion'),
  ('กระเป๋าเป้', 'Backpack', 'fashion'),
  ('เข็มกลัดซ่อนปลาย', 'Safety pin', 'fashion'),
  ('แว่นสายตา', 'Eyeglasses', 'fashion'),
  ('แว่นนิรภัย', 'Goggles', 'fashion'),
  ('อัญมณี', 'Gemstone', 'fashion'),
  ('โบผูกผม', 'Ribbon', 'fashion'),
  ('กระจก', 'Mirror', 'fashion'),
  ('มีดโกน', 'Razor', 'fashion'),
  ('ทำเล็บ', 'Nail polish', 'fashion'),
  ('อเมริกันฟุตบอล', 'American football', 'hobby'),
  ('เบสบอล', 'Baseball', 'hobby'),
  ('ซอฟต์บอล', 'Softball', 'hobby'),
  ('วอลเลย์บอล', 'Volleyball', 'hobby'),
  ('รักบี้', 'Rugby', 'hobby'),
  ('จานร่อน', 'Flying disc', 'hobby'),
  ('บิลเลียด', 'Billiards', 'hobby'),
  ('ปิงปอง', 'Table tennis', 'hobby'),
  ('แบดมินตัน', 'Badminton', 'hobby'),
  ('ฮอกกี้น้ำแข็ง', 'Ice hockey', 'hobby'),
  ('ฮอกกี้สนาม', 'Field hockey', 'hobby'),
  ('ลาครอส', 'Lacrosse', 'hobby'),
  ('คริกเก็ต', 'Cricket', 'hobby'),
  ('บูมเมอแรง', 'Boomerang', 'hobby'),
  ('ประตูฟุตบอล', 'Goal net', 'hobby'),
  ('กอล์ฟ', 'Golf', 'hobby'),
  ('ว่าว', 'Kite', 'hobby'),
  ('ธนู', 'Archery', 'hobby'),
  ('ตกปลา', 'Fishing', 'hobby'),
  ('ดำน้ำ', 'Diving mask', 'hobby'),
  ('นวมมวย', 'Boxing glove', 'hobby'),
  ('ชุดศิลปะต่อสู้', 'Martial arts uniform', 'hobby'),
  ('สเกตบอร์ด', 'Skateboard', 'hobby'),
  ('โรลเลอร์สเกต', 'Roller skate', 'hobby'),
  ('เลื่อนหิมะ', 'Sled', 'hobby'),
  ('สเกตน้ำแข็ง', 'Ice skate', 'hobby'),
  ('เคอร์ลิง', 'Curling', 'hobby'),
  ('สกี', 'Skis', 'hobby'),
  ('ปาเป้า', 'Darts', 'hobby'),
  ('โบว์ลิง', 'Bowling', 'hobby'),
  ('ลูกเต๋า', 'Dice', 'hobby'),
  ('หมากรุก', 'Chess', 'hobby'),
  ('โยโย่', 'Yo-yo', 'hobby'),
  ('ไม้กายสิทธิ์', 'Magic wand', 'hobby'),
  ('ละครเวที', 'Theater', 'hobby'),
  ('ด้าย', 'Thread', 'hobby'),
  ('เข็มเย็บผ้า', 'Sewing needle', 'hobby'),
  ('ไหมพรม', 'Yarn', 'hobby'),
  ('ปมเชือก', 'Knot', 'hobby'),
  ('แซกโซโฟน', 'Saxophone', 'hobby'),
  ('แอคคอร์เดียน', 'Accordion', 'hobby'),
  ('เปียโน', 'Piano', 'hobby'),
  ('ทรัมเป็ต', 'Trumpet', 'hobby'),
  ('ไวโอลิน', 'Violin', 'hobby'),
  ('แบนโจ', 'Banjo', 'hobby'),
  ('กลองชุด', 'Drum', 'hobby'),
  ('กลองยาว', 'Long drum', 'hobby'),
  ('โน้ตเพลง', 'Musical score', 'hobby'),
  ('บัตรเข้าชม', 'Admission ticket', 'hobby'),
  ('ละครสัตว์', 'Circus', 'hobby'),
  ('โยนบอลโชว์', 'Juggling', 'hobby'),
  ('เล่นเซิร์ฟ', 'Surfing', 'hobby'),
  ('ว่ายน้ำ', 'Swimming', 'hobby'),
  ('พายเรือ', 'Rowing', 'hobby'),
  ('ปีนหน้าผา', 'Climbing', 'hobby'),
  ('สุนัข', 'Dog', 'life'),
  ('แมว', 'Cat', 'life'),
  ('หนู', 'Mouse animal', 'life'),
  ('แฮมสเตอร์', 'Hamster', 'life'),
  ('กระต่าย', 'Rabbit', 'life'),
  ('สุนัขจิ้งจอก', 'Fox', 'life'),
  ('หมี', 'Bear', 'life'),
  ('แพนด้า', 'Panda', 'life'),
  ('โคอาลา', 'Koala', 'life'),
  ('เสือ', 'Tiger', 'life'),
  ('สิงโต', 'Lion', 'life'),
  ('วัว', 'Cow', 'life'),
  ('หมู', 'Pig', 'life'),
  ('กบ', 'Frog', 'life'),
  ('ลิง', 'Monkey', 'life'),
  ('ไก่', 'Chicken', 'life'),
  ('เพนกวิน', 'Penguin', 'life'),
  ('นก', 'Bird', 'life'),
  ('ลูกเจี๊ยบ', 'Chick', 'life'),
  ('เป็ด', 'Duck', 'life'),
  ('นกอินทรี', 'Eagle', 'life'),
  ('นกฮูก', 'Owl', 'life'),
  ('ค้างคาว', 'Bat', 'life'),
  ('หมาป่า', 'Wolf', 'life'),
  ('หมูป่า', 'Boar', 'life'),
  ('ม้า', 'Horse', 'life'),
  ('ยูนิคอร์น', 'Unicorn', 'life'),
  ('ผึ้ง', 'Bee', 'life'),
  ('หนอน', 'Caterpillar', 'life'),
  ('ผีเสื้อ', 'Butterfly', 'life'),
  ('หอยทาก', 'Snail', 'life'),
  ('เต่าทอง', 'Ladybug', 'life'),
  ('มด', 'Ant', 'life'),
  ('ยุง', 'Mosquito', 'life'),
  ('ด้วง', 'Beetle', 'life'),
  ('จิ้งหรีด', 'Cricket insect', 'life'),
  ('แมงมุม', 'Spider', 'life'),
  ('แมงป่อง', 'Scorpion', 'life'),
  ('เต่า', 'Turtle', 'life'),
  ('งู', 'Snake', 'life'),
  ('กิ้งก่า', 'Lizard', 'life'),
  ('ไดโนเสาร์ทีเร็กซ์', 'T-rex', 'life'),
  ('ไดโนเสาร์คอยาว', 'Sauropod', 'life'),
  ('ปลาหมึกยักษ์', 'Octopus', 'life'),
  ('ปลาหมึก', 'Squid', 'life'),
  ('กุ้ง', 'Shrimp', 'life'),
  ('กุ้งมังกร', 'Lobster', 'life'),
  ('ปู', 'Crab', 'life'),
  ('ปลาปักเป้า', 'Blowfish', 'life'),
  ('ปลาสวยงาม', 'Tropical fish', 'life'),
  ('ปลา', 'Fish', 'life'),
  ('โลมา', 'Dolphin', 'life'),
  ('วาฬ', 'Whale', 'life'),
  ('ฉลาม', 'Shark', 'life'),
  ('แมวน้ำ', 'Seal', 'life'),
  ('จระเข้', 'Crocodile', 'life'),
  ('ไก่งวง', 'Turkey', 'life'),
  ('เสือดาว', 'Leopard', 'life'),
  ('ม้าลาย', 'Zebra', 'life'),
  ('กอริลลา', 'Gorilla', 'life'),
  ('อุรังอุตัง', 'Orangutan', 'life'),
  ('แมมมอธ', 'Mammoth', 'life'),
  ('ช้าง', 'Elephant', 'life'),
  ('ฮิปโป', 'Hippopotamus', 'life'),
  ('แรด', 'Rhinoceros', 'life'),
  ('อูฐ', 'Camel', 'life'),
  ('ยีราฟ', 'Giraffe', 'life'),
  ('จิงโจ้', 'Kangaroo', 'life'),
  ('ไบซัน', 'Bison', 'life'),
  ('ควาย', 'Water buffalo', 'life'),
  ('วัวกระทิง', 'Ox', 'life'),
  ('แกะตัวผู้', 'Ram', 'life'),
  ('แกะ', 'Sheep', 'life'),
  ('ลามา', 'Llama', 'life'),
  ('แพะ', 'Goat', 'life'),
  ('กวาง', 'Deer', 'life'),
  ('นกยูง', 'Peacock', 'life'),
  ('นกแก้ว', 'Parrot', 'life'),
  ('หงส์', 'Swan', 'life'),
  ('ฟลามิงโก', 'Flamingo', 'life'),
  ('นกพิราบ', 'Dove', 'life'),
  ('แรคคูน', 'Raccoon', 'life'),
  ('สกังก์', 'Skunk', 'life'),
  ('แบดเจอร์', 'Badger', 'life'),
  ('บีเวอร์', 'Beaver', 'life'),
  ('นาก', 'Otter', 'life'),
  ('สลอธ', 'Sloth', 'life'),
  ('กระรอก', 'Squirrel', 'life'),
  ('เม่น', 'Hedgehog', 'life'),
  ('รอยเท้าสัตว์', 'Paw prints', 'life'),
  ('ต้นสน', 'Evergreen tree', 'life'),
  ('ต้นไม้ผลัดใบ', 'Deciduous tree', 'life'),
  ('ต้นปาล์ม', 'Palm tree', 'life'),
  ('ต้นกล้า', 'Seedling', 'life'),
  ('สมุนไพร', 'Herb', 'life'),
  ('แชมร็อก', 'Shamrock', 'life'),
  ('โคลเวอร์สี่แฉก', 'Four leaf clover', 'life'),
  ('ต้นไผ่ประดับ', 'Pine decoration', 'life'),
  ('ไม้กระถาง', 'Potted plant', 'life'),
  ('ต้นทานาบาตะ', 'Tanabata tree', 'life'),
  ('ใบไม้ปลิว', 'Leaf in wind', 'life'),
  ('ใบไม้ร่วง', 'Fallen leaf', 'life'),
  ('ใบเมเปิล', 'Maple leaf', 'life'),
  ('รวงข้าว', 'Sheaf of rice', 'life'),
  ('ชบา', 'Hibiscus', 'life'),
  ('ทานตะวัน', 'Sunflower', 'life'),
  ('กุหลาบ', 'Rose', 'life'),
  ('ทิวลิป', 'Tulip', 'life'),
  ('ซากุระ', 'Cherry blossom', 'life'),
  ('ดอกเดซี', 'Daisy', 'life'),
];
```

### 13.48 flutter_application_1/lib/widgets/amount_keypad.dart

แป้นตัวเลขร่วมและ showAmountKeypad แบบ bottom sheet แก้ text ตาม cursor จำกัดทศนิยมสองตำแหน่ง ใช้ controller เดียวกับช่องแสดงยอด

โครงสร้างที่ประกาศ: class AmountKeypad extends StatelessWidget (L5)

105 บรรทัด • SHA-256: 5470dc091c859b1b

```dart
import 'package:flutter/material.dart';
import '../screens/app_theme.dart';

/// Numeric amount entry with two decimal places and cursor-aware deletion.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.controller});
  final TextEditingController controller;
  static const double height = 232;

  void _press(String key) {
    final text = controller.text;
    final selection = controller.selection;
    var start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final replacement = key == '⌫' ? '' : key;
    if (key == '⌫' && start == end && start > 0) start--;
    var next = text.replaceRange(start, end, replacement);
    var cursor = start + replacement.length;
    if (next.startsWith('.')) {
      next = '0$next';
      cursor++;
    }
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(next) || next.length > 16) {
      return;
    }
    controller.value = TextEditingValue(
      text: next, selection: TextSelection.collapsed(offset: cursor));
  }

  Widget _key(String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16))),
          onPressed: () => _press(label),
          child: label == '⌫'
            ? const Icon(Icons.backspace_outlined, size: 23, semanticLabel: 'Delete')
            : Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(24)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final row in const [
        ['7', '8', '9'],
        ['4', '5', '6'],
        ['1', '2', '3'],
        ['.', '0', '⌫'],
      ])
        Row(children: row.map(_key).toList()),
    ]),
  ));
}

/// Opens the same amount keyboard for fields in dialogs and receipt forms.
Future<void> showAmountKeypad(
  BuildContext context, {
  required TextEditingController controller,
  required String title,
}) async {
  FocusScope.of(context).unfocus();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: TextStyle(color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: true,
            keyboardType: TextInputType.none,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, color: AppColors.ink),
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 8),
          AmountKeypad(
            controller: controller,
          ),
        ]),
      ),
    ),
  );
}
```

### 13.49 flutter_application_1/lib/widgets/bottom_nav.dart

แถบนำทาง Home/Wallet/Add/Statistic/Menu เลือกหน้าตาม index และ pushReplacement ใช้ layout ของปุ่มและภาพร่วมกับระบบ artwork

โครงสร้างที่ประกาศ: class BottomNav extends StatelessWidget (L13); class _NavItemData (L153)

158 บรรทัด • SHA-256: 729abd95f147bcb9

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../screens/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/add_income_expense_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/account_setting_screen.dart';
import 'pastel_artwork.dart';

/// Five evenly aligned tabs sized to the available screen width.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget page;
    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const WalletScreen();
        break;
      case 2:
        page = const AddIncomeExpenseScreen();
        break;
      case 3:
        page = const StatisticScreen();
        break;
      default:
        page = const AccountSettingScreen();
    }
    Navigator.pushReplacement(context, _noAnimationRoute(page));
  }

  PageRoute _noAnimationRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();

    final items = <_NavItemData>[
      _NavItemData(3, service.t('nav_home')),
      _NavItemData(14, service.t('nav_wallet')),
      _NavItemData(5, service.t('nav_add'), big: true),
      _NavItemData(20, service.t('nav_stat')),
      _NavItemData(13, service.t('nav_menu')),
    ];

    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final margin = (width * 0.03).clamp(8.0, 16.0);
            final itemWidth = (width - margin * 2 - 10) / items.length;
            final iconSize = (itemWidth * 0.36).clamp(22.0, 26.0);
            final iconHeight = (itemWidth * 0.44).clamp(28.0, 32.0);
            final addWidth = (itemWidth * 0.72).clamp(40.0, 56.0);
            final fontSize = (itemWidth * 0.16).clamp(10.5, 12.0);
            final textScaler = MediaQuery.textScalerOf(context);
            final styles = List.generate(items.length, (i) => TextStyle(
              fontFamily: appFontFamily, fontSize: fontSize, height: 1.4,
              fontWeight: i == currentIndex ? FontWeight.w800 : FontWeight.w500,
              color: i == currentIndex ? AppColors.ink : AppColors.textSecondary,
            ));
            // Reserve the same label height in all five tabs, including when
            // accessibility text sizing makes a label wrap onto a second line.
            var labelHeight = 0.0;
            for (var i = 0; i < items.length; i++) {
              final painter = TextPainter(
                text: TextSpan(text: items[i].label, style: styles[i]),
                textDirection: Directionality.of(context),
                textScaler: textScaler, maxLines: 2,
              )..layout(maxWidth: itemWidth - 4);
              if (painter.height > labelHeight) labelHeight = painter.height;
              painter.dispose();
            }
            return Container(
              margin: EdgeInsets.fromLTRB(margin, 4, margin, 6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: AppColors.shadow,
                  blurRadius: 18, offset: const Offset(0, 5))],
              ),
              child: Row(children: List.generate(items.length, (i) {
                final item = items[i];
                final selected = i == currentIndex;
                return Expanded(child: Semantics(
                  selected: selected, button: true, label: item.label,
                  child: Tooltip(
                    message: item.label,
                    child: InkWell(
                      key: ValueKey('nav-$i'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _onTap(context, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(height: iconHeight,
                            child: Center(child: item.big
                              ? Container(
                                  width: addWidth, height: iconHeight,
                                  decoration: BoxDecoration(color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(iconHeight / 2)),
                                  child: Icon(Icons.add_rounded,
                                    size: iconSize, color: AppColors.accentDeep),
                                )
                              : ExcludeSemantics(child: PastelArtwork(
                                  categoryNumber: item.categoryNumber, size: iconSize)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(height: labelHeight,
                            child: Center(child: Text(item.label,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center, style: styles[i])),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(duration: const Duration(milliseconds: 180),
                            height: 3, width: selected ? 18 : 0,
                            decoration: BoxDecoration(color: AppColors.accent,
                              borderRadius: BorderRadius.circular(3))),
                        ]),
                      ),
                    ),
                  ),
                ));
              })),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItemData {
  final int categoryNumber;
  final String label;
  final bool big;
  const _NavItemData(this.categoryNumber, this.label, {this.big = false});
}
```

### 13.50 flutter_application_1/lib/widgets/category_artwork_catalog.dart

รวม metadata ภาพเพิ่มเติมและสร้างตัวเลือกหมวด/กลุ่มค้นหา ใช้ artwork ID คงที่เพื่อให้ภาพที่บันทึกไว้ไม่เปลี่ยนเมื่อเปิดใหม่

51 บรรทัด • SHA-256: 82d1a6204fec05be

```dart
import 'additional_category_artwork.dart';
import 'package:flutter/material.dart';
import '../models/category_model.dart';

/// Stable artwork IDs are persisted with custom categories; never renumber them.
final extraCategoryArtwork = <(String, String, String)>[
  ('ครัวซองต์', 'Croissant', 'food'), ('เค้ก', 'Cake', 'food'),
  ('โดนัท', 'Donut', 'food'), ('ซูชิ', 'Sushi', 'food'),
  ('พิซซ่า', 'Pizza', 'food'), ('ไอศกรีม', 'Ice cream', 'food'),
  ('หูฟัง', 'Headphones', 'tech'), ('แล็ปท็อป', 'Laptop computer', 'tech'),
  ('กล้อง', 'Camera', 'tech'), ('นาฬิกาอัจฉริยะ', 'Smartwatch', 'tech'),
  ('คีย์บอร์ด', 'Keyboard', 'tech'), ('เครื่องพิมพ์', 'Printer', 'tech'),
  ('จักรยาน', 'Bicycle', 'travel'), ('รถไฟ', 'Train', 'travel'),
  ('สกู๊ตเตอร์', 'Scooter', 'travel'), ('กระเป๋าเดินทาง', 'Suitcase', 'travel'),
  ('เต็นท์', 'Tent camping', 'travel'), ('ชายหาด', 'Beach umbrella', 'travel'),
  ('ตุ๊กตาหมี', 'Teddy bear toy', 'life'), ('ขวดนม', 'Baby bottle', 'life'),
  ('ต้นกระบองเพชร', 'Cactus plant', 'life'), ('ช่อดอกไม้', 'Flower bouquet', 'life'),
  ('หนังสือ', 'Book reading', 'life'), ('วาดรูป', 'Painting palette art', 'life'),
  ('รองเท้า', 'Sneakers shoes', 'fashion'), ('กระเป๋าถือ', 'Handbag', 'fashion'),
  ('แว่นกันแดด', 'Sunglasses', 'fashion'), ('น้ำหอม', 'Perfume', 'fashion'),
  ('ไดร์เป่าผม', 'Hair dryer', 'fashion'), ('แหวน', 'Ring jewelry', 'fashion'),
  ('ดัมเบล', 'Dumbbell fitness', 'hobby'), ('บาสเกตบอล', 'Basketball', 'hobby'),
  ('เทนนิส', 'Tennis racket', 'hobby'), ('กีตาร์', 'Guitar music', 'hobby'),
  ('ไมโครโฟน', 'Microphone singing', 'hobby'), ('จิ๊กซอว์', 'Puzzle game', 'hobby'),
  for (final item in additionalCategoryArtwork) (item.$1, item.$2, item.$3),
];

List<CategoryModel> categoryArtworkCatalog(bool thai) => [
  // 33 and 34 share an atlas cell; retain legacy rendering but offer it once.
  for (final category in defaultCategories)
    if (category.id != 'c34')
      if (category.id == 'c18')
        CategoryModel(id: category.id, name: thai ? 'รับเงินออม' : 'Savings received',
          type: category.type, icon: category.icon, imagePath: category.imagePath)
      else category,
  for (var i = 0; i < extraCategoryArtwork.length; i++)
    CategoryModel(id: 'art${100 + i}',
      name: thai ? extraCategoryArtwork[i].$1 : extraCategoryArtwork[i].$2,
      type: CategoryType.expense, icon: Icons.category_outlined, artworkNumber: 100 + i),
];

int artworkNumberOf(CategoryModel c) => c.artworkNumber ?? int.parse(c.id.substring(1));
String artworkGroup(int number) {
  if (number >= 100 && number < 100 + extraCategoryArtwork.length) return extraCategoryArtwork[number - 100].$3;
  if ([1, 2, 35].contains(number)) return 'food';
  if ([45, 46, 47, 54, 55].contains(number)) return 'tech';
  if ([4, 8, 36, 37, 38, 39, 53].contains(number)) return 'travel';
  if ([6, 9, 44].contains(number)) return 'fashion';
  if ([10, 11, 48].contains(number)) return 'hobby';
  return 'life';
}
```

### 13.51 flutter_application_1/lib/widgets/category_editor_sheet.dart

สร้างหมวดพร้อมชื่อ สี หมวดย่อย และภาพ เลือก artwork จาก catalog/หมวดที่มีอยู่ เมื่อ service.addCategory สำเร็จคืน CategoryModel ให้หน้าที่เรียกเลือกใช้

โครงสร้างที่ประกาศ: class CategoryEditorSheet extends StatefulWidget (L24); class _CategoryEditorSheetState extends State<CategoryEditorSheet> (L32); class _IconPicker extends StatefulWidget (L169); class _IconPickerState extends State<_IconPicker> (L177)

309 บรรทัด • SHA-256: 3738a904f2ae6d19

```dart
import 'category_artwork_catalog.dart';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../screens/app_theme.dart';
import '../services/data_service.dart';
import 'pastel_artwork.dart';

Future<CategoryModel?> showCategoryArtworkPicker(BuildContext context,
    {required DataService service, required int selected}) {
  return showModalBottomSheet<CategoryModel>(
    context: context, isScrollControlled: true, useSafeArea: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _IconPicker(service: service, selected: selected),
  );
}

const _colors = [
  Color(0xFFC1E4F3), Color(0xFFF6CCD9), Color(0xFFFFE698),
  Color(0xFFCDE7CA), Color(0xFFD8D1EF), Color(0xFFFFD4B5),
  Color(0xFFBFE5DE), Color(0xFFDFE9B6), Color(0xFFD3DCEB),
];

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({super.key, required this.service, required this.type});
  final DataService service;
  final CategoryType type;
  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final _name = TextEditingController();
  final _children = <TextEditingController>[];
  CategoryModel _icon = defaultCategories.first;
  Color _color = _colors.first;
  bool _saving = false;
  String? _error;
  bool get _thai => widget.service.currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;
  int get _number => _icon.artworkNumber ?? int.tryParse(_icon.id.replaceFirst('c', '')) ?? 1;

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _children) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final names = _children.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = widget.service.t('please_enter_category_name'));
      return;
    }
    if (names.map((s) => s.toLowerCase()).toSet().length != names.length) {
      setState(() => _error = _t('ชื่อหมวดหมู่ย่อยต้องไม่ซ้ำกัน', 'Subcategory names must be unique.'));
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final category = await widget.service.addCategory(_name.text, widget.type, _icon.icon,
        colorValue: _color.toARGB32(), artworkNumber: _number, subcategories: names);
      if (mounted) Navigator.pop(context, category);
    } catch (_) {
      if (mounted) setState(() {
        _saving = false;
        _error = _t('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง ข้อมูลยังอยู่', 'Could not save. Your changes are retained. Please try again.');
      });
    }
  }

  Future<void> _chooseIcon() async {
    FocusScope.of(context).unfocus();
    final icon = await showModalBottomSheet<CategoryModel>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _IconPicker(service: widget.service, selected: _number),
    );
    if (mounted && icon != null) setState(() => _icon = icon);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: AbsorbPointer(absorbing: _saving,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(_t('เพิ่มหมวดหมู่ของคุณ', 'Create your category'), style: AppTextStyles.heading.copyWith(fontSize: 19))),
              IconButton.filledTonal(onPressed: _saving ? null : () => Navigator.pop(context),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            Center(child: Semantics(button: true, label: widget.service.t('choose_icon'),
              child: InkWell(onTap: _chooseIcon, borderRadius: BorderRadius.circular(60),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(width: 64, height: 64,
                    decoration: BoxDecoration(color: _color.withValues(alpha: 0.5), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: PastelArtwork(categoryNumber: _number, size: 44)),
                  Positioned(right: -2, top: -2, child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                    child: Icon(Icons.edit_outlined, size: 20, color: AppColors.ink))),
                ]),
              ),
            )),
            TextButton(onPressed: _chooseIcon, child: Text(widget.service.t('choose_icon'))),
            const SizedBox(height: 8),
            SizedBox(height: 52, child: ListView.separated(
              scrollDirection: Axis.horizontal, itemCount: _colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (_, i) => Semantics(selected: _color == _colors[i],
                label: _t('สี ${i + 1}', 'Color ${i + 1}'), button: true,
                child: InkWell(onTap: () => setState(() => _color = _colors[i]),
                  borderRadius: BorderRadius.circular(26),
                  child: Container(width: 48, margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle,
                      border: Border.all(color: _color == _colors[i] ? AppColors.ink : Colors.transparent, width: 2)),
                    child: _color == _colors[i] ? Icon(Icons.check_rounded, color: AppColors.accentDeep) : null),
                ),
              ),
            )),
            const SizedBox(height: 24),
            Text(_t('ชื่อหมวดหมู่', 'Category name'), style: AppTextStyles.label),
            const SizedBox(height: 8),
            AppTextField(controller: _name, hint: widget.service.t('category_name_hint'),
              onChanged: (_) { if (_error != null) setState(() => _error = null); }),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text(_t('หมวดหมู่ย่อย (ไม่บังคับ)', 'Subcategories (optional)'), style: AppTextStyles.label)),
              IconButton.filledTonal(
                tooltip: _t('เพิ่มหมวดหมู่ย่อย', 'Add subcategory'),
                onPressed: () => setState(() => _children.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded)),
            ]),
            for (var i = 0; i < _children.length; i++)
              Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                Expanded(child: AppTextField(controller: _children[i], hint: _t('ชื่อหมวดหมู่ย่อย', 'Subcategory name'))),
                IconButton(tooltip: _t('ลบหมวดหมู่ย่อย', 'Remove subcategory'),
                  onPressed: () {
                    final removed = _children[i];
                    setState(() => _children.removeAt(i));
                    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                  }, icon: const Icon(Icons.close_rounded)),
              ])),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.danger))),
            const SizedBox(height: 26),
            FilledButton(onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.service.t('save'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ]),
        ),
      ),
    ),
  );
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.service, required this.selected});
  final DataService service;
  final int selected;
  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  final _search = TextEditingController();
  String _query = '';
  String _tab = 'all';
  bool get _thai => widget.service.currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final custom = widget.service.categories.where((c) => c.artworkNumber != null);
    final mine = custom.map((c) => c.artworkNumber == 34 ? 33 : c.artworkNumber).toSet();
    final catalog = categoryArtworkCatalog(_thai);
    final tabs = <(String, String)>[
      ('all', _t('ทั้งหมด', 'All')), ('new', _t('มาใหม่', 'New')),
      ('mine', _t('ของฉัน', 'Mine')), ('food', _t('อาหาร', 'Food')),
      ('tech', _t('เทคโนโลยี', 'Tech')), ('travel', _t('เดินทาง', 'Travel')),
      ('life', _t('ของใช้', 'Lifestyle')), ('fashion', _t('แฟชั่น', 'Fashion')),
      ('hobby', _t('งานอดิเรก', 'Hobbies')),
    ];
    final icons = catalog.where((c) {
      final n = artworkNumberOf(c);
      final inTab = _tab == 'all' || (_tab == 'new' && n >= 100) ||
        (_tab == 'mine' && mine.contains(n)) || artworkGroup(n) == _tab;
      final names = [c.name, widget.service.categoryName(c),
        if (n >= 100) extraCategoryArtwork[n - 100].$1,
        if (n >= 100) extraCategoryArtwork[n - 100].$2,
        ...custom.where((item) => item.artworkNumber == n).map((item) => item.name)].join(' ').toLowerCase();
      return inTab && names.contains(_query.trim().toLowerCase());
    }).toList();
    return SizedBox(height: MediaQuery.sizeOf(context).height * 0.88,
      child: SafeArea(top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: CustomScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.auto_awesome_rounded, color: AppColors.ink, size: 23)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.service.t('choose_icon'), style: AppTextStyles.heading.copyWith(fontSize: 20)),
                      Text(_t('เติมความน่ารักให้หมวดหมู่ของคุณ', 'A little personality for your category'),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(context),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      style: IconButton.styleFrom(backgroundColor: AppColors.card, foregroundColor: AppColors.ink),
                      icon: const Icon(Icons.close_rounded, size: 21)),
                  ]),
                  const SizedBox(height: 20),
                  TextField(controller: _search, onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: _t('ค้นหารูป เช่น เค้ก กล้อง ดอกไม้', 'Search cake, camera, flowers'),
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      suffixIcon: _query.isEmpty ? null : IconButton(
                        tooltip: _t('ล้างการค้นหา', 'Clear search'), icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () { _search.clear(); setState(() => _query = ''); }),
                      filled: true, fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.accentDeep)),
                    )),
                  const SizedBox(height: 16),
                  Wrap(spacing: 7, runSpacing: 7, children: tabs.map((tab) => ChoiceChip(
                    label: Text(tab.$2), selected: _tab == tab.$1, showCheckmark: false,
                    onSelected: (_) => setState(() => _tab = tab.$1),
                    backgroundColor: AppColors.card, selectedColor: AppColors.accentBg,
                    side: BorderSide.none, shape: const StadiumBorder(),
                    labelStyle: TextStyle(fontFamily: appFontFamily, fontSize: 12,
                      color: _tab == tab.$1 ? AppColors.ink : AppColors.textSecondary,
                      fontWeight: _tab == tab.$1 ? FontWeight.w700 : FontWeight.w500),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList()),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Text(_t('เลือกรูปที่ใช่', 'Find your favorite'), style: AppTextStyles.label)),
                    Text('${icons.length} '+_t('รูป', 'icons'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                ]),
              )),
              if (icons.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.search_off_rounded, size: 38, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(_tab == 'mine' && _query.isEmpty
                      ? _t('ไอคอนที่บันทึกกับหมวดหมู่จะอยู่ที่นี่', 'Saved category icons will appear here')
                      : _t('ไม่พบรูป ลองค้นหาด้วยคำอื่นนะ', 'No matches. Try another search.'),
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  ]))),
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  key: const Key('category-artwork-grid'),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 88),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final icon = icons[i];
                    final number = artworkNumberOf(icon);
                    final selected = number == (widget.selected == 34 ? 33 : widget.selected);
                    return Tooltip(message: widget.service.categoryName(icon),
                      child: Semantics(button: true, selected: selected, label: widget.service.categoryName(icon),
                        child: Material(color: AppColors.card, borderRadius: BorderRadius.circular(20),
                          child: InkWell(borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context, icon),
                            child: Container(padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: selected ? AppColors.accentDeep : AppColors.border.withValues(alpha: 0.6), width: selected ? 2 : 1)),
                              child: Center(child: PastelArtwork(categoryNumber: number, size: 56))),
                          ),
                        ),
                      ),
                    );
                  }, childCount: icons.length),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 13.52 flutter_application_1/lib/widgets/data_action.dart

runDataAction จับ exception ของงาน async แล้วแสดง SnackBar เมื่อ context ยัง mounted; refreshAppData ใช้ wrapper นี้เรียก refreshData

16 บรรทัด • SHA-256: b740d78a72ee524b

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

Future<void> runDataAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> refreshAppData(BuildContext context) =>
    runDataAction(context, context.read<DataService>().refreshData);
```

### 13.53 flutter_application_1/lib/widgets/password_requirements.dart

ฟังค่าจาก controller ของรหัสและยืนยัน แสดงเงื่อนไขที่ผ่าน/ไม่ผ่านตาม policy และข้อความภาษาปัจจุบัน ช่วยผู้ใช้แก้ก่อนส่งฟอร์ม

โครงสร้างที่ประกาศ: class PasswordRequirements extends StatelessWidget (L7)

84 บรรทัด • SHA-256: 2b88ff1da530970b

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/app_theme.dart';
import '../services/data_service.dart';
import '../services/password_policy.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements(
      {super.key, required this.password, required this.confirmation});
  final TextEditingController password;
  final TextEditingController confirmation;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return AnimatedBuilder(
      animation: Listenable.merge([password, confirmation]),
      builder: (context, _) {
        final invalid = passwordValidationKey(password.text);
        Widget check(String label, bool passed) => Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(children: [
                Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color:
                        passed ? AppColors.success : AppColors.textSecondary),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: passed
                                ? AppColors.success
                                : AppColors.textSecondary))),
              ]),
            );
        final value = password.text;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.t('password_requirements'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            check(
                service.currentLanguage == 'English'
                    ? 'At least 6 characters'
                    : 'ความยาว 6 ตัวอักษรขึ้นไป',
                value.runes.length >= passwordMinLength),
            check(service.t('password_lowercase'),
                RegExp(r'[a-z]').hasMatch(value)),
            check(service.t('password_uppercase'),
                RegExp(r'[A-Z]').hasMatch(value)),
            check(
                service.t('password_digit'), RegExp(r'[0-9]').hasMatch(value)),
            check(
                service.t('password_symbol'),
                RegExp(r'[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]')
                    .hasMatch(value)),
            if (password.text.isNotEmpty)
              Text(service.t(invalid ?? 'password_valid'),
                  style: TextStyle(
                      fontSize: 12,
                      color: invalid == null
                          ? AppColors.success
                          : AppColors.danger)),
            if (confirmation.text.isNotEmpty)
              Text(
                  service.t(password.text == confirmation.text
                      ? 'password_confirmed'
                      : 'password_mismatch'),
                  style: TextStyle(
                      fontSize: 12,
                      color: password.text == confirmation.text
                          ? AppColors.success
                          : AppColors.danger)),
          ]),
        );
      },
    );
  }
}
```

### 13.54 flutter_application_1/lib/widgets/pastel_artwork.dart

PastelArtwork เลือกภาพจาก atlas ตามหมายเลข และ GoalArtwork เชื่อมไอคอนเป้าหมายกับภาพ วาด/ครอปตามตำแหน่งให้ภาพเดียวกันใช้ได้หลายหน้า

โครงสร้างที่ประกาศ: class PastelArtwork extends StatelessWidget (L6); class GoalArtwork extends StatelessWidget (L100)

146 บรรทัด • SHA-256: 18187b6a4f314f45

```dart
import 'package:flutter/material.dart';
import 'additional_category_artwork.dart';

/// Original pastel artwork atlas. Rows have explicit bounds because the
/// illustrations use slightly different spacing in the generated source.
class PastelArtwork extends StatelessWidget {
  const PastelArtwork(
      {super.key, required this.categoryNumber, this.size = 24});
  final int categoryNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final artworkIndex = categoryNumber - 136;
    if (artworkIndex >= 0 && artworkIndex < additionalCategoryArtwork.length) {
      final sheet = (artworkIndex ~/ 36).toString().padLeft(2, '0');
      final cell = artworkIndex % 36;
      return SizedBox(width: size, height: size,
        child: ClipRect(child: Stack(children: [
          Positioned(left: -(cell % 6) * size, top: -(cell ~/ 6) * size,
            width: size * 6, height: size * 6,
            child: Image.asset(
              'assets/images/categories/pastel_collection_${sheet}_transparent.png',
              semanticLabel: additionalCategoryArtwork[artworkIndex].$1,
              fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
        ])),
      );
    }
    if (categoryNumber >= 100 && categoryNumber < 136) {
      final index = categoryNumber - 100;
      return SizedBox(width: size, height: size,
        child: ClipRect(child: Stack(children: [
          Positioned(left: -(index % 6) * size, top: -(index ~/ 6) * size,
            width: size * 6, height: size * 6,
            child: Image.asset('assets/images/categories/pastel_extra_atlas_transparent.png',
              fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
        ])));
    }
    if (categoryNumber == 9) {
      return Image.asset(
        'assets/images/categories/beauty_lipstick_pastel.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'ลิปสติก',
      );
    }
    final index =
        categoryNumber <= 33 ? categoryNumber - 1 : categoryNumber - 2;
    final int row;
    final int column;
    final int columns;
    if (index < 32) {
      row = index ~/ 8;
      column = index % 8;
      columns = 8;
    } else if (index < 41) {
      row = 4;
      column = index - 32;
      columns = 9;
    } else {
      row = 5 + (index - 41) ~/ 8;
      column = (index - 41) % 8;
      columns = 8;
    }
    const bounds = [0.0, 210.0, 380.0, 552.0, 720.0, 884.0, 1050.0, 1254.0];
    final edges = row == 5
        ? <double>[0, 155, 303, 454, 583, 761, 941, 1090, 1254]
        : row == 4
            ? <double>[0, 158, 289, 439, 585, 718, 860, 998, 1120, 1254]
            : List<double>.generate(columns + 1, (i) => 1254 * i / columns);
    final cellWidth = edges[column + 1] - edges[column];
    final cellHeight = bounds[row + 1] - bounds[row];
    final scale = size / (cellWidth > cellHeight ? cellWidth : cellHeight);
    // The rice bowl sits low and right inside its atlas cell. Center the
    // illustration's bounds while retaining the original rendering scale.
    final source = categoryNumber == 1
        ? const Rect.fromLTRB(18, 52, 163, 196)
        : Rect.fromLTWH(edges[column], bounds[row], cellWidth, cellHeight);
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: SizedBox(width: source.width * scale, height: source.height * scale, child: ClipRect(
        child: Stack(children: [
          Positioned(
            left: -source.left * scale,
            top: -source.top * scale,
            width: 1254 * scale,
            height: 1254 * scale,
            child: Image.asset('assets/images/categories/pastel_atlas_transparent.png',
                fit: BoxFit.fill, filterQuality: FilterQuality.medium),
          ),
        ]),
      ))),
    );
  }
}

/// Keep saved goal icon codes compatible while presenting the new artwork.
class GoalArtwork extends StatelessWidget {
  const GoalArtwork(this.icon, {super.key, this.size = 24, this.color, this.artworkNumber});
  final IconData icon;
  final int? artworkNumber;
  final double size;
  final Color? color;
  static const icons = [
    Icons.restaurant,
    Icons.local_cafe,
    Icons.home,
    Icons.directions_car,
    Icons.receipt_long,
    Icons.shopping_bag,
    Icons.card_giftcard,
    Icons.flight,
    Icons.spa,
    Icons.music_note,
    Icons.sports_soccer,
    Icons.pets,
    Icons.school,
  ];
  @override
  Widget build(BuildContext context) {
    if (artworkNumber != null) {
      return PastelArtwork(categoryNumber: artworkNumber!, size: size);
    }
    final index = icons.indexWhere((item) => item.codePoint == icon.codePoint);
    final extra = <int, int>{
      Icons.category_outlined.codePoint: 32,
      Icons.payments.codePoint: 14,
      Icons.trending_up.codePoint: 20,
      Icons.card_membership.codePoint: 16,
      Icons.savings.codePoint: 17,
      Icons.fastfood.codePoint: 1,
      Icons.local_hospital.codePoint: 49,
      Icons.build.codePoint: 43,
      Icons.pets_outlined.codePoint: 12,
      Icons.celebration.codePoint: 26,
      Icons.wifi.codePoint: 46,
      Icons.subscriptions.codePoint: 47,
    };
    final number = index >= 0 ? index + 1 : extra[icon.codePoint];
    return number == null
        ? Icon(icon, size: size, color: color)
        : Center(child: PastelArtwork(categoryNumber: number, size: size));
  }
}
```

### 13.55 flutter_application_1/lib/widgets/period_selector.dart

ChartPeriod, PeriodFilterBar และ dialog เลือกวัน/เดือน/ปี ใช้ callback ส่งค่าไปให้หน้าที่คำนวณกราฟ ไม่อ่านหรือเขียนรายการฐานข้อมูลเอง

โครงสร้างที่ประกาศ: enum ChartPeriod (L7); class PeriodFilterBar extends StatelessWidget (L31); class _PastelDialogFrame extends StatelessWidget (L190); class _CalendarBadge extends StatelessWidget (L240); class _PillButton extends StatelessWidget (L282); class _PastelChoiceTile extends StatelessWidget (L318); class _NavArrow extends StatelessWidget (L356); class PastelCalendarDialog extends StatefulWidget (L382); class _PastelCalendarDialogState extends State<PastelCalendarDialog> (L400); class PastelMonthDialog extends StatefulWidget (L586); class _PastelMonthDialogState extends State<PastelMonthDialog> (L606); class PastelYearDialog extends StatefulWidget (L684); class _PastelYearDialogState extends State<PastelYearDialog> (L702)

758 บรรทัด • SHA-256: 2a789d8a06bef3ec

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

/// ประเภทช่วงเวลาที่ใช้กรองกราฟรายรับ-รายจ่าย: วัน / เดือน / ปี
enum ChartPeriod { day, month, year }

const List<String> _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const List<String> _enMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];
const List<String> _enMonthsAbbr = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

// สัปดาห์เริ่มวันอาทิตย์ (ตามดีไซน์ปฏิทินอ้างอิงใหม่)
const List<String> _thaiWeekdaysSun = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
const List<String> _enWeekdaysSun = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// แถบเลือกช่วงเวลา (วัน/เดือน/ปี) พร้อมปุ่มเลือกวันที่/เดือน/ปีที่ต้องการดูข้อมูลจริง
class PeriodFilterBar extends StatelessWidget {
  final ChartPeriod period;
  final DateTime anchor;
  final ValueChanged<ChartPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  /// ปฏิทินเลือกวัน — การ์ดพาสเทล "เลือกวันที่" (เหมือนกับตัวเลือกเดือน/ปี)
  Future<void> _pickDay(BuildContext context) async {
    final service = context.read<DataService>();
    final isThai = service.currentLanguage != 'English';

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelCalendarDialog(
        initialDate: anchor,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  /// เลือกเดือน — การ์ดพาสเทลสไตล์เดียวกับเลือกวันที่/ปี
  Future<void> _pickMonth(BuildContext context, bool isThai) async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelMonthDialog(
        initialMonth: anchor.month,
        initialYear: anchor.year,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (picked != null) onAnchorChanged(picked);
  }

  /// เลือกปี — การ์ดพาสเทลสไตล์เดียวกับเลือกวันที่/เดือน
  Future<void> _pickYear(BuildContext context, bool isThai) async {
    final pickedYear = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelYearDialog(
        initialYear: anchor.year,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        isThai: isThai,
      ),
    );
    if (pickedYear != null) onAnchorChanged(DateTime(pickedYear, anchor.month, 1));
  }

  String _label(DataService service) {
    final isThai = service.currentLanguage != 'English';
    final months = isThai ? _thaiMonthsFull : _enMonthsFull;
    switch (period) {
      case ChartPeriod.day:
        return '${anchor.day} ${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.month:
        return '${months[anchor.month - 1]} ${anchor.year}';
      case ChartPeriod.year:
        return '${anchor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _periodChip(service.t('period_day'), ChartPeriod.day),
            const SizedBox(width: 4),
            _periodChip(service.t('period_month'), ChartPeriod.month),
            const SizedBox(width: 4),
            _periodChip(service.t('period_year'), ChartPeriod.year),
          ],
        ),
        GestureDetector(
          onTap: () {
            switch (period) {
              case ChartPeriod.day:
                _pickDay(context);
                break;
              case ChartPeriod.month:
                _pickMonth(context, isThai);
                break;
              case ChartPeriod.year:
                _pickYear(context, isThai);
                break;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(_label(service),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _periodChip(String label, ChartPeriod value) {
    final selected = period == value;
    return GestureDetector(
      onTap: () => onPeriodChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDeep : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }
}

// ====================================================================
// กรอบการ์ดกลาง (Dialog Frame) ใช้ร่วมกันทั้ง 3 ตัวเลือก วัน/เดือน/ปี
// เพื่อให้หน้าตาเหมือนกันทุกจุด ไม่งงว่าอันไหนคืออันไหน:
// [หัวข้อ + ป้ายวันที่ไล่เฉด] -> [เนื้อหาเฉพาะของแต่ละตัวเลือก] -> [ปุ่มยืนยัน]
// ====================================================================
class _PastelDialogFrame extends StatelessWidget {
  final String title;
  final Widget badge;
  final Widget content;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  const _PastelDialogFrame({
    required this.title,
    required this.badge,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 14),
            PrimaryButton(label: confirmLabel, onPressed: onConfirm),
          ],
        ),
      ),
    );
  }
}

/// ป้าย (badge) มุมขวาบนไล่เฉดสีพาสเทลเดียวกับ Pinned Goals — ใช้ร่วมกันทั้ง
/// การ์ดเลือกวัน/เดือน/ปี เพื่อให้เห็นภาพจำเดียวกันว่ากำลังเลือก "อะไรอยู่"
class _CalendarBadge extends StatelessWidget {
  final Widget child;
  const _CalendarBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.pinnedGoalBg,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -4, left: 13, child: _ringDot()),
          Positioned(top: -4, right: 13, child: _ringDot()),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _ringDot() => Container(
        width: 6,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.pinnedGoalIcon,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// เม็ดยา (pill) ใช้เป็นตัวเลือกแบบ dropdown ร่วมกันทุกการ์ด
class _PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PillButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      ),
    );
  }
}

Widget _dropdownPillContent(String label) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
      ),
      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
    ],
  );
}

/// เซลล์กริดทรงกลม-เม็ดยาที่ใช้ร่วมกันทั้งกริดเดือนและลิสต์ปี (เลือก/ไม่เลือก/ปิดใช้งาน)
class _PastelChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _PastelChoiceTile({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: disabled ? null : onTap,
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? AppColors.textMuted
                      : selected
                          ? Colors.white
                          : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// ปุ่มลูกศรเลื่อนปีถัดไป/ก่อนหน้า (ใช้ในการ์ดเลือกเดือน)
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.accentDeep.withOpacity(onTap == null ? 0.03 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Icon(icon, size: 20, color: onTap == null ? AppColors.textMuted : AppColors.textSecondary),
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "วันที่" — ปฏิทินเต็มรูปแบบ พร้อมดรอปดาวน์เดือน/ปีด้านใน
// (แตะดรอปดาวน์เดือน/ปีจะเปิดการ์ดเดือน/ปีแบบเดียวกันนี้ซ้อนขึ้นมา)
// ====================================================================
class PastelCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelCalendarDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelCalendarDialog> createState() => _PastelCalendarDialogState();
}

class _PastelCalendarDialogState extends State<PastelCalendarDialog> {
  late DateTime _visibleMonth;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  List<String> get _months => widget.isThai ? _thaiMonthsFull : _enMonthsFull;
  List<String> get _weekdays => widget.isThai ? _thaiWeekdaysSun : _enWeekdaysSun;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openMonthPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelMonthDialog(
        initialMonth: _visibleMonth.month,
        initialYear: _visibleMonth.year,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        isThai: widget.isThai,
      ),
    );
    if (picked != null) {
      setState(() => _visibleMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _openYearPicker() async {
    final pickedYear = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PastelYearDialog(
        initialYear: _visibleMonth.year,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        isThai: widget.isThai,
      ),
    );
    if (pickedYear != null) {
      setState(() => _visibleMonth = DateTime(pickedYear, _visibleMonth.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Sunday-first: DateTime.weekday คือ Mon=1..Sun=7 -> % 7 ทำให้ Sun=0
    final leadingEmptyDays = firstDayOfMonth.weekday % 7;
    final prevMonthLastDay = DateTime(_visibleMonth.year, _visibleMonth.month, 0).day;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกวันที่' : 'Select Date',
      badge: _CalendarBadge(
        child: Text(_selected.day.toString().padLeft(2, '0'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, _selected),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  onTap: _openMonthPicker,
                  child: _dropdownPillContent(_months[_visibleMonth.month - 1]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PillButton(
                  onTap: _openYearPicker,
                  child: _dropdownPillContent('${_visibleMonth.year}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_weekdays.length, (i) {
              return Expanded(
                child: Center(
                  child: Text(_weekdays[i],
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? AppColors.accentDeep : AppColors.textSecondary)),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          ...List.generate(rows, (rowIndex) {
            return Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                int dayNumber;
                bool isCurrentMonth;
                DateTime cellDate;

                if (cellIndex < leadingEmptyDays) {
                  dayNumber = prevMonthLastDay - (leadingEmptyDays - cellIndex - 1);
                  final prevMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  cellDate = DateTime(prevMonth.year, prevMonth.month, dayNumber);
                  isCurrentMonth = false;
                } else if (cellIndex < leadingEmptyDays + daysInMonth) {
                  dayNumber = cellIndex - leadingEmptyDays + 1;
                  cellDate = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
                  isCurrentMonth = true;
                } else {
                  dayNumber = cellIndex - leadingEmptyDays - daysInMonth + 1;
                  final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  cellDate = DateTime(nextMonth.year, nextMonth.month, dayNumber);
                  isCurrentMonth = false;
                }

                final isSelected = _sameDay(cellDate, _selected);
                final isToday = _sameDay(cellDate, today);
                final disabled =
                    cellDate.isBefore(widget.firstDate) || cellDate.isAfter(widget.lastDate);

                return Expanded(
                  child: GestureDetector(
                    onTap: disabled
                        ? null
                        : () {
                            setState(() {
                              _selected = cellDate;
                              if (!isCurrentMonth) {
                                _visibleMonth = DateTime(cellDate.year, cellDate.month);
                              }
                            });
                          },
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentDeep : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (!isCurrentMonth || disabled)
                                    ? AppColors.textMuted
                                    : isToday
                                        ? AppColors.accentDeep
                                        : AppColors.textPrimary,
                            decoration: (isToday && !isSelected) ? TextDecoration.underline : null,
                            decorationColor: AppColors.accentDeep,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "เดือน" — หน้าตาเดียวกับเลือกวันที่/ปี: หัวข้อ+ป้าย, ตัวเลือก
// ปีด้วยลูกศรซ้าย-ขวา, กริดเดือน 12 ช่อง, ปุ่มยืนยัน
// ====================================================================
class PastelMonthDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelMonthDialog({
    super.key,
    required this.initialMonth,
    required this.initialYear,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelMonthDialog> createState() => _PastelMonthDialogState();
}

class _PastelMonthDialogState extends State<PastelMonthDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  List<String> get _monthsFull => widget.isThai ? _thaiMonthsFull : _enMonthsFull;
  List<String> get _monthsAbbr => widget.isThai ? _thaiMonthsAbbr : _enMonthsAbbr;

  @override
  Widget build(BuildContext context) {
    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกเดือน' : 'Select Month',
      badge: _CalendarBadge(
        child: Text(_monthsAbbr[_month - 1],
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, DateTime(_year, _month, 1)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _year--),
              ),
              Expanded(
                child: Center(
                  child: Text('$_year',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: _year >= widget.lastDate.year ? null : () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final m = i + 1;
              final disabled = DateTime(_year, m, 1).isAfter(widget.lastDate) ||
                  DateTime(_year, m, 1).isBefore(DateTime(widget.firstDate.year, widget.firstDate.month));
              return _PastelChoiceTile(
                label: _monthsFull[i],
                selected: m == _month,
                disabled: disabled,
                onTap: () => setState(() => _month = m),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// การ์ดเลือก "ปี" — หน้าตาเดียวกับเลือกวันที่/เดือน: หัวข้อ+ป้าย, ลิสต์ปี,
// ปุ่มยืนยัน
// ====================================================================
class PastelYearDialog extends StatefulWidget {
  final int initialYear;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isThai;

  const PastelYearDialog({
    super.key,
    required this.initialYear,
    required this.firstDate,
    required this.lastDate,
    required this.isThai,
  });

  @override
  State<PastelYearDialog> createState() => _PastelYearDialogState();
}

class _PastelYearDialogState extends State<PastelYearDialog> {
  late int _year;
  late final ScrollController _scrollController;
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (i) => widget.lastDate.year - i,
    );
    final initialIndex = _years.indexOf(_year).clamp(0, _years.length - 1);
    _scrollController =
        ScrollController(initialScrollOffset: (initialIndex - 2).clamp(0, _years.length).toDouble() * 48.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PastelDialogFrame(
      title: widget.isThai ? 'เลือกปี' : 'Select Year',
      badge: _CalendarBadge(
        child: Text(_year.toString().substring(2),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.pinnedGoalIcon)),
      ),
      confirmLabel: widget.isThai ? 'ยืนยัน' : 'Confirm',
      onConfirm: () => Navigator.pop(context, _year),
      content: SizedBox(
        height: 280,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _years.length,
          itemBuilder: (context, i) {
            final y = _years[i];
            final selected = y == _year;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _PastelChoiceTile(
                label: '$y',
                selected: selected,
                disabled: false,
                onTap: () => setState(() => _year = y),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

### 13.56 flutter_application_1/lib/widgets/quick_actions.dart

วิดเจ็ตทางลัดไปฟังก์ชันต่าง ๆ ผ่าน Navigator; เป็นองค์ประกอบ UI ที่ต้องถูกวางในหน้าจอจึงใช้งานได้ การมีไฟล์ไม่ยืนยันว่าปรากฏทุกหน้า

โครงสร้างที่ประกาศ: class QuickActions extends StatelessWidget (L13)

68 บรรทัด • SHA-256: 232926226fe64453

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../screens/add_income_expense_screen.dart';
import '../screens/app_theme.dart';
import '../screens/goal_saving_screen.dart';
import '../screens/income_expense_screen.dart';
import '../screens/receipt_scan_screen.dart';
import '../services/data_service.dart';
import 'pastel_artwork.dart';

/// The same four everyday actions across the dashboard, wallet and menu.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final th = service.currentLanguage != 'English';
    final actions = <(String, int, Widget)>[
      (
        th ? 'จดรายจ่าย' : 'Expense',
        6,
        const AddIncomeExpenseScreen(initialType: CategoryType.expense)
      ),
      (th ? 'สลิป / ใบเสร็จ' : 'Slip / receipt', 32, const ReceiptScanScreen()),
      (th ? 'ธุรกรรม' : 'Transactions', 21, const IncomeExpenseScreen()),
      (th ? 'ออมเงิน' : 'Savings', 17, const GoalSavingScreen()),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(26)),
      child: Row(
          children: actions
              .map((action) => Expanded(
                    child: Semantics(
                      button: true,
                      label: action.$1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                            context, noAnimationRoute(action.$3)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 2),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            ExcludeSemantics(
                                child: PastelArtwork(
                                    categoryNumber: action.$2, size: 28)),
                            const SizedBox(height: 7),
                            Text(action.$1,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                          ]),
                        ),
                      ),
                    ),
                  ))
              .toList()),
    );
  }
}
```

### 13.57 flutter_application_1/lib/widgets/receipt_category_picker.dart

sheet สำหรับค้นและเลือกหมวดรายจ่ายที่หน้าสแกนส่งมา คืนหมวดที่เลือกผ่าน Navigator.pop ไม่บันทึก transaction เอง

โครงสร้างที่ประกาศ: class _CategoryPicker extends StatefulWidget (L23); class _CategoryPickerState extends State<_CategoryPicker> (L34)

174 บรรทัด • SHA-256: 4f6aa9656ed18da6

```dart
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../screens/app_theme.dart';

Future<CategoryModel?> showReceiptCategoryPicker(
  BuildContext context, {
  required List<CategoryModel> categories,
  required String? selectedId,
  required bool thai,
}) =>
    showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => _CategoryPicker(
          categories: categories, selectedId: selectedId, thai: thai),
    );

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker(
      {required this.categories, required this.selectedId, required this.thai});
  final List<CategoryModel> categories;
  final String? selectedId;
  final bool thai;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where(
            (c) => c.name.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                        child: Container(
                            width: 38,
                            height: 5,
                            decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.accentAltBg,
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: AppColors.ink)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              widget.thai
                                  ? 'เลือกหมวดหมู่'
                                  : 'Choose a category',
                              style: AppTextStyles.heading)),
                      IconButton(
                          tooltip: widget.thai ? 'ปิด' : 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: AppColors.ink)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                          hintText: widget.thai
                              ? 'ค้นหาหมวดหมู่'
                              : 'Search categories',
                          prefixIcon:
                              Icon(Icons.search_rounded, color: AppColors.ink),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                        child: categories.isEmpty
                            ? Center(
                                child: Text(
                                    widget.thai
                                        ? 'ไม่พบหมวดหมู่นี้ ลองค้นหาใหม่นะ'
                                        : 'No categories found. Try another search.',
                                    textAlign: TextAlign.center))
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: categories.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final selected =
                                      category.id == widget.selectedId;
                                  final colors = [
                                    AppColors.accentBg,
                                    AppColors.surfaceAlt,
                                    AppColors.accentAltBg
                                  ];
                                  return Semantics(
                                      selected: selected,
                                      child: Material(
                                        color: selected
                                            ? AppColors.accentBg
                                            : colors[index % colors.length]
                                                .withValues(alpha: .55),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            side: BorderSide(
                                                color: selected
                                                    ? AppColors.ink
                                                    : Colors.transparent)),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () =>
                                              Navigator.pop(context, category),
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                              child: Row(children: [
                                                CategoryIcon(
                                                    category: category,
                                                    size: 44),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                    child: Text(category.name,
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textPrimary))),
                                                if (selected)
                                                  Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: AppColors.ink),
                                              ])),
                                        ),
                                      ));
                                },
                              )),
                  ]),
            )),
      ),
    );
  }
}
```

### 13.58 flutter_application_1/lib/widgets/receipt_scan_error_dialog.dart

dialog แสดงความล้มเหลวของ OCR แยกหมดเวลา/บริการไม่พร้อม/อ่านไม่ได้ และให้ปิดกลับไปลองรูปใหม่ รองรับข้อความไทย/อังกฤษ

โครงสร้างที่ประกาศ: class ReceiptScanErrorDialog extends StatelessWidget (L4)

166 บรรทัด • SHA-256: c17af13dee7d0ff5

```dart
import 'package:flutter/material.dart';
import '../screens/app_theme.dart';

class ReceiptScanErrorDialog extends StatelessWidget {
  const ReceiptScanErrorDialog({
    super.key,
    required this.isThai,
    this.timedOut = false,
    this.serviceUnavailable = false,
    this.message,
  });

  final bool isThai;
  final bool timedOut;
  final bool serviceUnavailable;
  final String? message;
  String _t(String th, String en) => isThai ? th : en;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  style:
                      IconButton.styleFrom(backgroundColor: AppColors.surface),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accentBg, AppColors.surfaceAlt],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(
                      timedOut
                          ? Icons.hourglass_bottom_rounded
                          : Icons.receipt_long_rounded,
                      size: 40,
                      color: AppColors.ink),
                  Positioned(
                    right: 8,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: AppColors.accentAltBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2)),
                      child: Icon(Icons.priority_high_rounded,
                          size: 15, color: AppColors.ink),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(_t('สแกนไม่สำเร็จ', 'Scan unsuccessful'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              Text(
                  message ??
                      (timedOut
                          ? _t(
                              'ใช้เวลาประมวลผลนานกว่าปกติ\nลองตรวจการเชื่อมต่อ แล้วสแกนอีกครั้งนะ',
                              'This is taking longer than expected. Check your connection and try again.')
                          : _t(
                              'ยังอ่านยอดเงินจากรูปนี้ไม่ได้\nลองใช้ภาพใบเสร็จหรือสลิปที่ชัดขึ้นนะ',
                              'We couldn’t read the total. Try a clearer photo of your receipt or payment slip.')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 14,
                      height: 1.65,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.accentAltBg,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          timedOut
                              ? Icons.crop_rounded
                              : Icons.lightbulb_outline_rounded,
                          color: AppColors.ink,
                          size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              timedOut
                                  ? _t(
                                      'ครอปให้เหลือเฉพาะสลิปหรือใบเสร็จ แล้วลองใหม่',
                                      'Crop the image to the slip or receipt and try again.')
                                  : serviceUnavailable
                                      ? _t(
                                          'ใช้แอปบน Android หรือ iPhone และปิดเปิดแอปใหม่หลังอัปเดต',
                                          'Use the Android or iPhone app and restart it after updating.')
                                      : _t(
                                          'ถ่ายให้เห็นยอดรวมครบ แสงเพียงพอ\nและไม่มีเงาบังตัวเลข',
                                          'Include the full total in good light, with no shadows over the numbers.'),
                              style: TextStyle(
                                  fontFamily: appFontFamily,
                                  fontSize: 12.5,
                                  height: 1.6,
                                  color: AppColors.ink))),
                    ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 21),
                  label: Text(
                      serviceUnavailable
                          ? _t('ปิด', 'Close')
                          : _t('กลับไปเลือกรูป', 'Back to photos'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
```

### 13.59 flutter_application_1/lib/widgets/responsive_scale.dart

ห่อ SafeArea แนวนอนโดยไม่ transform scale ทั้งแอป แต่ละหน้ารับผิดชอบความสูง ส่วนหัว และคีย์บอร์ดเอง

โครงสร้างที่ประกาศ: class ResponsiveScale extends StatelessWidget (L9)

19 บรรทัด • SHA-256: 30542402711fa5e0

```dart
import 'package:flutter/material.dart';

/// Keeps the app in the device's real logical coordinates.
///
/// Layouts respond to their own constraints instead of scaling a virtual
/// 360-pixel canvas. Preserve system text sizing and keyboard/safe-area metrics.
/// Only horizontal safe areas are applied here; each screen owns its header
/// and bottom inset so backgrounds can still extend behind the system bars.
class ResponsiveScale extends StatelessWidget {
  const ResponsiveScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: child,
      );
}
```

### 13.60 flutter_application_1/lib/widgets/success_notice.dart

banner สำเร็จบน root overlay มีตัวเลือกเปิดปิด แทน notice เดิมและ timer ปิด; Semantics liveRegion ช่วยการอ่านผลด้วย accessibility

โครงสร้างที่ประกาศ: class _SuccessNotice extends StatefulWidget (L58); class _SuccessNoticeState extends State<_SuccessNotice> (L71)

111 บรรทัด • SHA-256: 85cf6a642a7dcbd0

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

final _notices = Expando<OverlayEntry>('success notices');

/// Display above the navigator so closing a sheet or changing routes keeps it visible.
void showSuccessNotice(BuildContext context, String messageKey) {
  final service = context.read<DataService>();
  if (!service.successNotesEnabled) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  final message = service.t(messageKey);
  final dismissLabel = service.t('dismiss_success_notice');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!overlay.mounted) return;
    final previous = _notices[overlay];
    if (previous != null) {
      previous.remove();
      previous.dispose();
    }
    late final OverlayEntry entry;
    void dismiss() {
      if (_notices[overlay] != entry) return;
      _notices[overlay] = null;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _SuccessNotice(
                  message: message,
                  dismissLabel: dismissLabel,
                  onDismiss: dismiss),
            ),
          ),
        ),
      ),
    );
    _notices[overlay] = entry;
    overlay.insert(entry);
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

class _SuccessNotice extends StatefulWidget {
  const _SuccessNotice(
      {required this.message,
      required this.dismissLabel,
      required this.onDismiss});
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  State<_SuccessNotice> createState() => _SuccessNoticeState();
}

class _SuccessNoticeState extends State<_SuccessNotice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Material(
          color: const Color(0xFF216746),
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ),
              IconButton(
                tooltip: widget.dismissLabel,
                onPressed: widget.onDismiss,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ]),
          ),
        ),
      );
}
```

### 13.61 flutter_application_1/lib/widgets/transaction_sheet_style.dart

รวมสีและกรอบ sheet ของรายละเอียด/แก้ไข รวมส่วนหัว ปุ่มปิด และเนื้อหา เพื่อให้หน้ารายการมีหน้าตาสอดคล้องกัน

โครงสร้างที่ประกาศ: class TransactionSheetColors (L4); class TransactionSheetFrame extends StatelessWidget (L14)

98 บรรทัด • SHA-256: 31a756dfa0eef46c

```dart
import 'package:flutter/material.dart';
import '../screens/app_theme.dart' show appFontFamily;

class TransactionSheetColors {
  static const background = Color(0xFFF6F9FF);
  static const ink = Color(0xFF3D568F);
  static const muted = Color(0xFF8493B3);
  static const accent = Color(0xFFC1E4F3);
  static const red = Color(0xFFE0645F);
  static const green = Color(0xFF3D9E73);
}

/// Scrolls on small screens and keeps actions above the keyboard.
class TransactionSheetFrame extends StatelessWidget {
  const TransactionSheetFrame(
      {super.key,
      required this.title,
      required this.child,
      required this.actions,
      this.busy = false});
  final String title;
  final Widget child;
  final Widget actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top -
                    16)
                .clamp(0, double.infinity)),
        child: Material(
          color: TransactionSheetColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: TransactionSheetColors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700))),
                      IconButton.filled(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: TransactionSheetColors.muted),
                          icon: const Icon(Icons.close_rounded)),
                    ])),
                Flexible(
                    child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: child)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: actions),
              ])),
        ),
      ),
    );
  }
}

Widget transactionWhiteCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: child);

ButtonStyle transactionActionStyle(
        {bool primary = false, bool destructive = false}) =>
    FilledButton.styleFrom(
      backgroundColor: primary ? TransactionSheetColors.accent : Colors.white,
      foregroundColor:
          destructive ? TransactionSheetColors.red : TransactionSheetColors.ink,
      disabledBackgroundColor:
          TransactionSheetColors.accent.withValues(alpha: 0.5),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontFamily: appFontFamily, fontSize: 14, fontWeight: FontWeight.w700),
    );
```

### 13.62 flutter_application_1/linux/flutter/generated_plugin_registrant.cc

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

15 บรรทัด • SHA-256: cf105e8ce1d7b7a3

```text
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_linux/file_selector_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
}
```

### 13.63 flutter_application_1/linux/flutter/generated_plugin_registrant.h

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

15 บรรทัด • SHA-256: 00f93bb5b1faefde

```text
//
//  Generated file. Do not edit.
//

// clang-format off

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter_linux/flutter_linux.h>

// Registers Flutter plugins.
void fl_register_plugins(FlPluginRegistry* registry);

#endif  // GENERATED_PLUGIN_REGISTRANT_
```

### 13.64 flutter_application_1/linux/flutter/generated_plugins.cmake

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

25 บรรทัด • SHA-256: 65075042e24dd08f

```text
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  file_selector_linux
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
```

### 13.65 flutter_application_1/linux/runner/main.cc

โค้ด host ฝั่ง Linux: เชื่อม lifecycle หน้าต่าง GTK กับ Flutter engine และ plugins ส่วนกฎข้อมูลอยู่ Dart; Firebase options ปัจจุบันยังไม่รองรับ Linux

6 บรรทัด • SHA-256: ea23f7cdf74091d6

```text
#include "my_application.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
```

### 13.66 flutter_application_1/linux/runner/my_application.cc

โค้ด host ฝั่ง Linux: เชื่อม lifecycle หน้าต่าง GTK กับ Flutter engine และ plugins ส่วนกฎข้อมูลอยู่ Dart; Firebase options ปัจจุบันยังไม่รองรับ Linux

148 บรรทัด • SHA-256: 055fdb7230018801

```text
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "flutter_application_1");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "flutter_application_1");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
```

### 13.67 flutter_application_1/linux/runner/my_application.h

โค้ด host ฝั่ง Linux: เชื่อม lifecycle หน้าต่าง GTK กับ Flutter engine และ plugins ส่วนกฎข้อมูลอยู่ Dart; Firebase options ปัจจุบันยังไม่รองรับ Linux

21 บรรทัด • SHA-256: a4218d7ac0db8a9a

```text
#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication,
                     my_application,
                     MY,
                     APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new();

#endif  // FLUTTER_MY_APPLICATION_H_
```

### 13.68 flutter_application_1/macos/Flutter/GeneratedPluginRegistrant.swift

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

24 บรรทัด • SHA-256: 3096bd7a50b78caa

```swift
//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import cloud_firestore
import file_selector_macos
import firebase_auth
import firebase_core
import google_sign_in_ios
import shared_preferences_foundation
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FLTFirebaseFirestorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseFirestorePlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  FLTFirebaseAuthPlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseAuthPlugin"))
  FLTFirebaseCorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseCorePlugin"))
  FLTGoogleSignInPlugin.register(with: registry.registrar(forPlugin: "FLTGoogleSignInPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}
```

### 13.69 flutter_application_1/macos/Runner/AppDelegate.swift

App delegate ของ macOS จัดวงจรชีวิตและนโยบายปิดหน้าต่างของแอป Flutter

โครงสร้างที่ประกาศ: class AppDelegate: FlutterAppDelegate (L5)

13 บรรทัด • SHA-256: ce9dbe45a57c59e8

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
```

### 13.70 flutter_application_1/macos/Runner/MainFlutterWindow.swift

สร้าง FlutterViewController ในหน้าต่าง macOS และ register plugins ก่อนแสดง UI จาก Dart

โครงสร้างที่ประกาศ: class MainFlutterWindow: NSWindow (L4)

15 บรรทัด • SHA-256: 65c9613c11bcedfa

```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
```

### 13.71 flutter_application_1/macos/RunnerTests/RunnerTests.swift

ชุดทดสอบ: โครงทดสอบฝั่ง native ที่มากับโปรเจกต์ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

โครงสร้างที่ประกาศ: class RunnerTests: XCTestCase (L5)

12 บรรทัด • SHA-256: 6bc180bc77c7def7

```swift
import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}
```

### 13.72 flutter_application_1/test/amount_keypad_test.dart

ชุดทดสอบ: ปุ่มที่มีอยู่จริง ทศนิยมสองหลัก และ sheet บนหน้าจอแคบ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| keypad has only digits, decimal and backspace |
| shared keypad limits decimals and resets after external edits |
| amount sheet works on a narrow phone without system keyboard |

74 บรรทัด • SHA-256: b5e633ad65d1850f

```dart
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
```

### 13.73 flutter_application_1/test/bottom_nav_layout_test.dart

ชุดทดสอบ: การจัดแนวเมนูล่างในความกว้างและ text scale ต่าง ๆ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| aligned navigation at width $width and text scale $scale |

41 บรรทัด • SHA-256: b9a5b08d214be378

```dart
import 'package:budgetmate/services/data_service.dart';
import 'package:budgetmate/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  for (final width in [320.0, 390.0, 648.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('aligned navigation at width $width and text scale $scale', (tester) async {
        final service = DataService(database: MemoryDB());
        addTearDown(service.dispose);
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(bottom: 34)), child: child!),
            home: const Scaffold(bottomNavigationBar: BottomNav(currentIndex: 2))),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rects = List.generate(5, (i) => tester.getRect(find.byKey(ValueKey('nav-$i'))));
        for (final rect in rects) {
          expect(rect.top, closeTo(rects.first.top, 0.01));
          expect(rect.bottom, closeTo(rects.first.bottom, 0.01));
          expect(rect.width, closeTo(rects.first.width, 0.01));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.bottom, lessThanOrEqualTo(766));
        }
        expect(rects.last.right - rects.first.left, lessThanOrEqualTo(640));
        expect((rects.first.left + rects.last.right) / 2, closeTo(width / 2, 0.01));
      });
    }
  }
}
```

### 13.74 flutter_application_1/test/category_artwork_catalog_test.dart

ชุดทดสอบ: จำนวนตัวเลือก ID คงที่ และความแตกต่างของช่องภาพใน atlas รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| 410 new image cells are nonempty and have distinct pixels |
| 500 distinct choices with stable artwork IDs and valid groups |
| all illustrated cells use their own atlas position without emoji |

111 บรรทัด • SHA-256: 99859f8ad269e459

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/widgets/additional_category_artwork.dart';
import 'package:budgetmate/widgets/category_artwork_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('410 new image cells are nonempty and have distinct pixels', () async {
    final fingerprints = <String>{};
    for (var sheet = 0; sheet < 12; sheet++) {
      final path = 'assets/images/categories/pastel_collection_${sheet.toString().padLeft(2, '0')}_transparent.png';
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      expect(image.width, image.height);
      final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer.asUint8List();
      for (var cell = 0; cell < (sheet == 11 ? 14 : 36); cell++) {
        final x0 = ((cell % 6) * image.width / 6).round();
        final x1 = ((cell % 6 + 1) * image.width / 6).round();
        final y0 = ((cell ~/ 6) * image.height / 6).round();
        final y1 = ((cell ~/ 6 + 1) * image.height / 6).round();
        final bytes = BytesBuilder(copy: false);
        var coloredPixels = 0;
        var transparentPixels = 0;
        for (var y = y0; y < y1; y++) {
          final row = Uint8List.sublistView(pixels,
              (y * image.width + x0) * 4, (y * image.width + x1) * 4);
          bytes.add(row);
          for (var x = 0; x < row.length; x += 4) {
            if (row[x + 3] == 0) transparentPixels++;
            if (row[x + 3] > 200 &&
                (row[x] < 200 || row[x + 1] < 200 || row[x + 2] < 200)) {
              coloredPixels++;
            }
          }
        }
        expect(coloredPixels, greaterThan(500), reason: '$path cell $cell is empty');
        expect(transparentPixels, greaterThan(500),
            reason: '$path cell $cell still has an opaque background');
        expect(fingerprints.add(sha256.convert(bytes.takeBytes()).toString()), isTrue,
            reason: '$path cell $cell repeats another illustration');
      }
      image.dispose();
      codec.dispose();
    }
    expect(fingerprints, hasLength(410));
  });

  test('500 distinct choices with stable artwork IDs and valid groups', () {
    for (final thai in [true, false]) {
      final catalog = categoryArtworkCatalog(thai);
      expect(catalog, hasLength(500));
      expect(catalog.map((c) => c.id).toSet(), hasLength(500));
      expect(catalog.map((c) => c.name).toSet(), hasLength(500));
      expect(catalog.map(artworkNumberOf).toSet(), hasLength(500));
      for (final category in catalog) {
        expect(['food', 'tech', 'travel', 'life', 'fashion', 'hobby'],
            contains(artworkGroup(artworkNumberOf(category))));
        expect(artworkNumberOf(CategoryModel.fromMap(category.toMap())),
            artworkNumberOf(category));
      }
      expect(catalog.any((c) => artworkNumberOf(c) == 34), isFalse);
      expect(catalog.firstWhere((c) => c.id == 'art100').artworkNumber, 100);
      expect(catalog.firstWhere((c) => c.id == 'art135').artworkNumber, 135);
    }
    expect(additionalCategoryArtwork.map((a) => a.$2).toSet(), hasLength(410));
  });

  testWidgets('all illustrated cells use their own atlas position without emoji', (tester) async {
    for (final size in [24.0, 58.0]) {
      for (var sheet = 0; sheet < 12; sheet++) {
        final start = sheet * 36;
        final end = (start + 36).clamp(0, additionalCategoryArtwork.length);
        final path = 'assets/images/categories/pastel_collection_${sheet.toString().padLeft(2, '0')}_transparent.png';
        await tester.pumpWidget(MaterialApp(home: Scaffold(body:
          Wrap(children: [
            for (var i = start; i < end; i++)
              CategoryIcon(category: CategoryModel.fromMap(CategoryModel(
                id: 'saved-$i', name: additionalCategoryArtwork[i].$1,
                type: CategoryType.expense, icon: Icons.category_outlined,
                artworkNumber: 136 + i,
              ).toMap()), size: size),
          ]),
        )));
        await tester.runAsync(() async {
          await precacheImage(AssetImage(path),
              tester.element(find.byType(Scaffold)));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Text), findsNothing);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, hasLength(end - start));
        expect(images.every((image) => image.image == AssetImage(path)), isTrue);
        final cells = tester.widgetList<Positioned>(find.byType(Positioned))
            .where((cell) => cell.width == size * 6).toList();
        for (var cell = 0; cell < cells.length; cell++) {
          expect(cells[cell].left, -(cell % 6) * size);
          expect(cells[cell].top, -(cell ~/ 6) * size);
        }
      }
    }
  });
}
```

### 13.75 flutter_application_1/test/currency_test.dart

ชุดทดสอบ: การตรึงสกุลเงินแต่ละรายการและไม่แปลงยอดเดิม รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| new entries retain selected currency; old amounts never convert |

28 บรรทัด • SHA-256: 8d9792e7b11bc4db

```dart
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/user_model.dart';
import 'package:budgetmate/services/data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new entries retain selected currency; old amounts never convert', () async {
    final db = MemoryDB();
    final service = DataService(database:db)..currentUser=UserModel(id:'u',name:'Test',email:'u@example.com',createdAt:DateTime(2026));
    await db.insert('users',service.currentUser!.toMap());
    final category=defaultCategories.firstWhere((c)=>c.type==CategoryType.income);
    await service.addTransaction(type:CategoryType.income,amount:100,category:category,date:DateTime(2026));
    await service.setCurrency('USD');
    expect(service.balance,0);
    await service.addTransaction(type:CategoryType.income,amount:5,category:category,date:DateTime(2026));
    expect(service.balance,5);
    expect(db.tables['transactions']!.values.last['currency'],'USD');
    expect(db.tables['transactions']!.values.first['amount'],100);
    await service.setCurrency('THB');
    expect(service.balance,100);
    await service.refreshData();
    expect(service.balance,100);
    expect(service.transactions.single.currency,'THB');
    service.dispose();
  });
}
```

### 13.76 flutter_application_1/test/data_service_test.dart

ชุดทดสอบ: กฎยอดรวม การบันทึกล้มเหลว การกรองเจ้าของ การแก้รายการ หมวด และความสัมพันธ์รายการโอนกับเป้าหมาย รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

โครงสร้างที่ประกาศ: class MemoryDB implements DBHelper (L9)

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| custom category colors, artwork and child transactions survive reload |
| failed category save leaves no partial children |
| income, expense and period summaries agree |
| invalid amounts never enter the ledger |
| backdated entries are sorted by date |
| failed add edit and delete preserve ledger |
| profile changes apply only after persistence |
| failed avatar removal preserves current profile image |
| refresh restores persisted entries and filters other users |
| custom category persists across refresh |
| goal validation and completed initial savings |
| failed contribution and delete preserve goal |
| transfer handles failure, balance limit and target completion |
| editing all fields keeps one record and updates totals after reload |
| pin and edit goal survive reload, saved amount is preserved |
| failed goal edits and pinning keep existing state |
| editing and deleting savings transfers updates goal and ledger together |

270 บรรทัด • SHA-256: df12d6f9f1a91d2a

```dart
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
```

### 13.77 flutter_application_1/test/google_login_navigation_test.dart

ชุดทดสอบ: เส้นทางบัญชี Google ใหม่/เดิมและเมื่อ login ล้มเหลว รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

โครงสร้างที่ประกาศ: class GoogleLoginService extends DataService (L13)

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| Google login routes correctly for newAccount=$newAccount |
| failed or cancelled Google login stays on login |

64 บรรทัด • SHA-256: e67cb70c7c51080f

```dart
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
```

### 13.78 flutter_application_1/test/home_goals_test.dart

ชุดทดสอบ: เป้าหมายปักหมุด โน้ต และการเลือกภาพ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| other artwork can be selected, saved and reopened on a goal |
| goal notes appear on cards, open in full, and update after editing |
| home offers a goal even before the first one is created |
| pinned goals are visible and open savings |
| home only shows pinned goals and removes them when unpinned |

145 บรรทัด • SHA-256: 66893371e80945b1

```dart
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
```

### 13.79 flutter_application_1/test/language_setup_test.dart

ชุดทดสอบ: preview ค่าเดิม การบันทึก และการไม่ออกจากหน้าถ้าล้มเหลว รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| loads saved language and currency; preview does not persist |
| save failure stays on setup and restores controls |
| setup persists profile and local defaults |
| failed setup does not mark complete |

58 บรรทัด • SHA-256: ec1fead9accb3b0a

```dart
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
```

### 13.80 flutter_application_1/test/local_receipt_store_test.dart

ชุดทดสอบ: การเก็บ bytes แยกเจ้าของและการปฏิเสธ path ลบที่ไม่ถูกต้อง รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| persists bytes locally with distinct account namespaces |
| cleanup cannot delete arbitrary paths or cloud receipts |

40 บรรทัด • SHA-256: 53db7665ea5a428c

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:budgetmate/services/local_receipt_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalReceiptStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt-store-test-');
    store = LocalReceiptStore(directory: () async => root);
  });
  tearDown(() async => root.delete(recursive: true));

  test('persists bytes locally with distinct account namespaces', () async {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final first = await store.save(bytes, owner: 'user-a', isPng: true);
    final second = await store.save(bytes, owner: 'user-b', isPng: true);
    expect(first.split('/').first, isNot(second.split('/').first));
    expect(first, startsWith('local-receipt:'));
    final files =
        await root.list(recursive: true).where((f) => f is File).toList();
    expect(files, hasLength(2));
    expect(await (files.first as File).readAsBytes(), bytes);
    await store.delete(first);
    expect(await root.list(recursive: true).where((f) => f is File).length, 1);
    await store.delete(first); // Retry cleanup is safe.
    await store.delete(second);
  });

  test('cleanup cannot delete arbitrary paths or cloud receipts', () async {
    for (final marker in [
      'local-receipt:../../outside',
      '/tmp/file',
      'receipts/user/id'
    ]) {
      await expectLater(store.delete(marker), throwsArgumentError);
    }
  });
}
```

### 13.81 flutter_application_1/test/password_policy_test.dart

ชุดทดสอบ: ความยาว ชนิดอักขระ และรหัสผ่านที่ปิดกั้น รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| requires length and every character class |
| blocks common passwords and preserves maximum length |

25 บรรทัด • SHA-256: 60087d12df8c70b4

```dart
import 'package:budgetmate/services/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires length and every character class', () {
    expect(passwordValidationKey('Aa1!x'), 'password_min_length');
    expect(passwordValidationKey('Aa1!xy'), isNull);
    expect(passwordValidationKey('Violet river 29!'), isNull);
    expect(passwordValidationKey('VIOLET RIVER 29!'), 'password_lowercase');
    expect(passwordValidationKey('violet river 29!'), 'password_uppercase');
    expect(passwordValidationKey('Violet river abc!'), 'password_digit');
    expect(passwordValidationKey('Violet river 290'), 'password_symbol');
    expect(passwordValidationKey('Violet river 29🌻'), 'password_symbol');
    expect(passwordValidationKey('  Violet river 29!  '), isNull);
  });
  test('blocks common passwords and preserves maximum length', () {
    expect(passwordValidationKey('123456789012345'), 'password_common');
    expect(passwordValidationKey('PasswordPassword'), 'password_common');
    expect(passwordValidationKey(' ' * 15), 'password_common');
    expect(passwordValidationKey('Aa1!' + 'x' * 124), isNull);
    expect(passwordValidationKey('Aa1!' + 'x' * 125), 'password_max_length');
    expect(passwordValidationKey('Aa1!' + '🌻' * 62), isNull);
    expect(passwordValidationKey('Aa1!' + '🌻' * 63), 'password_max_length');
  });
}
```

### 13.82 flutter_application_1/test/persisted_icons_test.dart

ชุดทดสอบ: ไอคอนที่โหลดกลับจากข้อมูลและ fallback รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| default categories retain their icons when loaded from storage |
| saved goals retain their selected icon |
| unrecognized stored icon uses a visible fallback |

48 บรรทัด • SHA-256: 070e0fa512f66231

```dart
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/models/goal_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default categories retain their icons when loaded from storage', () {
    for (final category in defaultCategories) {
      expect(CategoryModel.fromMap(category.toMap()).icon, category.icon);
    }
  });

  test('saved goals retain their selected icon', () {
    const goalIcons = [
      Icons.restaurant,
      Icons.local_cafe,
      Icons.home,
      Icons.directions_car,
      Icons.receipt_long,
      Icons.shopping_bag,
      Icons.card_giftcard,
      Icons.flight,
      Icons.spa,
      Icons.music_note,
      Icons.sports_soccer,
      Icons.pets,
      Icons.school,
      Icons.savings,
    ];
    for (final icon in goalIcons) {
      final goal = GoalModel(
        id: 'goal',
        name: 'Trip',
        targetAmount: 100,
        savedAmount: 10,
        startDate: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 12, 1),
        icon: icon,
      );
      expect(GoalModel.fromMap(goal.toMap('user')).icon, icon);
    }
  });

  test('unrecognized stored icon uses a visible fallback', () {
    final map = defaultCategories.first.toMap()..['icon_code'] = -1;
    expect(CategoryModel.fromMap(map).icon, Icons.category_outlined);
  });
}
```

### 13.83 flutter_application_1/test/phone_card_layout_test.dart

ชุดทดสอบ: การ์ดบนขนาดโทรศัพท์และ text scale หลายค่า รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| phone cards fit $size $brightness text $scale with safe areas |

160 บรรทัด • SHA-256: 229c77554bccc0aa

```dart
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
```

### 13.84 flutter_application_1/test/receipt_ocr_assets_test.dart

ชุดทดสอบ: ไฟล์โมเดล OCR ไทย/อังกฤษไม่ใช่หน้า error ที่ดาวน์โหลดผิด รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| offline Thai and English models are bundled, not download error pages |

22 บรรทัด • SHA-256: 51b104b9dd356864

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline Thai and English models are bundled, not download error pages',
      () async {
    final config =
        jsonDecode(await File('assets/tessdata_config.json').readAsString());
    expect(
        config['files'], containsAll(['tha.traineddata', 'eng.traineddata']));
    for (final name in config['files']) {
      final file = File('assets/tessdata/$name');
      expect(await file.length(), greaterThan(1000000));
      final handle = await file.open();
      final header = await handle.read(4);
      await handle.close();
      // Tesseract traineddata starts with a little-endian component count.
      expect(header, [24, 0, 0, 0]);
    }
  });
}
```

### 13.85 flutter_application_1/test/receipt_parser_test.dart

ชุดทดสอบ: ยอดสุทธิ/ยอดโอน ชื่อผู้รับ เลขไทย วันที่ และการไม่เดาจากข้อมูลกำกวม รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| MAKE selects recipient above second masked account, not heading |
| recipient labels preserve spacing and ignore sender |
| incomplete or conflicting recipient evidence stays blank |
| SCB separated amount columns and decomposed Thai OCR label |
| uses grand total rather than subtotal, cash, change or VAT |
| reads Thai digits, Buddhist date and amount on next line |
| does not guess from prices, phone numbers or invalid dates |
| does not take next line item description as a total |
| reads bank transfer labels and split currency without choosing fees |
| reads an unlabelled bank slip amount and abbreviated Buddhist date |
| rejects ambiguous amounts, negative totals and reference numbers |
| empty scan has no invented fields |

102 บรรทัด • SHA-256: 9f0498688dc6ac65

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetmate/services/receipt_parser.dart';

void main() {
  test('MAKE selects recipient above second masked account, not heading', () {
    final draft = ReceiptDraft.fromText(
        'โอนเงินสำเร็จ make\n30 ก.ย. 2569 16:27\nพรหมพร แรงจบ\nxxx-x-x4606-x\nศิรายุ ภูกลิ่น\nxxx-x-x4570-x\nจำนวน\n350.00 บาท');
    expect(draft.merchant, 'ศิรายุ ภูกลิ่น');
    expect(draft.amount, 350);
  });
  test('recipient labels preserve spacing and ignore sender', () {
    for (final text in [
      'โอนเงินสำเร็จ\nผู้โอน: สมชาย ใจดี\nผู้รับ: สมหญิง ใจงาม\nจำนวนเงิน 350.00',
      'Transfer successful\nFrom: John Smith\nTo\nJane Smith\nAmount 350.00',
    ]) {
      expect(ReceiptDraft.fromText(text).merchant,
          text.startsWith('Transfer') ? 'Jane Smith' : 'สมหญิง ใจงาม');
    }
  });
  test('incomplete or conflicting recipient evidence stays blank', () {
    for (final text in [
      'โอนเงินสำเร็จ make\nจำนวนเงิน 350.00',
      'โอนเงินสำเร็จ\nสมชาย ใจดี\nxxx-x-x4606-x\nจำนวนเงิน 350.00',
      'โอนเงินสำเร็จ\nผู้รับ: สมชาย ใจดี\nผู้รับ: สมหญิง ใจงาม\nจำนวนเงิน 350.00',
    ]) {
      expect(ReceiptDraft.fromText(text).merchant, isEmpty);
    }
  });
  test('SCB separated amount columns and decomposed Thai OCR label', () {
    for (final text in [
      'SCB\nโอนเงินสำเร็จ\n29 ก.ย. 2569 - 22:26\nจำนวนเงิน 350.00',
      'SCB\nโอนเงินสำเร็จ\n29 ก.ย. 2569 - 22:26\nจํานวน เงิน\n350.00',
      'SCB\nโอน เงิน สําเร็จ\n29 ก.ย. 2569 - 22:26\nจํา นวน เงิน 350.00',
    ]) {
      final draft = ReceiptDraft.fromText(text);
      expect(draft.amount, 350.00, reason: text);
      expect(draft.date, DateTime(2026, 9, 29));
    }
  });
  test('uses grand total rather than subtotal, cash, change or VAT', () {
    final draft = ReceiptDraft.fromText(
        'SHOP\nSubtotal 100.00\nVAT 7.00\nGrand Total 107.00\nCash 200.00\nChange 93.00\nTotal 100.00');
    expect(draft.amount, 107);
    expect(draft.merchant, 'SHOP');
  });
  test('reads Thai digits, Buddhist date and amount on next line', () {
    final draft =
        ReceiptDraft.fromText('ร้านค้า\n๐๙/๐๙/๒๕๖๙\nรวมสุทธิ\n๑,๒๓๔.๕๐ บาท');
    expect(draft.amount, 1234.50);
    expect(draft.date, DateTime(2026, 9, 9));
  });
  test('does not guess from prices, phone numbers or invalid dates', () {
    final draft =
        ReceiptDraft.fromText('SHOP\n0812345678\n31/02/2026\nItem 999.00');
    expect(draft.amount, isNull);
    expect(draft.date, isNull);
  });
  test('does not take next line item description as a total', () {
    expect(ReceiptDraft.fromText('Total\n2 items 100.00').amount, isNull);
  });
  test('reads bank transfer labels and split currency without choosing fees',
      () {
    for (final label in [
      'จำนวนเงินที่โอน',
      'ยอดเงินที่โอน',
      'Transfer amount',
      'Amount (THB)'
    ]) {
      final draft = ReceiptDraft.fromText(
          'โอนเงินสำเร็จ\n$label\nTHB\n1,250.50\nค่าธรรมเนียม 10.00');
      expect(draft.amount, 1250.50);
    }
  });
  test('reads an unlabelled bank slip amount and abbreviated Buddhist date',
      () {
    final draft = ReceiptDraft.fromText(
        'โอนเงินสำเร็จ\n29 ก.ย. 69 - 10:30\n1,250.50 บาท\nค่าธรรมเนียม\n10.00 บาท');
    expect(draft.amount, 1250.50);
    expect(draft.date, DateTime(2026, 9, 29));
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\n31 ก.พ. 2569\n100.00 บาท').date,
        isNull);
  });
  test('rejects ambiguous amounts, negative totals and reference numbers', () {
    for (final text in [
      'Transfer successful\nTHB 100.00\nTHB 200.00',
      'Total -100.00',
      'Amount\nReference 123456789012',
      'Amount\n123456789012',
      'โอนเงินสำเร็จ\nค่าธรรมเนียม\n10.00 บาท',
      'Holiday photo\n100.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
  });
  test('empty scan has no invented fields', () {
    final draft = ReceiptDraft.fromText('');
    expect(draft.amount, isNull);
    expect(draft.date, isNull);
    expect(draft.merchant, isEmpty);
  });
}
```

### 13.86 flutter_application_1/test/receipt_service_test.dart

ชุดทดสอบ: OCR ไม่มียอด การหมดเวลา และผลลัพธ์ที่ตรวจแก้ได้ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| non-receipt text cannot proceed to saving |
| unresponsive scanner times out instead of waiting indefinitely |
| valid receipt and transfer slip return a reviewable amount |

29 บรรทัด • SHA-256: 5a03cace04efe09e

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:budgetmate/services/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-receipt text cannot proceed to saving', () async {
    final service = ReceiptService(readText: (_) async => 'Holiday photo 2026');
    await expectLater(service.scan(Uint8List(0)), throwsFormatException);
  });
  test('unresponsive scanner times out instead of waiting indefinitely',
      () async {
    final service = ReceiptService(
        readText: (_) => Completer<String>().future,
        timeout: const Duration(milliseconds: 10));
    await expectLater(
        service.scan(Uint8List(0)), throwsA(isA<TimeoutException>()));
  });
  test('valid receipt and transfer slip return a reviewable amount', () async {
    for (final text in [
      'SHOP\nGrand total 250.00',
      'โอนเงินสำเร็จ\nจำนวนเงิน 1,200.00 บาท'
    ]) {
      final result =
          await ReceiptService(readText: (_) async => text).scan(Uint8List(0));
      expect(result.amount, text.startsWith('SHOP') ? 250 : 1200);
    }
  });
}
```

### 13.87 flutter_application_1/test/reported_issues_widget_test.dart

ชุดทดสอบ: การใช้งาน keypad หมวด กราฟ ประวัติ แก้/ทำซ้ำ และเป้าหมายผ่าน UI รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| shared numeric keypad opens and enters amounts on ${goal ?  |
| wallet back preserves login ($systemBack) |
| search category and save using the header action |
| custom category sheet saves and selects a new category |
| category editor chooses artwork, color and subcategories |
| chart matches all history and selected-day type filters |
| tiny category keeps its amount without a zero percent label |
| income chart uses income, notes visible, delete can be cancelled |
| transaction editor preloads note and saves to same id |
| history opens details, edits and duplicates only after save |
| edit sheet keeps save visible with keyboard on a small phone |
| blank confirmation reports missing field before mismatch |
| goals pin, confirm deletion, and accept typed deposit amounts |
| goal editor retains existing savings, icon and pin |

429 บรรทัด • SHA-256: c5d3b23e5b2b5370

```dart
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
```

### 13.88 flutter_application_1/test/responsive_interaction_test.dart

ชุดทดสอบ: ฟอร์ม คีย์บอร์ด และ keypad ในหลายขนาด/ธีม รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| forms keyboard and keypad $size dark=$dark |

223 บรรทัด • SHA-256: 228bf0cffc6e9e26

```dart
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
```

### 13.89 flutter_application_1/test/responsive_test_support.dart

ชุดทดสอบ: ตัวช่วยสร้างกรอบจอ/สถานะสำหรับการทดสอบ responsive ไม่ใช่หน้าจอจริง รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

24 บรรทัด • SHA-256: 208a421554db1991

```dart
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';

// Keep the viewport tests aligned with BudgetMateApp's current themes.
ThemeData phoneTheme(Brightness brightness) => brightness == Brightness.dark
    ? AppTheme.dark
    : ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.black,
        brightness: Brightness.light,
        fontFamily: appFontFamily,
        appBarTheme: const AppBarTheme(
          toolbarHeight: 56,
          titleTextStyle: TextStyle(
              fontFamily: appFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
      );
```

### 13.90 flutter_application_1/test/success_notice_test.dart

ชุดทดสอบ: banner สำเร็จหลังการทำรายการ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| success notice after $action |

73 บรรทัด • SHA-256: c400e17b0519ee2b

```dart
import 'package:budgetmate/services/data_service.dart';
import 'package:budgetmate/widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  for (final action in [
    'stay',
    'replace',
    'pop',
    'disabled',
    'close',
    'repeat'
  ]) {
    testWidgets('success notice after $action', (tester) async {
      final service = DataService(database: MemoryDB())
        ..successNotesEnabled = action != 'disabled';
      addTearDown(service.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: service,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      ));
      navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: Center(
              child: TextButton(
            onPressed: () {
              showSuccessNotice(context, 'transaction_saved');
              if (action == 'replace') {
                Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('History')),
                ));
              } else if (action == 'pop') {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          )),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(service.t('transaction_saved')),
          action == 'disabled' ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      if (action != 'disabled') {
        final notice = find.text(service.t('transaction_saved'));
        expect(tester.getTopLeft(notice).dy, lessThan(150));
        if (action == 'close') {
          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          expect(notice, findsNothing);
        } else if (action == 'repeat') {
          await tester.pump(const Duration(seconds: 3));
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 2));
          expect(notice, findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
      }
    });
  }
}
```

### 13.91 flutter_application_1/test/thai_slip_formats_test.dart

ชุดทดสอบ: ป้ายยอดหลายธนาคาร ค่าธรรมเนียม วันที่ไทย/อังกฤษ และชื่อผู้รับ รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| bank-independent label: $label |
| split currency and payment success variants |
| preserves transfer principal and does not select a same-row fee |
| rejects conflicting amounts instead of silently taking the last |
| does not invent an amount from references, accounts or OCR letters |
| Thai, English, ISO and abbreviated years |
| all twelve Thai month names and invalid dates |
| keeps Thai display names intact while normalizing OCR labels |

150 บรรทัด • SHA-256: 3c597b402c1453d4

```dart
import 'dart:typed_data';
import 'package:budgetmate/services/receipt_parser.dart';
import 'package:budgetmate/services/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic OCR variants, not a claim of verification against every bank's app.
void main() {
  const labels = [
    'จำนวนเงิน',
    'จำนวนเงินที่โอน',
    'ยอดเงินที่โอน',
    'ยอดเงินโอน',
    'ยอดโอน',
    'ยอดเงิน',
    'ยอดชำระ',
    'จำนวนเงินที่ชำระ',
    'ยอดเงินที่ชำระ',
    'ยอดที่ชำระ',
    'ยอดเงินสุทธิ',
    'ยอดชำระสุทธิ',
    'รวมทั้งสิ้น',
    'ยอดรวม',
    'Transfer Amount',
    'Amount Transferred',
    'Payment Amount',
    'Amount Paid',
    'จำนวนเงิน / Amount',
    'Amount / จำนวนเงิน',
  ];
  for (final label in labels) {
    test('bank-independent label: $label', () async {
      for (final value in [
        '1,250.50 บาท',
        '(THB) 1,250.50',
        '๑,๒๕๐.๕๐',
        '1, 250 . 50 THB'
      ]) {
        final text =
            'ทำรายการสำเร็จ\n30 กันยายน 2569\n$label\n$value\nค่าธรรมเนียม 10.00 บาท\nยอดคงเหลือ 9,999.00 บาท';
        final draft = await ReceiptService(readText: (_) async => text)
            .scan(Uint8List(0));
        expect(draft.amount, 1250.50, reason: '$label: $value');
        expect(draft.date, DateTime(2026, 9, 30));
      }
    });
  }
  test('split currency and payment success variants', () {
    for (final header in [
      'โอนเงินสำเร็จ',
      'ชำระเงินสำเร็จ',
      'ทำรายการสำเร็จ',
      'Payment successful'
    ]) {
      for (final layout in ['บาท\n350.00', '350.00\nTHB', '฿ 350.00']) {
        expect(ReceiptDraft.fromText('$header\n$layout').amount, 350);
      }
    }
  });
  test('preserves transfer principal and does not select a same-row fee', () {
    expect(
        ReceiptDraft.fromText('จำนวนเงิน 350.00 บาท ค่าธรรมเนียม 10.00 บาท')
            .amount,
        350);
    expect(ReceiptDraft.fromText('ยอดโอน 350.00\nยอดรวม 360.00').amount, 350);
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\nค่าธรรมเนียม\nบาท\n10.00').amount,
        isNull);
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\nยอดรวมค่าธรรมเนียม\n10.00 บาท')
            .amount,
        isNull);
  });
  test('rejects conflicting amounts instead of silently taking the last', () {
    for (final text in [
      'จำนวนเงิน 100.00\nAmount 200.00',
      'Amount 100.00 Total 200.00',
      'โอนเงินสำเร็จ\n100.00 บาท\n200.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
    expect(
        ReceiptDraft.fromText('จำนวนเงิน 100.00\nAmount 100.00').amount, 100);
  });
  test('does not invent an amount from references, accounts or OCR letters',
      () {
    for (final text in [
      'โอนเงินสำเร็จ\nรหัสอ้างอิง\n350.00 THB',
      'โอนเงินสำเร็จ\nบัญชี\nTHB\n1234567',
      'จำนวนเงิน 35O.OO',
      'จำนวนเงิน -350.00',
      'จำนวนเงิน\nxxx-xxx-1234',
      'จำนวนเงิน 1,25.50',
      'รายการทดสอบ\n350.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
  });
  test('Thai, English, ISO and abbreviated years', () {
    for (final date in [
      '30 กันยายน 2569',
      '30 ก.ย. 69',
      '๓๐ ก.ย. ๒๕๖๙',
      '30ก.ย.2569',
      '30 ก. ย. 2569',
      '30 กันยายน พ.ศ. 2569',
      '30 กันยายน ค.ศ. 26',
      '30 September 2026',
      '30 Sep 26',
      '30/09/2569',
      '30-09-2026',
      '2026-09-30',
      '30 / 09 / 69',
      '30/09/26',
    ]) {
      expect(
          ReceiptDraft.fromText('ทำรายการสำเร็จ\n$date\nยอดเงิน 350.00').date,
          DateTime(2026, 9, 30),
          reason: date);
    }
  });
  test('all twelve Thai month names and invalid dates', () {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    for (var i = 0; i < months.length; i++) {
      expect(ReceiptDraft.fromText('15 ${months[i]} 2569').date,
          DateTime(2026, i + 1, 15));
    }
    for (final date in ['31 กุมภาพันธ์ 2569', '2026-13-30', '29/02/2026']) {
      expect(ReceiptDraft.fromText(date).date, isNull, reason: date);
    }
  });
  test('keeps Thai display names intact while normalizing OCR labels', () {
    final draft =
        ReceiptDraft.fromText('ร้าน อาหาร ทดสอบ\nจํา นวน เงิน 350.00');
    expect(draft.merchant, 'ร้าน อาหาร ทดสอบ');
    expect(draft.amount, 350);
  });
}
```

### 13.92 flutter_application_1/tool/receipt_ocr_smoke.dart

เครื่องมือ smoke test สร้างภาพใบเสร็จตัวอย่างด้วย Canvas/ฟอนต์ Mali แล้วเรียก OCR จริง ตรวจยอด 125.50 และวันที่ เขียนสถานะเป็นไฟล์และแสดงบนจอ

53 บรรทัด • SHA-256: b1bf517ec3389e72

```dart
// Run on a device/simulator: flutter run -t tool/receipt_ocr_smoke.dart
// Synthetic data only; this does not initialize Firebase or create expenses.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:budgetmate/services/receipt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Testing offline OCR…')))));
  String status;
  try {
    final loader = FontLoader('ReceiptTest')
      ..addFont(rootBundle.load('assets/fonts/Mali-Regular.ttf'));
    await loader.load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final painter = TextPainter(
      text: const TextSpan(
        text:
            'ร้านทดสอบ\nใบเสร็จรับเงิน\n30/09/2026\nยอดสุทธิ 125.50 บาท\nGrand Total 125.50',
        style: TextStyle(
            fontFamily: 'ReceiptTest',
            fontSize: 42,
            color: Colors.black,
            height: 1.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 850);
    painter.paint(canvas, const Offset(40, 40));
    final picture = recorder.endRecording();
    final image = await picture.toImage(950, 600);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final draft = await ReceiptService().scan(data!.buffer.asUint8List());
    if (draft.amount != 125.50 || draft.date != DateTime(2026, 9, 30)) {
      throw StateError('Unexpected result: ${draft.amount}, ${draft.date}');
    }
    image.dispose();
    picture.dispose();
    painter.dispose();
    status = 'PASS: offline OCR amount=125.50 date=2026-09-30';
  } catch (error) {
    status = 'FAIL: $error';
  }
  final dir = await getApplicationSupportDirectory();
  await File('${dir.path}/receipt-ocr-smoke.txt').writeAsString(status);
  debugPrint(status);
  runApp(MaterialApp(home: Scaffold(body: Center(child: Text(status)))));
}
```

### 13.93 flutter_application_1/tool/receipt_vision_smoke/main.swift

เครื่องมือ Swift สำหรับลองอ่านภาพผ่าน Vision และตรวจผล OCR นอกหน้าจอแอป ใช้ช่วยวิเคราะห์การรองรับ native

38 บรรทัด • SHA-256: d259b7a3d40885f6

```swift
// Synthetic SCB-style layout; no real account or transaction data.
// swiftc ios/Runner/ReceiptTextRecognizer.swift tool/receipt_vision_smoke/main.swift -o /tmp/receipt-vision-check
// /tmp/receipt-vision-check
import AppKit
import Foundation
let output = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("budgetmate-vision-test")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1290, pixelsHigh: 2017, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1290, height: 2017).fill()
func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 44) {
  (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black])
}
line("SCB", 450, 1770, 90)
line("โอนเงินสำเร็จ", 430, 1570, 55)
line("29 ก.ย. 2569 - 22:26", 430, 1470)
line("รหัสอ้างอิง: TEST20260929ABC", 240, 1390)
line("จาก", 70, 1220); line("ผู้ส่งทดสอบ", 820, 1220)
line("xxx-xxx123-4", 910, 1130)
line("ไปยัง", 70, 1020); line("ผู้รับทดสอบ", 820, 1020)
line("xxx-xxx-5678", 910, 920)
line("จำนวนเงิน", 70, 740)
if CommandLine.arguments.contains("--large-amount") {
  line("350.00", 920, 728, 80)
} else {
  line("350.00", 1050, 740)
}
line("ผู้รับเงินสามารถตรวจสอบสถานะการโอนเงิน", 70, 490)
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: output.appendingPathComponent("scb-layout.png"))
let text = try ReceiptTextRecognizer.read(png) ?? "UNSUPPORTED"
try text.write(toFile: output.appendingPathComponent("ocr.txt").path, atomically: true, encoding: .utf8)
print(text)
guard text.components(separatedBy: "\n").contains("จำนวนเงิน 350.00"),
      text.contains("29 ก.ย. 2569") else { exit(1) }
```

### 13.94 flutter_application_1/web/index.html

โค้ด HTML/CSS ของหน้าเว็บตาม path: โครง DOM รูปแบบข้อความ ปุ่ม และส่วนเชื่อมสคริปต์; public/reset_password.html ใช้ร่วมกับ reset_password.js ส่วน web/index.html เป็นจุดโหลด Flutter web

38 บรรทัด • SHA-256: fc29e0df79ef3444

```text
<!DOCTYPE html>
<html>
<head>
  <!--
    If you are serving your web app in a path other than the root, change the
    href value below to reflect the base path you are serving from.

    The path provided below has to start and end with a slash "/" in order for
    it to work correctly.

    For more details:
    * https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base

    This is a placeholder for base href that will be replaced by the value of
    the `--base-href` argument provided to `flutter build`.
  -->
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="flutter_application_1">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>flutter_application_1</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

### 13.95 flutter_application_1/windows/flutter/generated_plugin_registrant.cc

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

23 บรรทัด • SHA-256: d79eeadfc15695b7

```text
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <cloud_firestore/cloud_firestore_plugin_c_api.h>
#include <file_selector_windows/file_selector_windows.h>
#include <firebase_auth/firebase_auth_plugin_c_api.h>
#include <firebase_core/firebase_core_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  CloudFirestorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CloudFirestorePluginCApi"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FirebaseAuthPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseAuthPluginCApi"));
  FirebaseCorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
}
```

### 13.96 flutter_application_1/windows/flutter/generated_plugin_registrant.h

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

15 บรรทัด • SHA-256: dbc11635d7b1ba18

```text
//
//  Generated file. Do not edit.
//

// clang-format off

#ifndef GENERATED_PLUGIN_REGISTRANT_
#define GENERATED_PLUGIN_REGISTRANT_

#include <flutter/plugin_registry.h>

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry* registry);

#endif  // GENERATED_PLUGIN_REGISTRANT_
```

### 13.97 flutter_application_1/windows/flutter/generated_plugins.cmake

ไฟล์ที่เครื่องมือ Flutter สร้างเพื่อ register plugin ของแพลตฟอร์ม ไม่ใช่กฎธุรกิจ ควรให้ระบบสร้างใหม่เมื่อ dependencies เปลี่ยน

28 บรรทัด • SHA-256: bd92fbfc57f657d5

```text
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  cloud_firestore
  file_selector_windows
  firebase_auth
  firebase_core
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
```

### 13.98 flutter_application_1/windows/runner/Runner.rc

สคริปต์ CMake สำหรับรวม native plugin หรือ resource script ฝั่ง Windows กำหนดทรัพยากรและขั้นตอน compile/link ไม่ใช่กฎบัญชีการเงิน

121 บรรทัด • SHA-256: 8f2c32989d13e90c

```text
// Microsoft Visual C++ generated resource script.
//
#pragma code_page(65001)
#include "resource.h"

#define APSTUDIO_READONLY_SYMBOLS
/////////////////////////////////////////////////////////////////////////////
//
// Generated from the TEXTINCLUDE 2 resource.
//
#include "winres.h"

/////////////////////////////////////////////////////////////////////////////
#undef APSTUDIO_READONLY_SYMBOLS

/////////////////////////////////////////////////////////////////////////////
// English (United States) resources

#if !defined(AFX_RESOURCE_DLL) || defined(AFX_TARG_ENU)
LANGUAGE LANG_ENGLISH, SUBLANG_ENGLISH_US

#ifdef APSTUDIO_INVOKED
/////////////////////////////////////////////////////////////////////////////
//
// TEXTINCLUDE
//

1 TEXTINCLUDE
BEGIN
    "resource.h\0"
END

2 TEXTINCLUDE
BEGIN
    "#include ""winres.h""\r\n"
    "\0"
END

3 TEXTINCLUDE
BEGIN
    "\r\n"
    "\0"
END

#endif    // APSTUDIO_INVOKED


/////////////////////////////////////////////////////////////////////////////
//
// Icon
//

// Icon with lowest ID value placed first to ensure application icon
// remains consistent on all systems.
IDI_APP_ICON            ICON                    "resources\\app_icon.ico"


/////////////////////////////////////////////////////////////////////////////
//
// Version
//

#if defined(FLUTTER_VERSION_MAJOR) && defined(FLUTTER_VERSION_MINOR) && defined(FLUTTER_VERSION_PATCH) && defined(FLUTTER_VERSION_BUILD)
#define VERSION_AS_NUMBER FLUTTER_VERSION_MAJOR,FLUTTER_VERSION_MINOR,FLUTTER_VERSION_PATCH,FLUTTER_VERSION_BUILD
#else
#define VERSION_AS_NUMBER 1,0,0,0
#endif

#if defined(FLUTTER_VERSION)
#define VERSION_AS_STRING FLUTTER_VERSION
#else
#define VERSION_AS_STRING "1.0.0"
#endif

VS_VERSION_INFO VERSIONINFO
 FILEVERSION VERSION_AS_NUMBER
 PRODUCTVERSION VERSION_AS_NUMBER
 FILEFLAGSMASK VS_FFI_FILEFLAGSMASK
#ifdef _DEBUG
 FILEFLAGS VS_FF_DEBUG
#else
 FILEFLAGS 0x0L
#endif
 FILEOS VOS__WINDOWS32
 FILETYPE VFT_APP
 FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904e4"
        BEGIN
            VALUE "CompanyName", "com.example" "\0"
            VALUE "FileDescription", "flutter_application_1" "\0"
            VALUE "FileVersion", VERSION_AS_STRING "\0"
            VALUE "InternalName", "flutter_application_1" "\0"
            VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved." "\0"
            VALUE "OriginalFilename", "flutter_application_1.exe" "\0"
            VALUE "ProductName", "flutter_application_1" "\0"
            VALUE "ProductVersion", VERSION_AS_STRING "\0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1252
    END
END

#endif    // English (United States) resources
/////////////////////////////////////////////////////////////////////////////



#ifndef APSTUDIO_INVOKED
/////////////////////////////////////////////////////////////////////////////
//
// Generated from the TEXTINCLUDE 3 resource.
//


/////////////////////////////////////////////////////////////////////////////
#endif    // not APSTUDIO_INVOKED
```

### 13.99 flutter_application_1/windows/runner/flutter_window.cpp

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

71 บรรทัด • SHA-256: dd185884c0b5301d

```text
#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
```

### 13.100 flutter_application_1/windows/runner/flutter_window.h

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

โครงสร้างที่ประกาศ: class FlutterWindow : public Win32Window (L12)

33 บรรทัด • SHA-256: 38e0fcd3a0b83895

```text
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
```

### 13.101 flutter_application_1/windows/runner/main.cpp

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

43 บรรทัด • SHA-256: add46983823ea1b1

```text
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"flutter_application_1", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
```

### 13.102 flutter_application_1/windows/runner/resource.h

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

16 บรรทัด • SHA-256: 1fa98588b0456159

```text
//{{NO_DEPENDENCIES}}
// Microsoft Visual C++ generated include file.
// Used by Runner.rc
//
#define IDI_APP_ICON                    101

// Next default values for new objects
//
#ifdef APSTUDIO_INVOKED
#ifndef APSTUDIO_READONLY_SYMBOLS
#define _APS_NEXT_RESOURCE_VALUE        102
#define _APS_NEXT_COMMAND_VALUE         40001
#define _APS_NEXT_CONTROL_VALUE         1001
#define _APS_NEXT_SYMED_VALUE           101
#endif
#endif
```

### 13.103 flutter_application_1/windows/runner/utils.cpp

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

65 บรรทัด • SHA-256: dc2ee94d43116f95

```text
#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}
```

### 13.104 flutter_application_1/windows/runner/utils.h

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

19 บรรทัด • SHA-256: 95a7f7dddb832997

```text
#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty std::string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty std::vector<std::string> on failure.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
```

### 13.105 flutter_application_1/windows/runner/win32_window.cpp

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

โครงสร้างที่ประกาศ: class WindowClassRegistrar (L59)

288 บรรทัด • SHA-256: 9065f31ccf746cf8

```text
#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
```

### 13.106 flutter_application_1/windows/runner/win32_window.h

โค้ด host ฝั่ง Windows: จุดเริ่มโปรแกรม หน้าต่าง Win32 หรือ helper สำหรับ Flutter engine ตามชื่อคลาส/ฟังก์ชันในโค้ด; Firebase options ปัจจุบันยังไม่รองรับ Windows

โครงสร้างที่ประกาศ: class Win32Window (L13)

102 บรรทัด • SHA-256: 7dd03746b19dcf35

```text
#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
```

### 13.107 functions/index.js

Cloud Function scanReceipt แบบเดิม ตรวจผู้ใช้ Base64 และขนาด เรียก Cloud Vision แล้วคืน text หรือ HttpsError; ไม่ใช่เส้นทาง OCR ที่ ReceiptService ปัจจุบันเรียก

27 บรรทัด • SHA-256: bc5465d10a9090d7

```javascript
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {ImageAnnotatorClient} = require('@google-cloud/vision');
const vision = new ImageAnnotatorClient();

exports.scanReceipt = onCall({region: 'asia-southeast1', timeoutSeconds: 60,
  memory: '512MiB', maxInstances: 3}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const content = request.data?.image;
  if (typeof content !== 'string' || content.length > 7 * 1024 * 1024 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(content)) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  const bytes = Buffer.from(content, 'base64');
  if (!bytes.length || bytes.length > 5 * 1024 * 1024) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  try {
    const [result] = await vision.documentTextDetection({
      image: {content: bytes}, imageContext: {languageHints: ['th', 'en']},
    }, {timeout: 45000});
    if (result.error?.message) throw new Error('OCR failed');
    return {text: result.fullTextAnnotation?.text || ''};
  } catch (_) {
    // Do not log receipt contents or return internal service details.
    throw new HttpsError('unavailable', 'Receipt scanning is unavailable. Try again later.');
  }
});
```

### 13.108 public/password_policy.js

ตัวตรวจ policy สำหรับเว็บที่สร้างจาก JSON เดียวกับ Dart ติดตั้ง BudgetmatePasswordPolicy บน window หรือ globalThis เพื่อใช้ทั้ง browser และ tests

17 บรรทัด • SHA-256: 00a5c91ab02a871c

```javascript
// Generated by scripts/generate_password_policy.py. Edit config/password_policy.json.
(function (root) {
  const blocked = new Set(["123456789012345", "1234567890123456", "12345678901234567890", "passwordpassword", "password123456789", "password12345678", "qwertyuiopasdfgh", "qwertyuiopasdfghjkl", "qwerty1234567890", "aaaaaaaaaaaaaaa", "111111111111111", "000000000000000", "budgetmate123456", "budgetmatepassword", "budgetmatebudgetmate"]);
  root.BudgetmatePasswordPolicy = Object.freeze({
    minLength: 6, maxLength: 128,
    validate(password) {
      if ([...password].length < 6) return 'password_min_length';
      if (password.length > 128) return 'password_max_length';
      if (!password.trim() || blocked.has(password.toLowerCase())) return 'password_common';
      if (!new RegExp("[a-z]").test(password)) return 'password_lowercase';
      if (!new RegExp("[A-Z]").test(password)) return 'password_uppercase';
      if (!new RegExp("[0-9]").test(password)) return 'password_digit';
      if (!new RegExp("[\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E]").test(password)) return 'password_symbol';
      return null;
    }
  });
})(typeof window !== 'undefined' ? window : globalThis);
```

### 13.109 public/reset_password.html

โค้ด HTML/CSS ของหน้าเว็บตาม path: โครง DOM รูปแบบข้อความ ปุ่ม และส่วนเชื่อมสคริปต์; public/reset_password.html ใช้ร่วมกับ reset_password.js ส่วน web/index.html เป็นจุดโหลด Flutter web

114 บรรทัด • SHA-256: fb7f8595afea3352

```text
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<title>BUDGETMATE · รีเซ็ตรหัสผ่าน</title>
<meta name="referrer" content="no-referrer" />
<link rel="stylesheet" href="reset_password.css" />
</head>
<body>

<main class="card">
  <header class="brand"><span class="brand-mark" aria-hidden="true">B</span><span>BUDGETMATE</span><span class="brand-spark" aria-hidden="true">✦</span></header>

  <!-- ===== STATE: loading (verifying oobCode) ===== -->
  <div id="state-loading" role="status" aria-live="polite">
    <div class="loading-wrap"><div class="ring"></div></div>
    <p class="status-text" data-i18n="verifying">กำลังตรวจสอบลิงก์...</p>
  </div>

  <!-- ===== STATE: invalid / expired link ===== -->
  <div id="state-invalid" class="hidden" role="status">
    <div class="center-icon error-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9"></circle>
        <line x1="9" y1="9" x2="15" y2="15"></line>
        <line x1="15" y1="9" x2="9" y2="15"></line>
      </svg>
    </div>
    <h1 id="invalid-title" data-i18n="invalidTitle">ลิงก์นี้ใช้ไม่ได้แล้ว</h1>
    <p class="subtitle" id="invalid-description" data-i18n="invalidDesc">ลิงก์รีเซ็ตรหัสผ่านนี้หมดอายุหรือถูกใช้ไปแล้ว กรุณากลับไปที่แอปแล้วขอลิงก์ใหม่อีกครั้ง</p>
    <button type="button" class="btn btn-secondary hidden" id="retry-btn" data-i18n="retry">ลองอีกครั้ง</button>
  </div>

  <!-- ===== STATE: form (enter new password) ===== -->
  <div id="state-form" class="hidden">
    <div class="badge">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="4" y="11" width="16" height="10" rx="2"></rect>
        <path d="M8 11V7a4 4 0 0 1 8 0v4"></path>
      </svg>
    </div>
    <h1 data-i18n="formTitle">ตั้งรหัสผ่านใหม่</h1>
    <p class="subtitle" id="form-subtitle">
      <span data-i18n="formDescPrefix">กำลังตั้งรหัสผ่านใหม่ให้บัญชี</span> <strong id="account-email"></strong>
    </p>

    <div id="form-error" class="banner error hidden" role="alert">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9"></circle><line x1="12" y1="8" x2="12" y2="13"></line><circle cx="12" cy="16.5" r="0.5" fill="currentColor"></circle>
      </svg>
      <span id="form-error-text"></span>
    </div>

    <form id="reset-form" novalidate>
      <div class="field">
        <label for="new-password" class="field-label" data-i18n="newPasswordLabel">รหัสผ่านใหม่</label>
        <div class="input-wrap" id="wrap-new">
          <svg class="lead" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="4" y="11" width="16" height="10" rx="2"></rect><path d="M8 11V7a4 4 0 0 1 8 0v4"></path>
          </svg>
          <input type="password" id="new-password" required minlength="6" aria-describedby="password-hint" autocomplete="new-password" autocapitalize="none" spellcheck="false" data-i18n-placeholder="newPasswordPh" placeholder="อย่างน้อย 6 ตัวอักษร" />
          <button type="button" class="eye-btn" data-target="new-password" aria-label="toggle password">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"></path><circle cx="12" cy="12" r="3"></circle>
            </svg>
          </button>
        </div>
      </div>

      <p class="password-hint" id="password-hint" data-i18n="passwordHint">ใช้ 6 ตัวอักษรขึ้นไป มี a–z, A–Z, ตัวเลข และสัญลักษณ์ อย่างน้อยประเภทละ 1 ตัว</p>
      <p class="hint" id="policy-status" aria-live="polite"></p>
      <div class="field">
        <label for="confirm-password" class="field-label" data-i18n="confirmPasswordLabel">ยืนยันรหัสผ่านใหม่</label>
        <div class="input-wrap" id="wrap-confirm">
          <svg class="lead" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="4" y="11" width="16" height="10" rx="2"></rect><path d="M8 11V7a4 4 0 0 1 8 0v4"></path>
          </svg>
          <input type="password" id="confirm-password" required aria-describedby="match-hint" autocomplete="new-password" autocapitalize="none" spellcheck="false" data-i18n-placeholder="confirmPasswordPh" placeholder="กรอกรหัสผ่านใหม่อีกครั้ง" />
          <button type="button" class="eye-btn" data-target="confirm-password" aria-label="toggle password">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"></path><circle cx="12" cy="12" r="3"></circle>
            </svg>
          </button>
        </div>
        <p class="hint" id="match-hint" aria-live="polite"></p>
      </div>

      <button type="submit" class="btn btn-primary" id="submit-btn">
        <span data-i18n="submitBtn">บันทึกรหัสผ่านใหม่</span>
      </button>
    </form>
  </div>

  <!-- ===== STATE: success ===== -->
  <div id="state-success" class="hidden" role="status">
    <div class="center-icon success-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
        <path class="check" d="M5 13l4 4L19 7"></path>
      </svg>
    </div>
    <h1 data-i18n="successTitle">ตั้งรหัสผ่านใหม่สำเร็จ</h1>
    <p class="subtitle" data-i18n="successDesc">กลับไปที่แอป BUDGETMATE แล้วเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้เลย</p>
  </div>

  <div class="security-label"><span aria-hidden="true">◇</span><span data-i18n="securityLabel">พื้นที่ส่วนตัวของคุณ</span></div>
  <p class="footer-note" data-i18n="footerNote">หากคุณไม่ได้เป็นผู้ขอรีเซ็ตรหัสผ่านนี้ สามารถปิดหน้านี้ได้เลย บัญชีของคุณยังปลอดภัย</p>
</main>

<script src="password_policy.js" defer></script>
<script src="reset_password.js" defer></script>
<noscript>กรุณาเปิด JavaScript เพื่อใช้หน้ารีเซ็ตรหัสผ่าน / Please enable JavaScript.</noscript>
</body>
</html>
```

### 13.110 public/reset_password.js

สคริปต์ควบคุมเว็บรีเซ็ต อ่านลิงก์ ตรวจ oobCode แสดงฟอร์ม ตรวจ policy/ยืนยัน ส่งรหัสใหม่ และจัดการ network/retry/สถานะปุ่ม

256 บรรทัด • SHA-256: 4e7514207963af4e

```javascript
(function () {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode');
  const oobCode = params.get('oobCode');
  const apiKey = params.get('apiKey');
  // Firebase shares this URL across email templates. Preserve its standard
  // handler for verification, recovery and other non-password-reset actions.
  if (mode && mode !== 'resetPassword') {
    const fallback = new URL('https://budgetmate-app-a94da.firebaseapp.com/__/auth/action');
    fallback.search = params.toString();
    window.location.replace(fallback.href);
    return;
  }

  let continueLang;
  try { continueLang = new URL(params.get('continueUrl')).searchParams.get('lang'); } catch (_) {}
  const lang = (continueLang || params.get('lang') || 'th').toLowerCase();

  const isEN = lang.startsWith('en');
  const dict = {
    th: {
      verifying: 'กำลังตรวจสอบลิงก์...',
      invalidTitle: 'ลิงก์นี้ใช้ไม่ได้แล้ว',
      invalidDesc: 'ลิงก์รีเซ็ตรหัสผ่านนี้หมดอายุหรือถูกใช้ไปแล้ว กรุณากลับไปที่แอปแล้วขอลิงก์ใหม่อีกครั้ง',
      formTitle: 'ตั้งรหัสผ่านใหม่',
      formDescPrefix: 'กำลังตั้งรหัสผ่านใหม่ให้บัญชี',
      newPasswordLabel: 'รหัสผ่านใหม่',
      newPasswordPh: 'อย่างน้อย 6 ตัวอักษร',
      confirmPasswordLabel: 'ยืนยันรหัสผ่านใหม่',
      confirmPasswordPh: 'กรอกรหัสผ่านใหม่อีกครั้ง',
      submitBtn: 'บันทึกรหัสผ่านใหม่',
      submitBtnLoading: 'กำลังบันทึก...',
      successTitle: 'ตั้งรหัสผ่านใหม่สำเร็จ',
      successDesc: 'กลับไปที่แอป BUDGETMATE แล้วเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้เลย',
      footerNote: 'หากคุณไม่ได้เป็นผู้ขอรีเซ็ตรหัสผ่านนี้ สามารถปิดหน้านี้ได้เลย บัญชีของคุณยังปลอดภัย',
      errTooShort: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
      errMismatch: 'รหัสผ่านไม่ตรงกัน',
      errTooLong: 'รหัสผ่านยาวเกิน 128 ตัวอักษร',
      errCommon: 'รหัสผ่านนี้เดาง่าย กรุณาเลือกวลีอื่น',
      errConfirm: 'กรุณากรอกยืนยันรหัสผ่าน',
      policyValid: 'รหัสผ่านผ่านเงื่อนไขแล้ว',
      errGeneric: 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
      errBadLink: 'ลิงก์นี้ไม่ถูกต้องหรือหมดอายุแล้ว',
    },
    en: {
      verifying: 'Verifying your link...',
      invalidTitle: 'This link is no longer valid',
      invalidDesc: 'This password reset link has expired or already been used. Go back to the app and request a new one.',
      formTitle: 'Set a new password',
      formDescPrefix: 'Setting a new password for',
      newPasswordLabel: 'New password',
      newPasswordPh: 'At least 6 characters',
      confirmPasswordLabel: 'Confirm new password',
      confirmPasswordPh: 'Re-enter your new password',
      submitBtn: 'Save new password',
      submitBtnLoading: 'Saving...',
      successTitle: 'Password reset successful',
      successDesc: 'Go back to BUDGETMATE and log in with your new password.',
      footerNote: "If you didn't request this, you can safely close this page. Your account is still secure.",
      errTooShort: 'Password must be at least 6 characters',
      errMismatch: 'Passwords do not match',
      errTooLong: 'Password exceeds the 128-character limit',
      errCommon: 'This password is too common. Choose another passphrase.',
      errConfirm: 'Please confirm your password',
      policyValid: 'Password meets the requirements',
      errGeneric: 'Something went wrong. Please try again.',
      errBadLink: 'This link is invalid or has expired.',
    },
  };
  Object.assign(dict.th, {
    passwordHint: 'ใช้ 6 ตัวอักษรขึ้นไป มี a–z, A–Z, ตัวเลข และสัญลักษณ์ อย่างน้อยประเภทละ 1 ตัว',
    networkTitle: 'ยังเชื่อมต่อไม่ได้', securityLabel: 'พื้นที่ส่วนตัวของคุณ', retry: 'ลองอีกครั้ง',
    errNetwork: 'ยังเชื่อมต่อไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
    errPolicy: 'รหัสผ่านยังไม่ตรงตามเงื่อนไขของบัญชี กรุณาเลือกวลีอื่นที่ยาวอย่างน้อย 6 ตัวอักษร',
    showPassword: 'แสดงรหัสผ่าน', hidePassword: 'ซ่อนรหัสผ่าน',
    passwordMatch: 'รหัสผ่านตรงกันแล้ว',
  });
  Object.assign(dict.en, {
    passwordHint: 'Use at least 6 characters with at least 1 lowercase letter, uppercase letter, number and symbol.',
    networkTitle: 'Unable to connect', securityLabel: 'Your personal space', retry: 'Try again',
    errNetwork: 'Unable to connect. Check your internet connection and try again.',
    errPolicy: 'This password does not meet your account policy. Choose a different passphrase of at least 6 characters.',
    showPassword: 'Show password', hidePassword: 'Hide password',
    passwordMatch: 'Passwords match',
  });
  const T = isEN ? dict.en : dict.th;
  document.title = 'BUDGETMATE · ' + T.formTitle;
  if (isEN) document.documentElement.lang = 'en';

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    if (T[key]) el.textContent = T[key];
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
    const key = el.getAttribute('data-i18n-placeholder');
    if (T[key]) el.placeholder = T[key];
  });

  const show = (id) => {
    ['state-loading', 'state-invalid', 'state-form', 'state-success'].forEach((s) => {
      document.getElementById(s).classList.toggle('hidden', s !== id);
    });
  };

  function apiUrl(path) {
    return 'https://identitytoolkit.googleapis.com/v1/accounts:' + path + '?key=' + encodeURIComponent(apiKey);
  }

  if (mode !== 'resetPassword' || !oobCode || !apiKey) {
    show('state-invalid');
    return;
  }

  async function requestReset(body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const res = await fetch(apiUrl('resetPassword'), {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body), signal: controller.signal,
      });
      const data = await res.json();
      return {ok: res.ok, data};
    } finally { clearTimeout(timeout); }
  }

  const retryBtn = document.getElementById('retry-btn');
  const invalidDescription = document.getElementById('invalid-description');
  function invalidLink(retryable) {
    document.getElementById('invalid-title').textContent = retryable ? T.networkTitle : T.invalidTitle;
    invalidDescription.textContent = retryable ? T.errNetwork : T.invalidDesc;
    retryBtn.classList.toggle('hidden', !retryable);
    show('state-invalid');
  }
  async function verify() {
    show('state-loading');
    try {
      const {ok, data} = await requestReset({oobCode});
      if (!ok || !data.email) {
        const code = data.error?.message || '';
        invalidLink(!/EXPIRED_OOB_CODE|INVALID_OOB_CODE|USER_DISABLED|USER_NOT_FOUND/.test(code));
        return;
      }
      document.getElementById('account-email').textContent = data.email;
      show('state-form');
    } catch (_) { invalidLink(true); }
  }
  retryBtn.addEventListener('click', verify);
  verify();

  // ---- ฟอร์มตั้งรหัสผ่านใหม่ ----
  const form = document.getElementById('reset-form');
  const newPw = document.getElementById('new-password');
  const confirmPw = document.getElementById('confirm-password');
  const wrapNew = document.getElementById('wrap-new');
  const wrapConfirm = document.getElementById('wrap-confirm');
  const matchHint = document.getElementById('match-hint');
  const submitBtn = document.getElementById('submit-btn');
  const errorBanner = document.getElementById('form-error');
  const errorText = document.getElementById('form-error-text');

  document.querySelectorAll('.eye-btn').forEach((btn) => {
    btn.setAttribute('aria-label', T.showPassword);
    btn.setAttribute('aria-pressed', 'false');
    btn.addEventListener('click', () => {
      const input = document.getElementById(btn.getAttribute('data-target'));
      input.type = input.type === 'password' ? 'text' : 'password';
      btn.setAttribute('aria-label', input.type === 'text' ? T.hidePassword : T.showPassword);
      btn.setAttribute('aria-pressed', String(input.type === 'text'));
    });
  });

  function clearError() {
    errorBanner.classList.add('hidden');
    wrapNew.classList.remove('has-error');
    wrapConfirm.classList.remove('has-error');
    matchHint.textContent = '';
  }

  function showError(msg) {
    errorText.textContent = msg;
    errorBanner.classList.remove('hidden');
  }

  const policyMessages = {
    password_lowercase: isEN ? 'At least 1 lowercase letter (a–z)' : 'ตัวพิมพ์เล็ก a–z อย่างน้อย 1 ตัว',
    password_uppercase: isEN ? 'At least 1 uppercase letter (A–Z)' : 'ตัวพิมพ์ใหญ่ A–Z อย่างน้อย 1 ตัว',
    password_digit: isEN ? 'At least 1 number (0–9)' : 'ตัวเลข 0–9 อย่างน้อย 1 ตัว',
    password_symbol: isEN ? 'At least 1 symbol, such as ! @ #' : 'สัญลักษณ์ เช่น ! @ # อย่างน้อย 1 ตัว',
 password_min_length: T.errTooShort, password_max_length: T.errTooLong, password_common: T.errCommon };
  function passwordError(value) {
    const key = window.BudgetmatePasswordPolicy.validate(value);
    return key ? policyMessages[key] : null;
  }
  [newPw, confirmPw].forEach(input => input.addEventListener('input', () => {
    clearError();
    document.getElementById('policy-status').textContent = newPw.value ? (passwordError(newPw.value) || T.policyValid) : '';
    if (confirmPw.value && newPw.value === confirmPw.value) matchHint.textContent = T.passwordMatch;
  }));
  let saving = false;
  form.addEventListener('submit', async function (e) {
    e.preventDefault();
    if (saving) return;
    clearError();

    const pw1 = newPw.value;
    const pw2 = confirmPw.value;

    const invalid = passwordError(pw1);
    if (invalid) {
      wrapNew.classList.add('has-error');
      showError(invalid);
      newPw.focus();
      return;
    }
    if (!pw2) {
      wrapConfirm.classList.add('has-error');
      showError(T.errConfirm);
      confirmPw.focus();
      return;
    }
    if (pw1 !== pw2) {
      wrapConfirm.classList.add('has-error');
      showError(T.errMismatch);
      confirmPw.focus();
      return;
    }

    saving = true;
    submitBtn.disabled = true;
    newPw.disabled = confirmPw.disabled = true;
    submitBtn.textContent = T.submitBtnLoading;
    form.setAttribute('aria-busy', 'true');
    try {
      const {ok, data} = await requestReset({oobCode, newPassword: pw1});
      if (!ok) {
        const code = data.error?.message || '';
        if (/EXPIRED_OOB_CODE|INVALID_OOB_CODE/.test(code)) {
          invalidLink(false);
          return;
        }
        showError(/WEAK_PASSWORD|PASSWORD_DOES_NOT_MEET_REQUIREMENTS/.test(code) ? T.errPolicy : T.errGeneric);
        return;
      }
      newPw.value = confirmPw.value = '';
      show('state-success');
    } catch (_) { showError(T.errNetwork); }
    finally {
      saving = false;
      submitBtn.disabled = false;
      newPw.disabled = confirmPw.disabled = false;
      submitBtn.textContent = T.submitBtn;
      form.setAttribute('aria-busy', 'false');
    }
  });
})();
```

### 13.111 scripts/generate_password_policy.py

อ่าน config/password_policy.json แล้วเขียนตัวตรวจสองภาษา Dart/JavaScript ให้ใช้ความยาว regex และ blocklist เดียวกัน

42 บรรทัด • SHA-256: 6334ca9fdb468654

```python
"""Generate matching Dart/web validation from one versioned policy. No secrets."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = json.loads((root / 'config/password_policy.json').read_text())
dart_rules = '\n'.join("  if (!RegExp(" + json.dumps(pattern) + ").hasMatch(password)) return 'password_" + key + "';" for key, pattern in p['requiredPatterns'].items())
js_rules = '\n'.join("      if (!new RegExp(" + json.dumps(pattern) + ").test(password)) return 'password_" + key + "';" for key, pattern in p['requiredPatterns'].items())
blocked = ',\n  '.join(json.dumps(v) for v in p['blockedPasswords'])
(root / 'flutter_application_1/lib/services/password_policy.dart').write_text(f'''// Generated by scripts/generate_password_policy.py. Edit config/password_policy.json.
const passwordMinLength = {p['minCodePoints']};
const passwordMaxLength = {p['maxUtf16Units']};
const _blockedPasswords = <String>{{
  {blocked}
}};

/// New passwords only. Never trim, truncate or rewrite a user's secret.
/// Minimum counts Unicode code points; maximum uses Firebase-compatible UTF-16 units.
String? passwordValidationKey(String password) {{
  if (password.runes.length < passwordMinLength) return 'password_min_length';
  if (password.length > passwordMaxLength) return 'password_max_length';
  if (password.trim().isEmpty || _blockedPasswords.contains(password.toLowerCase())) {{
    return 'password_common';
  }}
{dart_rules}
  return null;
}}
''')
(root / 'public/password_policy.js').write_text(f'''// Generated by scripts/generate_password_policy.py. Edit config/password_policy.json.
(function (root) {{
  const blocked = new Set({json.dumps(p['blockedPasswords'])});
  root.BudgetmatePasswordPolicy = Object.freeze({{
    minLength: {p['minCodePoints']}, maxLength: {p['maxUtf16Units']},
    validate(password) {{
      if ([...password].length < {p['minCodePoints']}) return 'password_min_length';
      if (password.length > {p['maxUtf16Units']}) return 'password_max_length';
      if (!password.trim() || blocked.has(password.toLowerCase())) return 'password_common';
{js_rules}
      return null;
    }}
  }});
}})(typeof window !== 'undefined' ? window : globalThis);
''')
```

### 13.112 storage.rules

กฎ Firebase Security Rules ตรวจสิทธิ์ตาม uid เจ้าของและเงื่อนไขข้อมูล; อ่านบท 11 ประกอบ ไม่ยืนยันว่าไฟล์นี้ถูก deploy แล้ว

12 บรรทัด • SHA-256: 5faf8bf108a88c91

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /receipts/{userId}/{receiptId} {
      allow read, delete: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
    match /{allPaths=**} { allow read, write: if false; }
  }
}
```

### 13.113 tests/reset_password.test.cjs

ชุดทดสอบ: เว็บลิงก์รีเซ็ต เครือข่าย retry การยืนยันรหัสและการส่งเพียงครั้งเดียว รายชื่อกรณีด้านล่างดึงจาก test declarations; การมีกรณีทดสอบไม่ได้หมายความว่ารอบนี้ได้รันผ่านแล้ว

| ตัวอย่างกรณีที่ประกาศในไฟล์ |
| --- |
| missing reset code shows invalid state without requests |
| verified account opens form and mismatched passwords never submit |
| successful reset submits once and clears both password fields |
| network verification failure offers retry, then opens form |
| expired link does not offer network retry |
| backend password policy error retains fields and enables retry |
| other email actions retain the trusted Firebase default handler |
| numeric-only passwords never submit a reset request |
| valid password preserves leading and trailing spaces |
| unicode code points and maximum length are validated without requests |
| empty confirmation produces a specific message |
| missing character classes never submit a reset request |
| six-character mixed password is accepted, five characters are rejected |

110 บรรทัด • SHA-256: 233a83a9a71445e6

```text
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const script = readFileSync('public/password_policy.js', 'utf8') + '\n' + readFileSync('public/reset_password.js', 'utf8');
function setup(replies, search = '?mode=resetPassword&oobCode=test-code&apiKey=test-key&lang=th') {
  const nodes = new Map();
  function element(id) {
    if (nodes.has(id)) return nodes.get(id);
    const classes = new Set(id.startsWith('state-') && id !== 'state-loading' ? ['hidden'] : []);
    const el = {value:'', textContent:'', type:'password', disabled:false, attrs:{}, handlers:{},
      classList:{add:c=>classes.add(c),remove:c=>classes.delete(c),contains:c=>classes.has(c),toggle(c,on){on ? classes.add(c) : classes.delete(c);}},
      addEventListener(name, fn){this.handlers[name]=fn;},setAttribute(k,v){this.attrs[k]=v;},getAttribute(k){return this.attrs[k];},focus(){this.focused=true;}};
    nodes.set(id,el);return el;
  }
  const calls=[];
  let redirected;
  vm.runInNewContext(script, {URL,URLSearchParams,AbortController,setTimeout,clearTimeout,
    window:{location:{search,replace:url=>{redirected=url;}}},document:{documentElement:{lang:'th'},getElementById:element,querySelectorAll:()=>[]},
    fetch:async (url,options)=>{calls.push({url,body:JSON.parse(options.body)});const next=replies.shift();if(next instanceof Error)throw next;return {ok:next.ok ?? true,json:async()=>next.data ?? next};}});
  return {element,calls,get redirected(){return redirected;},flush:()=>new Promise(resolve=>setImmediate(resolve)),
    submit:()=>element('reset-form').handlers.submit({preventDefault(){}})};
}
test('missing reset code shows invalid state without requests',()=>{
  const s=setup([], '');assert.equal(s.element('state-invalid').classList.contains('hidden'),false);assert.equal(s.calls.length,0);
});
test('verified account opens form and mismatched passwords never submit',async()=>{
  const s=setup([{email:'sample@example.com'}]);await s.flush();
  assert.equal(s.element('state-form').classList.contains('hidden'),false);
  s.element('new-password').value='Violet-river-cloud-29';s.element('confirm-password').value='different-123';await s.submit();
  assert.equal(s.calls.length,1);assert.equal(s.element('confirm-password').focused,true);
});
test('successful reset submits once and clears both password fields',async()=>{
  const s=setup([{email:'sample@example.com'},{email:'sample@example.com'}]);await s.flush();
  s.element('new-password').value=s.element('confirm-password').value='Violet-river-cloud-29';
  const first=s.submit();await s.submit();await first;
  assert.equal(s.calls.length,2);assert.deepEqual(s.calls[1].body,{oobCode:'test-code',newPassword:'Violet-river-cloud-29'});
  assert.equal(s.element('state-success').classList.contains('hidden'),false);
  assert.equal(s.element('new-password').value,'');assert.equal(s.element('confirm-password').value,'');
});
test('network verification failure offers retry, then opens form',async()=>{
  const s=setup([new Error('offline'),{email:'sample@example.com'}]);await s.flush();
  assert.equal(s.element('retry-btn').classList.contains('hidden'),false);
  await s.element('retry-btn').handlers.click();assert.equal(s.element('state-form').classList.contains('hidden'),false);
});
test('expired link does not offer network retry',async()=>{
  const s=setup([{ok:false,data:{error:{message:'EXPIRED_OOB_CODE'}}}]);await s.flush();
  assert.equal(s.element('state-invalid').classList.contains('hidden'),false);assert.equal(s.element('retry-btn').classList.contains('hidden'),true);
});
test('backend password policy error retains fields and enables retry',async()=>{
  const s=setup([{email:'sample@example.com'},{ok:false,data:{error:{message:'PASSWORD_DOES_NOT_MEET_REQUIREMENTS'}}}]);await s.flush();
  s.element('new-password').value=s.element('confirm-password').value='Violet-river-cloud-29';await s.submit();
  assert.equal(s.element('submit-btn').disabled,false);assert.equal(s.element('new-password').value,'Violet-river-cloud-29');assert.match(s.element('form-error-text').textContent,/เงื่อนไข/);
});

test('other email actions retain the trusted Firebase default handler',()=>{
  const s=setup([], '?mode=verifyEmail&oobCode=test-code&apiKey=test-key');
  const target=new URL(s.redirected);
  assert.equal(target.origin,'https://budgetmate-app-a94da.firebaseapp.com');
  assert.equal(target.pathname,'/__/auth/action');
  assert.equal(target.searchParams.get('mode'),'verifyEmail');
  assert.equal(target.searchParams.get('oobCode'),'test-code');
  assert.equal(s.calls.length,0);
});

test('numeric-only passwords never submit a reset request', async () => {
  const s = setup([{email:'sample@example.com'}]); await s.flush();
  s.element('new-password').value = s.element('confirm-password').value = '123456789012345';
  await s.submit();
  assert.equal(s.calls.length, 1);
  assert.match(s.element('form-error-text').textContent, /เดาง่าย/);
});

test('valid password preserves leading and trailing spaces', async () => {
  const s = setup([{email:'sample@example.com'}, {}]); await s.flush();
  s.element('new-password').value = s.element('confirm-password').value = '  Violet river cloud 29!  ';
  await s.submit();
  assert.equal(s.calls[1].body.newPassword, '  Violet river cloud 29!  ');
});
test('unicode code points and maximum length are validated without requests', async () => {
  for (const password of ['🌻'.repeat(14), 'x'.repeat(129)]) {
    const s = setup([{email:'sample@example.com'}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit(); assert.equal(s.calls.length, 1);
  }
});
test('empty confirmation produces a specific message', async () => {
  const s = setup([{email:'sample@example.com'}]); await s.flush();
  s.element('new-password').value = 'Violet river cloud 29!'; await s.submit();
  assert.equal(s.calls.length, 1);
  assert.match(s.element('form-error-text').textContent, /กรุณากรอกยืนยัน/);
});

test('missing character classes never submit a reset request', async () => {
  for (const password of ['VIOLET RIVER 29!', 'violet river 29!', 'Violet river abc!', 'Violet river 290']) {
    const s = setup([{email:'user@example.com'}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit();
    assert.equal(s.calls.length, 1);
  }
});

test('six-character mixed password is accepted, five characters are rejected', async () => {
  for (const [password, expectedCalls] of [['Aa1!x', 1], ['Aa1!xy', 2]]) {
    const s = setup([{email: 'user@example.com'}, {}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit();
    assert.equal(s.calls.length, expectedCalls);
  }
});
```

## 14. ไฟล์ตั้งค่า เว็บไซต์ assets และเอกสารประกอบ

| ไฟล์ | หน้าที่ |
| --- | --- |
| .firebaserc | Firebase project alias สำหรับเครื่องมือ deploy |
| .gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| README.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| config/password_policy.json | ต้นฉบับกฎรหัสผ่านที่ generator ใช้สร้าง Dart และ JavaScript |
| docs/app-flowchart.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| docs/app-flowchart.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| docs/income-expense-presentation.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| docs/user-manual-appendix.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| firestore.indexes.json | ดัชนีสำหรับกรอง transactions ตามผู้ใช้และเรียงวันที่ |
| flutter_application_1/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/.metadata | ไฟล์ประกอบการตั้งค่าหรือทรัพยากรของโปรเจกต์ตาม path ไม่อยู่ในกลุ่มโค้ดธุรกิจ Dart |
| flutter_application_1/FUNCTION_CHECK.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/OFFLINE_RECEIPTS.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/analysis_options.yaml | ตั้งค่าการวิเคราะห์และ lint ของ Dart |
| flutter_application_1/android/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/android/app/src/debug/AndroidManifest.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/app/src/main/res/drawable-v21/launch_background.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/app/src/main/res/drawable/launch_background.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/app/src/main/res/mipmap-hdpi/ic_launcher.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/android/app/src/main/res/mipmap-mdpi/ic_launcher.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/android/app/src/main/res/values-night/styles.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/app/src/main/res/values/styles.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/app/src/profile/AndroidManifest.xml | Android manifest หรือ resource สำหรับสิทธิ์และหน้าตา native |
| flutter_application_1/android/gradle.properties | ตั้งค่าการ build Android, plugins, SDK, Java/Kotlin หรือ Gradle wrapper |
| flutter_application_1/android/gradle/wrapper/gradle-wrapper.properties | ตั้งค่าการ build Android, plugins, SDK, Java/Kotlin หรือ Gradle wrapper |
| flutter_application_1/assets/fonts/Mali-Bold.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/fonts/Mali-ExtraLight.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/fonts/Mali-Light.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/fonts/Mali-Medium.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/fonts/Mali-Regular.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/fonts/Mali-SemiBold.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| flutter_application_1/assets/icon/budgetmate_icon.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/ChatGPT Image 31 ส.ค. 2569 23_59_21.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/beauty_lipstick_pastel.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c01.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c02.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c03.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c04.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c05.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c06.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c07.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c08.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c09.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c10.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c11.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c12.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c13.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c14.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c15.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c16.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c17.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c18.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c19.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c20.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c21.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c22.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c23.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c24.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c25.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c26.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c27.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c28.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c29.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c30.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c31.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c32.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c33.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c34.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c35.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c36.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c37.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c38.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c39.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c40.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c41.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c42.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c43.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c44.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c45.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c46.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c47.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c48.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c49.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c50.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c51.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c52.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c53.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c54.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/c55.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_atlas.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_atlas_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_00.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_00_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_01.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_01_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_02.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_02_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_03.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_03_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_04.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_04_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_05.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_05_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_06.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_06_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_07.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_07_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_08.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_08_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_09.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_09_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_10.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_10_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_11.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_collection_11_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_extra_atlas.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/pastel_extra_atlas_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/categories/peach_transparent.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/google_logo.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/images/loading.gif | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/assets/tessdata/LICENSE | ไฟล์ประกอบการตั้งค่าหรือทรัพยากรของโปรเจกต์ตาม path ไม่อยู่ในกลุ่มโค้ดธุรกิจ Dart |
| flutter_application_1/assets/tessdata/README.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/assets/tessdata/eng.traineddata | โมเดลภาษา OCR ที่ Tesseract โหลดจาก assets |
| flutter_application_1/assets/tessdata/tha.traineddata | โมเดลภาษา OCR ที่ Tesseract โหลดจาก assets |
| flutter_application_1/assets/tessdata_config.json | กำหนดไฟล์โมเดลภาษาให้ plugin OCR |
| flutter_application_1/design/app_icon_prompt.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/beauty_lipstick_prompt.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/pastel_artwork_prompt.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/pastel_collection_prompts.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/responsive_layout_review.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/test_case_fixes.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/design/transparent_category_artwork.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/ios/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/ios/Flutter/AppFrameworkInfo.plist | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/ios/Flutter/Debug.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/ios/Flutter/Release.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/ios/Podfile | กำหนดการรวม dependencies native ผ่าน CocoaPods |
| flutter_application_1/ios/Podfile.lock | ตรึงรุ่น dependencies ที่ resolve แล้ว ไม่ใช่โค้ดธุรกิจ |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json | metadata รายการรูปและขนาดใน Apple asset catalog |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json | metadata รายการรูปและขนาดใน Apple asset catalog |
| flutter_application_1/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| flutter_application_1/ios/Runner/Base.lproj/LaunchScreen.storyboard | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/ios/Runner/Base.lproj/Main.storyboard | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/ios/Runner/GoogleService-Info.plist | ค่าระบุแอป Firebase ฝั่ง Apple ไม่ใช่ตัวจัดการบัญชีหรือฐานข้อมูล |
| flutter_application_1/ios/Runner/Info.plist | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/linux/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/linux/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/linux/flutter/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/linux/runner/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/macos/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/macos/Flutter/Flutter-Debug.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Flutter/Flutter-Release.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Podfile | กำหนดการรวม dependencies native ผ่าน CocoaPods |
| flutter_application_1/macos/Runner.xcodeproj/project.pbxproj | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner.xcworkspace/contents.xcworkspacedata | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json | metadata รายการรูปและขนาดใน Apple asset catalog |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/macos/Runner/Base.lproj/MainMenu.xib | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Configs/AppInfo.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Configs/Debug.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Configs/Release.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Configs/Warnings.xcconfig | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/DebugProfile.entitlements | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/GoogleService-Info.plist | ค่าระบุแอป Firebase ฝั่ง Apple ไม่ใช่ตัวจัดการบัญชีหรือฐานข้อมูล |
| flutter_application_1/macos/Runner/Info.plist | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/macos/Runner/Release.entitlements | ตั้งค่า Apple build, สิทธิ์, workspace หรือหน้าต่าง/launch screen ตามชนิดไฟล์ |
| flutter_application_1/pubspec.lock | ตรึงรุ่น dependencies ที่ resolve แล้ว ไม่ใช่โค้ดธุรกิจ |
| flutter_application_1/pubspec.yaml | ชื่อแอป SDK constraint dependencies assets และฟอนต์ |
| flutter_application_1/web/favicon.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/web/icons/Icon-192.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/web/icons/Icon-512.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/web/icons/Icon-maskable-192.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/web/icons/Icon-maskable-512.png | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/web/manifest.json | ชื่อ ไอคอน และข้อมูลติดตั้ง Flutter web |
| flutter_application_1/windows/.gitignore | รายการไฟล์ที่ Git ไม่ติดตาม เช่น cache/build และค่าท้องถิ่น |
| flutter_application_1/windows/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/windows/flutter/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/windows/runner/CMakeLists.txt | ตั้งค่าการ compile/link Flutter host และ plugins บน desktop |
| flutter_application_1/windows/runner/resources/app_icon.ico | รูป/ไอคอน/ภาพเคลื่อนไหว ใช้แสดง UI หรือภาพเอกสาร ไม่ใช่ตรรกะโปรแกรม |
| flutter_application_1/windows/runner/runner.exe.manifest | ไฟล์ประกอบการตั้งค่าหรือทรัพยากรของโปรเจกต์ตาม path ไม่อยู่ในกลุ่มโค้ดธุรกิจ Dart |
| functions/README.md | เอกสารคู่มือ การออกแบบ หรือการตั้งค่า ควรเทียบกับ implementation ปัจจุบันเสมอ |
| functions/package-lock.json | ตรึงรุ่น dependencies ที่ resolve แล้ว ไม่ใช่โค้ดธุรกิจ |
| functions/package.json | entry point ของ backend, Node engine และ dependencies |
| public/fonts/Mali-Regular.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| public/fonts/Mali-SemiBold.ttf | ไฟล์ฟอนต์ Mali ประกาศน้ำหนักใน pubspec.yaml |
| public/reset_password.css | ไฟล์ประกอบการตั้งค่าหรือทรัพยากรของโปรเจกต์ตาม path ไม่อยู่ในกลุ่มโค้ดธุรกิจ Dart |

assets ภาพหมวดบางส่วนเป็น atlas หนึ่งภาพมีหลายช่อง PastelArtwork เลือกตำแหน่งตามหมายเลข artwork ดังนั้นการเปลี่ยนลำดับภาพต้องรักษา ID เดิม ฟอนต์ Mali อยู่ใน pubspec และโมเดล tha/eng ใช้กับ Tesseract ส่วนรูป platform เป็นไอคอนแอปและ launch screen

## 15. ขอบเขตทดสอบและข้อจำกัดที่พบจากโค้ด

data_service_test.dart ใช้ MemoryDB implements DBHelper เพื่อจำลองฐานข้อมูลและบังคับให้การเขียนล้มเหลวได้ จึงตรวจความสอดคล้องของ state โดยไม่ต้องแตะข้อมูลจริง แต่ไม่ได้แทนการทดสอบ Security Rules หรือ transaction พร้อมกันบน Firestore จริง

รอบจัดทำเอกสารนี้ตรวจความครบถ้วนของรายการไฟล์ ตรวจว่า code excerpts ตรงกับไฟล์จริง และตรวจโครงสร้างเอกสาร ไม่ได้รัน Flutter tests หรือทดสอบ Firebase จริง รายชื่อ test ในบท 13 บอกพฤติกรรมที่โค้ดทดสอบตั้งใจตรวจเท่านั้น

| ข้อสังเกต | ผลต่อการอ่าน/พัฒนาต่อ |
| --- | --- |
| มีข้อความเก่าเรื่อง SQLite และ Cloud OCR | อธิบายตาม implementation: Firestore + on-device OCR |
| สกุลเงินเป็นการกรอง ไม่ใช่ conversion | ห้ามรวมยอดต่างสกุลแล้วเรียกว่า balance เดียว |
| OCR ออฟไลน์ไม่ได้แปลว่าทั้งแอปออฟไลน์ | บัญชีและการบันทึกหลักยังเชื่อม Firebase |
| รูปใบเสร็จอยู่ในเครื่อง | marker ที่ซิงก์ไม่ได้ทำให้ภาพพร้อมใช้บนอีกเครื่อง |
| โอนเป้าหมายเป็นบันทึกบัญชี | ไม่มี API โอนเงินจริงกับธนาคาร |
| Firestore transaction ป้องกันสองเอกสารไม่ตรงกัน | แต่เงื่อนไข balance อ่านจาก client state จึงไม่ใช่การรับประกันยอดรวมข้ามอุปกรณ์ทุกกรณี |
| deleteTransaction ไม่เรียก LocalReceiptStore.delete | ภาพของรายการที่ลบอาจยังเหลือในเครื่อง; cleanup ในหน้าสแกนครอบคลุมเฉพาะบันทึกล้มเหลว |
| มี platform folders หลายระบบ | Firebase options และ OCR จำกัด platform ตามที่ระบุจริง |
| Android release ใช้ debug signing ใน build.gradle.kts | ยังไม่ใช่การตั้ง signing สำหรับแจก production ที่เสร็จสมบูรณ์ |
| ข้อมูลเงินใช้ double | ผลรวมทศนิยมใช้ floating point; formatMoney จัดแสดงสองตำแหน่ง ไม่ได้เปลี่ยนชนิดจัดเก็บเป็นหน่วยย่อยจำนวนเต็ม |

ไฟล์ที่ Git ติดตามแต่ขาดจาก working tree ณ เวลาสร้างเอกสาร (เอกสารไม่ได้กู้คืนหรือเปลี่ยนไฟล์เหล่านี้):

| ไฟล์ที่ขาด |
| --- |
| RESET_PASSWORD_SETUP.md |
| firebase.json |
| flutter_application_1/README.md |
| flutter_application_1/android/app/google-services.json |
| flutter_application_1/android/app/src/main/AndroidManifest.xml |
| flutter_application_1/firebase.json |
| flutter_application_1/ios/Runner.xcodeproj/project.pbxproj |
| flutter_application_1/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata |
| flutter_application_1/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist |
| flutter_application_1/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings |
| flutter_application_1/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved |
| flutter_application_1/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme |
| flutter_application_1/ios/Runner.xcworkspace/contents.xcworkspacedata |
| flutter_application_1/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist |
| flutter_application_1/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings |
| flutter_application_1/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved |
| flutter_application_1/ios/Runner/AppDelegate.swift |
| flutter_application_1/lib/services/exchange_rate_service.dart |

ผลที่ต้องระวังโดยตรง: AndroidManifest.xml และ google-services.json ของ Android หาย รวมทั้งส่วนโครง Xcode/ AppDelegate ของ iOS และ firebase.json จึงไม่สรุปว่าเปิด ZIP แล้ว build/deploy ได้ทันที โค้ด exchange_rate_service.dart ก็ไม่อยู่แล้ว ซึ่งสอดคล้องกับการไม่มีขั้นตอนแปลงสกุลเงินใน DataService ปัจจุบัน

## 16. วิธีใช้เอกสารและตรวจโค้ดต่อ

เปิด BudgetMate-source-guide.html ด้วยเบราว์เซอร์เพื่ออ่านแบบมีสารบัญและโค้ดพับได้ ใช้ช่องค้นหาเพื่อค้นชื่อไฟล์ คำอธิบาย หรือข้อความในโค้ด; ปุ่มเปิดโค้ดทั้งหมดช่วยให้ใช้ Find ของเบราว์เซอร์ได้ทั่วทั้งเอกสาร ไฟล์ Markdown เหมาะสำหรับเปิดใน VS Code และแก้ไขรายงาน ส่วน source-manifest.json บันทึก path จำนวนบรรทัด และ hash ไว้ตรวจ snapshot

ถ้าจะตรวจพฤติกรรมภายหลัง หลังแก้ไฟล์ตั้งค่าที่ขาดและเตรียม dependencies แล้ว ใช้ flutter test จากโฟลเดอร์ flutter_application_1 และ node --test tests/reset_password.test.cjs จากรากโปรเจกต์ ส่วน OCR native ต้องทดสอบกับเครื่องหรือ emulator ที่รองรับต่างหาก เอกสารนี้ไม่ได้เรียกคำสั่ง deploy และไม่ได้เปลี่ยนซอร์สแอป

ขอบเขต snapshot: ไฟล์โปรแกรมพร้อมคำอธิบายและโค้ดเต็ม 113 ไฟล์ รวม 19,427 บรรทัด; ไฟล์ตั้งค่า/ทรัพยากร/เอกสารอีก 216 ไฟล์ ไม่รวม dependencies ที่ดาวน์โหลด build cache ประวัติ .git และแพ็กเกจแอปที่ compile แล้ว
