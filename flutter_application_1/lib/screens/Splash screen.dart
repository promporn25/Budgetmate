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