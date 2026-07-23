import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // TODO: ปรับ path ให้ตรงกับโปรเจกต์จริง
// import 'home_screen.dart'; // ใช้ถ้ามีระบบเช็ค session ว่าล็อกอินค้างอยู่ไหม

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
    // TODO: ใส่ logic เตรียมข้อมูลจริงตรงนี้ เช่น เช็ค session ที่ล็อกอินค้างไว้
    // ตอนนี้หน่วงเวลาไว้ก่อนเพื่อให้เห็น GIF ระหว่างโหลด
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, // กัน back ย้อนมาหน้า Splash
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
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