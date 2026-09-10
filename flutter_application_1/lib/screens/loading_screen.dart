import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

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
            const SizedBox(height: 24),
            Text(
              service.t('app_name'),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}