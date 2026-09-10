import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

/// หน้า Forgot Password - รีเซ็ตรหัสผ่านผ่าน Firebase Authentication
/// (ผู้ใช้กรอกแค่อีเมล ระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้ทางอีเมลโดยตรง
/// จึงไม่ต้องกรอกรหัสผ่านใหม่ในแอปอีกต่อไป)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  String? _error;
  String? _success;
  bool _loading = false;

  Future<void> _handleReset() async {
    if (_loading) return;
    final service = context.read<DataService>();

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = service.t('enter_email');
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    // ส่งลิงก์รีเซ็ตรหัสผ่านผ่าน Firebase Authentication (sendPasswordResetEmail)
    final error = await service.resetPassword(email);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _success = service.t('reset_email_sent');
      });
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
        title: Text(service.t('forgot_password_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            bottom: -60,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.15),
                      blurRadius: 99,
                      spreadRadius: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
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
                          const HeaderIconBadge(icon: Icons.lock_reset_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(service.t('reset_password_heading'),
                        textAlign: TextAlign.center, style: AppTextStyles.title),
                    const SizedBox(height: 8),
                    Text(
                      service.t('reset_password_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 28),

                    // การ์ดฟอร์มโค้งมนลอยตัว ให้ความรู้สึกนุ่มนวลอบอุ่นกว่าเดิม
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
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
                          _fieldLabel(service.t('email')),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: 'you@example.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_error != null || _success != null) {
                                setState(() {
                                  _error = null;
                                  _success = null;
                                });
                              }
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            MessageBanner(text: _error!),
                          ],
                          if (_success != null) ...[
                            const SizedBox(height: 18),
                            MessageBanner(text: _success!, isError: false),
                          ],
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: service.t('reset_password_heading'),
                            loading: _loading,
                            onPressed: _handleReset,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: Text(service.t('back_to_login'),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
      );
}