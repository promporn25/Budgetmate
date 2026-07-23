import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'language_setup_screen.dart';

/// หน้า Loading (3.4.1) - เริ่มต้นฐานข้อมูล SQLite และตรวจสอบ session ที่ล็อกอินค้างไว้
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

    await service.init(); // สร้างตาราง/seed หมวดหมู่ + กู้คืน session

    // ให้หน้า Loading แสดงอย่างน้อย 1.2 วินาที กันจอกระพริบเร็วเกินไป
    final elapsed = DateTime.now().difference(started);
    final remain = const Duration(milliseconds: 1200) - elapsed;
    if (remain > Duration.zero) {
      await Future.delayed(remain);
    }

    if (!mounted) return;

    Widget nextScreen;
    if (service.currentUser != null) {
      // มี session ล็อกอินค้างอยู่ -> เข้าหน้า Home ทันที
      nextScreen = const HomeScreen();
    } else if (!(await service.isSetupCompleted())) {
      // เปิดแอปครั้งแรก -> ให้ตั้งค่าภาษา/สกุลเงินก่อน
      nextScreen = const LanguageSetupScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
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
            const SizedBox(height: 24),
            const Text(
              'BUDGETMATE',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.orange.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}