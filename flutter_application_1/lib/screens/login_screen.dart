import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';


/// หน้า Login (3.4.3) - เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน (ตรวจสอบกับ SQLite จริง)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeaderIconBadge(icon: Icons.account_balance_wallet_rounded),
                const SizedBox(height: 20),
                const Text('BUDGETMATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('เข้าสู่ระบบเพื่อจัดการเงินของคุณ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Text('เข้าสู่ระบบ',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text('สมัครสมาชิก',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                  obscureText: _obscure,
                  toggleObscure: () => setState(() => _obscure = !_obscure),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  MessageBanner(text: _error!),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Sign In',
                  loading: _loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: Text('Forgot password?',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}