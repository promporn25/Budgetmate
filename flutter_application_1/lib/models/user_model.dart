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