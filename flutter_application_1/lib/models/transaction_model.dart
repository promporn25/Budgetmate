import 'category_model.dart';

/// เอนทิตี้ Transaction ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class TransactionModel {
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
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      description: description ?? this.description,
      receiptPath: receiptPath ?? this.receiptPath,
    );
  }
}
