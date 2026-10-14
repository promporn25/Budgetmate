import 'package:budgetmate/screens/Forgot%20password%20screen.dart';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'language_setup_screen.dart';

/// หน้า Login (3.4.3) - เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน (ตรวจสอบกับ SQLite จริง)
///
/// ปรับดีไซน์ให้เข้าชุดเดียวกับหน้า Register / Forgot Password:
/// - ใช้โครงหน้า HeaderIconBadge + title + subtitle เหมือนกันทั้ง 3 หน้า auth
/// - เปลี่ยนปุ่มสลับ "เข้าสู่ระบบ/สมัครสมาชิก" จากกล่องสีทึบ 2 กล่อง
///   มาเป็น pill segmented toggle แบบเดียวกับที่ใช้ทั่วแอป
///   (เทียบ _filterChip ใน history_screen.dart, _periodChip ใน period_selector.dart)
/// - ใช้ AppTextStyles.title ให้สัดส่วนตัวอักษรตรงกับหน้าอื่น
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
  bool _googleLoading = false;

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
      Navigator.pushAndRemoveUntil(
          context, noAnimationRoute(const HomeScreen()), (route) => false);
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    final service = context.read<DataService>();
    final error = await service.loginWithGoogle();

    if (!mounted) return;

    if (error == null) {
      Navigator.pushAndRemoveUntil(
          context,
          noAnimationRoute(service.googleLoginCreatedAccount
              ? const LanguageSetupScreen()
              : const HomeScreen()),
          (route) => false);
    } else {
      setState(() {
        _googleLoading = false;
        _error = error;
      });
    }
  }

  void _goToRegister() {
    Navigator.push(context, noAnimationRoute(const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final isThai = service.currentLanguage != 'English';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ก้อนสีพาสเทลลอยด้านหลัง เพิ่มความน่ารักให้พื้นหลัง
          const _PastelBlob(
            top: -60,
            right: -50,
            size: 170,
          ),
          const _PastelBlob(
            bottom: -70,
            left: -60,
            size: 190,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // ไอคอนหัวข้อพร้อมแสงเรืองสีพาสเทลด้านหลัง ให้ดูนุ่มนวลน่ารักขึ้น
                    Center(
                      child: _GlowBadge(
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(service.t('app_name'),
                        textAlign: TextAlign.center, style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(service.t('login_subtitle'),
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
                            isLogin: true,
                            onLoginTap: () {},
                            onRegisterTap: _goToRegister,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailCtrl,
                            hint: service.t('email_hint'),
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _passCtrl,
                            hint: service.t('password_hint'),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            toggleObscure: () => setState(() => _obscure = !_obscure),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            MessageBanner(text: _error!),
                          ],
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: service.t('sign_in'),
                            loading: _loading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(isThai ? 'หรือ' : 'or',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 12.5)),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.bg,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                              ),
                              onPressed: _googleLoading ? null : _handleGoogleLogin,
                              icon: _googleLoading
                                  ? SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.textPrimary))
                                  : Image.asset('assets/images/google_logo.png',
                                      height: 20, width: 20,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Google'),
                              label: Text(
                                  isThai ? 'เข้าสู่ระบบด้วย Google' : 'Continue with Google',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                            context, noAnimationRoute(const ForgotPasswordScreen())),
                        child: Text(service.t('forgot_password_q'),
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
}

/// วงกลมแสงพาสเทลนุ่ม ๆ วางไว้ที่ไอคอนหัวข้อ เพื่อเพิ่มมิติและความน่ารักให้หน้า auth
class _GlowBadge extends StatelessWidget {
  final IconData icon;
  const _GlowBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        HeaderIconBadge(icon: icon),
      ],
    );
  }
}

/// ก้อนแสงพาสเทลลอยอยู่มุมจอ ใช้เป็นของแต่งพื้นหลังโทนนุ่มนวล
/// ใช้เทคนิค BoxShadow เบลอ (กล่องขนาด 0x0 แล้วให้เงาฟุ้งออกรอบทิศ) แทนการไล่สี
/// แบบ gradient เพราะเบลอจริงแบบนี้จะฟุ้งกลืนไปกับพื้นหลังได้เนียนทุกด้าน
/// ไม่มีขอบเส้นแข็ง ๆ ให้เห็นแม้จะโดนขอบจอตัดก็ตาม
class _PastelBlob extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;

  const _PastelBlob({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDeep.withOpacity(0.16),
                blurRadius: size * 0.55,
                spreadRadius: size * 0.12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill segmented toggle "เข้าสู่ระบบ / สมัครสมาชิก" — ใช้โทนสี/รูปแบบเดียวกับ
/// _typeToggle ใน add_income_expense_screen.dart (แถบพื้นหลัง AppColors.surface
/// มีเส้นขอบ + แท่งไฮไลต์ AppColors.accentDeep) เพื่อให้หน้า Login/Register
/// ใช้ภาษาภาพเดียวกับส่วนอื่นของแอป
///
/// เป็น toggle ที่ "เลื่อนได้" จริง ๆ: แท่งไฮไลต์จะ animate เลื่อนไปด้านที่แตะ
/// ก่อน แล้วค่อยเรียก callback นำทางไปหน้านั้น (ดีเลย์เท่ากับ duration ของ
/// แอนิเมชัน) ทำให้เห็นการสลับ tab ลื่นไหลก่อนเปลี่ยนหน้าจริง
/// ใช้ร่วมกันได้ทั้งหน้า Login (isLogin: true) และหน้า Register (isLogin: false)
class AuthTabToggle extends StatefulWidget {
  final String loginLabel;
  final String registerLabel;
  final bool isLogin;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  const AuthTabToggle({
    super.key,
    required this.loginLabel,
    required this.registerLabel,
    required this.isLogin,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  @override
  State<AuthTabToggle> createState() => _AuthTabToggleState();
}

class _AuthTabToggleState extends State<AuthTabToggle> {
  static const _duration = Duration(milliseconds: 260);
  late bool _isLogin = widget.isLogin;

  @override
  void didUpdateWidget(covariant AuthTabToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLogin != widget.isLogin) {
      setState(() => _isLogin = widget.isLogin);
    }
  }

  void _handleTap(bool tappedLogin) {
    if (tappedLogin == _isLogin) return;
    // เลื่อนแท่งไฮไลต์ไปด้านที่แตะก่อน แล้วค่อยนำทางไปหน้าใหม่
    setState(() => _isLogin = tappedLogin);
    Future.delayed(_duration, () {
      if (!mounted) return;
      tappedLogin ? widget.onLoginTap() : widget.onRegisterTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    const height = 46.0;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: _duration,
            curve: Curves.easeOutCubic,
            alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentDeep,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleTap(true),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      style: TextStyle(
                          color: _isLogin ? Colors.white : AppColors.textPrimary,
                          fontWeight: _isLogin ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14),
                      child: Text(widget.loginLabel),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleTap(false),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      style: TextStyle(
                          color: !_isLogin ? Colors.white : AppColors.textPrimary,
                          fontWeight: !_isLogin ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14),
                      child: Text(widget.registerLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
