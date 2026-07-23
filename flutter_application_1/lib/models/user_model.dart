/// เอนทิตี้ User ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class UserModel {
  final String id; // user_id
  String name; // name
  String email; // email
  String password; // password (เก็บเป็นค่า SHA-256 hash ไม่เก็บ plain text)
  final DateTime createdAt; // created_at
  String language; // ตั้งค่าในหน้า Information / Account Setting
  String currency;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
    this.language = 'ไทย',
    this.currency = 'THB',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'created_at': createdAt.toIso8601String(),
      'language': language,
      'currency': currency,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      language: map['language'] as String? ?? 'ไทย',
      currency: map['currency'] as String? ?? 'THB',
    );
  }
}
