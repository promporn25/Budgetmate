/// เอนทิตี้ User ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class UserModel {
  final String id; // user_id
  String name; // name
  String email; // email
  String password; // password
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
}
