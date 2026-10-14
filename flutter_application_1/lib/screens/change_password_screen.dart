import '../widgets/password_requirements.dart';
import '../services/password_policy.dart';
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

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final service = context.read<DataService>();
    if (_currentCtrl.text.isEmpty) {
      setState(() {
        _error = service.t('enter_current_password');
        _success = null;
      });
      return;
    }
    final invalid = passwordValidationKey(_newCtrl.text);
    if (invalid != null) {
      setState(() {
        _error = service.t(invalid);
        _success = null;
      });
      return;
    }
    if (_confirmCtrl.text.isEmpty) {
      setState(() { _error = service.t('enter_confirm_password'); _success = null; });
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() {
        _error = service.t('password_mismatch');
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    String? error;
    try { error = await service.changePassword(_currentCtrl.text, _newCtrl.text); }
    catch (_) { error = service.t('save_failed'); }

    if (!mounted) return;
    if (error == null) {
      setState(() {
        _loading = false;
        _success = service.t('change_password_success');
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
    final service = context.watch<DataService>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(service.t('password_security'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeaderIconBadge(icon: Icons.shield_outlined),
              const SizedBox(height: 18),
              _label(service.t('current_password')),
              AppTextField(
                controller: _currentCtrl,
                autofillHints: const [AutofillHints.password],
                hint: service.t('current_password_hint'),
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureCurrent,
                toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 12),
              _label(service.t('new_password')),
              AppTextField(
                controller: _newCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                hint: service.t('new_password_hint'),
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureNew,
                toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 12),
              _label(service.t('confirm_new_password')),
              AppTextField(
                controller: _confirmCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                hint: service.t('confirm_new_password_hint'),
                icon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirm,
                toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              PasswordRequirements(password: _newCtrl, confirmation: _confirmCtrl),
              if (_error != null) ...[
                const SizedBox(height: 12),
                MessageBanner(text: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                MessageBanner(text: _success!, isError: false),
              ],
              const SizedBox(height: 18),
              PrimaryButton(label: service.t('save_new_password'), loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
      );
}