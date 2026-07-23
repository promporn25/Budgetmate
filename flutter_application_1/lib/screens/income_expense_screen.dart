import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';
import 'Income expense overview.dart';

/// หน้า Income/Expense (3.4.9) - แสดงสัดส่วนรายจ่ายแบบ Pie Chart และประวัติรายวัน
/// เนื้อหาหลัก (pie chart + history) อยู่ใน [IncomeExpenseOverview] เพื่อให้ฝังใช้ซ้ำได้
/// ในหน้า Add Income/Expense ตอนเลือกแท็บ "Expenses" ด้วยเช่นกัน
class IncomeExpenseScreen extends StatelessWidget {
  const IncomeExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Income/Expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: const IncomeExpenseOverview(),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}