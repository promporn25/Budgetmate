import 'package:flutter/material.dart';

/// ประเภทของหมวดหมู่ สอดคล้องกับ Entity Category (category_type)
enum CategoryType { income, expense }

/// เอนทิตี้ Category ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class CategoryModel {
  final String id; // category_id
  final String name; // category_name
  final CategoryType type; // category_type
  final IconData icon;
  final String? description; // description

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.description,
  });
}

/// หมวดหมู่เริ่มต้นของระบบ (ผู้ใช้สามารถเพิ่มเองได้ผ่าน DataService)
final List<CategoryModel> defaultCategories = [
  CategoryModel(id: 'c01', name: 'อาหาร', type: CategoryType.expense, icon: Icons.restaurant),
  CategoryModel(id: 'c02', name: 'เครื่องดื่ม', type: CategoryType.expense, icon: Icons.local_cafe),
  CategoryModel(id: 'c03', name: 'ที่พัก', type: CategoryType.expense, icon: Icons.home),
  CategoryModel(id: 'c04', name: 'ยานพาหนะ', type: CategoryType.expense, icon: Icons.directions_car),
  CategoryModel(id: 'c05', name: 'ภาษี', type: CategoryType.expense, icon: Icons.receipt_long),
  CategoryModel(id: 'c06', name: 'ช้อปปิ้ง', type: CategoryType.expense, icon: Icons.shopping_bag),
  CategoryModel(id: 'c07', name: 'ของขวัญ', type: CategoryType.expense, icon: Icons.card_giftcard),
  CategoryModel(id: 'c08', name: 'ท่องเที่ยว', type: CategoryType.expense, icon: Icons.flight),
  CategoryModel(id: 'c09', name: 'ความงาม', type: CategoryType.expense, icon: Icons.spa),
  CategoryModel(id: 'c10', name: 'บันเทิง', type: CategoryType.expense, icon: Icons.music_note),
  CategoryModel(id: 'c11', name: 'กีฬา', type: CategoryType.expense, icon: Icons.sports_soccer),
  CategoryModel(id: 'c12', name: 'สัตว์เลี้ยง', type: CategoryType.expense, icon: Icons.pets),
  CategoryModel(id: 'c13', name: 'การศึกษา', type: CategoryType.expense, icon: Icons.school),
  CategoryModel(id: 'c14', name: 'เงินเดือน', type: CategoryType.income, icon: Icons.payments),
  CategoryModel(id: 'c15', name: 'รายได้เสริม', type: CategoryType.income, icon: Icons.trending_up),
  CategoryModel(id: 'c16', name: 'โบนัส', type: CategoryType.income, icon: Icons.card_membership),
];
