import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';


/// หน้า Forgot Password - รีเซ็ตรหัสผ่านด้วยอีเมล
/// หมายเหตุ: แอปนี้เก็บข้อมูลใน SQLite ภายในเครื่องเท่านั้น (ไม่มีระบบส่งอีเมลจริง)
/// จึงให้ผู้ใช้กรอกอีเมลเพื่อยืนยันตัวตน แล้วตั้งรหัสผ่านใหม่ได้ทันที
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String? _error;
  String? _success;
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _handleReset() async {
    if (_loading) return;

    if (_emailCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'กรุณากรอกอีเมล';
        _success = null;
      });
      return;
    }
    if (_newPassCtrl.text.isEmpty) {
      setState(() {
        _error = 'กรุณากรอกรหัสผ่านใหม่';
        _success = null;
      });
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() {
        _error = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
        _success = null;
      });
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() {
        _error = 'รหัสผ่านไม่ตรงกัน';
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final service = context.read<DataService>();
    final error = await service.resetPassword(
        _emailCtrl.text.trim(), _newPassCtrl.text);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _success = 'ตั้งรหัสผ่านใหม่สำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่';
      });
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('ลืมรหัสผ่าน', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const HeaderIconBadge(icon: Icons.lock_reset_rounded),
                const SizedBox(height: 20),
                const Text('ตั้งรหัสผ่านใหม่',
                    textAlign: TextAlign.center, style: AppTextStyles.title),
                const SizedBox(height: 8),
                Text(
                  'กรอกอีเมลที่ใช้สมัครสมาชิก แล้วตั้งรหัสผ่านใหม่ได้เลย',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 32),

                _fieldLabel('อีเมล'),
                AppTextField(
                  controller: _emailCtrl,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),

                _fieldLabel('รหัสผ่านใหม่'),
                AppTextField(
                  controller: _newPassCtrl,
                  hint: 'อย่างน้อย 6 ตัวอักษร',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureNew,
                  toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 18),

                _fieldLabel('ยืนยันรหัสผ่านใหม่'),
                AppTextField(
                  controller: _confirmPassCtrl,
                  hint: 'กรอกรหัสผ่านอีกครั้ง',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  toggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 18),
                  MessageBanner(text: _error!),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 18),
                  MessageBanner(text: _success!, isError: false),
                ],

                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'ตั้งรหัสผ่านใหม่',
                  loading: _loading,
                  onPressed: _handleReset,
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text('กลับไปหน้าเข้าสู่ระบบ',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: Colors.grey.shade800)),
      );
}