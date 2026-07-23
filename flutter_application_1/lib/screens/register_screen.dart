import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// หน้า Register (3.4.4) - สมัครสมาชิกผู้ใช้งานใหม่ (บันทึกลง SQLite จริง)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Future<void> _handleRegister() async {
    if (_loading) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'รหัสผ่านไม่ตรงกัน');
      return;
    }
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.register(
        _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false, // ล้าง stack ทั้งหมด กัน back ย้อนไปหน้า Login/Register
      );
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeaderIconBadge(icon: Icons.person_add_alt_1_rounded),
                const SizedBox(height: 20),
                const Text('สร้างบัญชีใหม่',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text('เริ่มจัดการเงินของคุณกับ BUDGETMATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _nameCtrl,
                  hint: 'ชื่อ',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _emailCtrl,
                  hint: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _passCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePass,
                  toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirmCtrl,
                  hint: 'Confirm Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MessageBanner(text: _error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Sign Up',
                  loading: _loading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _goToLogin,
                    child: Text.rich(
                      TextSpan(
                        text: 'มีบัญชีอยู่แล้ว? ',
                        style: TextStyle(color: Colors.grey.shade700),
                        children: const [
                          TextSpan(
                            text: 'เข้าสู่ระบบ',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}