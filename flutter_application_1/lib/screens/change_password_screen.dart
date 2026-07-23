import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';


/// หน้า Password & Security - เปลี่ยนรหัสผ่าน (ต้องยืนยันรหัสผ่านเดิมก่อน)
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _submit() async {
    if (_loading) return;
    if (_currentCtrl.text.isEmpty) {
      setState(() {
        _error = 'กรุณากรอกรหัสผ่านเดิม';
        _success = null;
      });
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() {
        _error = 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร';
        _success = null;
      });
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() {
        _error = 'รหัสผ่านใหม่ไม่ตรงกัน';
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
    final error = await service.changePassword(_currentCtrl.text, _newCtrl.text);

    if (!mounted) return;
    if (error == null) {
      setState(() {
        _loading = false;
        _success = 'เปลี่ยนรหัสผ่านสำเร็จ';
      });
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
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
        title: const Text('Password & Security', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeaderIconBadge(icon: Icons.shield_outlined),
              const SizedBox(height: 24),
              _label('รหัสผ่านเดิม'),
              AppTextField(
                controller: _currentCtrl,
                hint: 'กรอกรหัสผ่านปัจจุบัน',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureCurrent,
                toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 16),
              _label('รหัสผ่านใหม่'),
              AppTextField(
                controller: _newCtrl,
                hint: 'อย่างน้อย 6 ตัวอักษร',
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureNew,
                toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 16),
              _label('ยืนยันรหัสผ่านใหม่'),
              AppTextField(
                controller: _confirmCtrl,
                hint: 'กรอกรหัสผ่านใหม่อีกครั้ง',
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirm,
                toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                MessageBanner(text: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 16),
                MessageBanner(text: _success!, isError: false),
              ],
              const SizedBox(height: 24),
              PrimaryButton(label: 'บันทึกรหัสผ่านใหม่', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: Colors.grey.shade800)),
      );
}