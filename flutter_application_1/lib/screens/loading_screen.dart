import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// เตรียมข้อมูลและกู้คืนบัญชีก่อนเข้าสู่แอป
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
    final isThai = service.currentLanguage != 'English';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 240,
                height: 232,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 218, height: 218,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFF6F9FF),
                        const Color(0xFFDCEEF7),
                        AppColors.accentBg.withValues(alpha: 0.15),
                      ], stops: const [0.35, 0.78, 1]),
                    ),
                  ),
                  Image.asset(
                    'assets/images/loading.gif',
                    width: 160, height: 160,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text(service.t('app_name'), textAlign: TextAlign.center,
                style: TextStyle(fontFamily: appFontFamily, fontSize: 21,
                  fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(isThai ? '' : 'Little savings, lovely possibilities',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(fontSize: 13)),
              const SizedBox(height: 22),
              Semantics(
                label: isThai ? 'กำลังเตรียมข้อมูล' : 'Loading your data',
                child: const ExcludeSemantics(child: _LoadingDots()),
              ),
              const SizedBox(height: 12),
              Text(isThai ? 'รอสักครู่นะ…' : 'Just a moment…',
                textAlign: TextAlign.center, style: AppTextStyles.caption),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = (_controller.value - index * 0.18) % 1.0;
          final opacity = reduceMotion ? 0.7 : 0.3 + 0.7 *
              Curves.easeInOut.transform(1 - (phase * 2 - 1).abs());
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.ink, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}
