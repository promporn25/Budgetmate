import '../widgets/password_requirements.dart';
import '../services/password_policy.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'language_setup_screen.dart';

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_loading) return;
    final service = context.read<DataService>();

    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = service.t('fill_all_fields'));
      return;
    }
    if (_confirmCtrl.text.isEmpty) {
      setState(() => _error = service.t('enter_confirm_password'));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = service.t('password_mismatch'));
      return;
    }

    final invalid = passwordValidationKey(_passCtrl.text);
    if (invalid != null) {
      setState(() => _error = service.t(invalid));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? error;
    try {
      error = await service.register(
          _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      error = '${service.t('save_failed')}: $e';
    }

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        noAnimationRoute(const LanguageSetupScreen()),
        (route) => false,
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
        context, noAnimationRoute(const LoginScreen()));
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
      ),
      body: Stack(
        children: [
          // ก้อนสีพาสเทลลอยด้านหลัง เพิ่มความน่ารักให้พื้นหลัง
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.16),
                      blurRadius: 88,
                      spreadRadius: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.15),
                      blurRadius: 105,
                      spreadRadius: 23,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ไอคอนหัวข้อพร้อมแสงเรืองสีพาสเทลด้านหลัง
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.accentDeep.withOpacity(0.20),
                                  AppColors.accentDeep.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          const HeaderIconBadge(icon: Icons.person_add_alt_1_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('create_account'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(service.t('register_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                    const SizedBox(height: 26),

                    // การ์ดฟอร์มโค้งมนลอยตัว ให้ความรู้สึกนุ่มนวลอบอุ่นกว่าเดิม
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md + 8),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDeep.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // สลับ เข้าสู่ระบบ/สมัครสมาชิก แบบ pill segmented ที่เลื่อนได้จริง
                          AuthTabToggle(
                            loginLabel: service.t('login'),
                            registerLabel: service.t('register'),
                            isLogin: false,
                            onLoginTap: _goToLogin,
                            onRegisterTap: () {},
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _nameCtrl,
                            hint: service.t('name_hint'),
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: service.t('email_hint'),
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _passCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                            hint: service.t('password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _confirmCtrl,
                            autofillHints: const [AutofillHints.newPassword],
                            hint: service.t('confirm_password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirm,
                            toggleObscure: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
              PasswordRequirements(password: _passCtrl, confirmation: _confirmCtrl),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            MessageBanner(text: _error!),
                          ],
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: service.t('sign_up'),
                            loading: _loading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}