import 'package:flutter/material.dart';
import 'login_screen.dart';

/// หน้า Loading (3.4.1) - แสดงขณะเริ่มต้นแอปพลิเคชัน
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'BUDGETMATE',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
