import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// สร้าง Route แบบไม่มีอนิเมชันสไลด์ (ใช้แทน MaterialPageRoute ทุกจุดในแอป
/// เพื่อให้การเปลี่ยนหน้าทุกที่ไม่มีเอฟเฟกต์เลื่อนจากขอบจอแบบ default ของ iOS)
PageRoute<T> noAnimationRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// ธีมกลางของแอป BUDGETMATE
class AppColors {
  AppColors._();

  static Brightness brightness = Brightness.light;
  static bool get _dark => brightness == Brightness.dark;

  static Color get ink => _dark ? const Color(0xFFC1E4F3) : const Color(0xFF3D568F);
  static Color get inkOn => Colors.white;
  static Color get accent => const Color(0xFFC1E4F3);
  static Color get accentAlt => const Color(0xFFFFE698);
  static Color get accentDeep => const Color(0xFF3D568F);
  static Color get accentPink => const Color.fromARGB(255, 234, 139, 171);

  static Color get accentBg => _dark ? const Color(0xFF223259) : const Color(0xFFDCEEF7);
  static Color get accentAltBg => _dark ? const Color(0xFF4A2A3C) : const Color(0xFFFBEED0);

  static Color get bg => _dark ? const Color(0xFF141A2C) : const Color(0xFFF6F9FF);
  static Color get surface => _dark ? const Color(0xFF1E2740) : const Color(0xFFEFF4FE);
  static Color get surfaceAlt => _dark ? const Color(0xFF262F4A) : const Color(0xFFFFF8FB);
  static Color get card => _dark ? const Color(0xFF1E2740) : const Color(0xFFFFFFFF);
  static Color get border => _dark ? const Color(0xFF2E3A5C) : const Color(0xFFE3EBFB);

  static Color get textPrimary => _dark ? const Color(0xFFEDF2FF) : const Color(0xFF283350);
  static Color get textSecondary => _dark ? const Color(0xFFAAB8DD) : const Color(0xFF8493B3);
  static Color get textMuted => _dark ? const Color(0xFFAAB8D5) : const Color(0xFFBCC8E2);

  static Color get success => _dark ? const Color(0xFF7FD9A8) : const Color(0xFF3D9E73);
  static Color get successBg => _dark ? const Color(0xFF1F3A2E) : const Color(0xFFE4F8ED);
  static Color get danger => _dark ? const Color(0xFFF0A0A0) : const Color(0xFFE0645F);
  static Color get dangerBg => _dark ? const Color(0xFF3E2429) : const Color(0xFFFFEAE8);
  static Color get income => _dark ? const Color(0xFFA0E4C0) : const Color(0xFF45AB7C);
  static Color get incomeBg => _dark ? const Color(0xFF1F3A2E) : const Color(0xFFE4F8ED);
  static Color get expense => _dark ? const Color(0xFFF6AFAA) : const Color(0xFFF0847A);
  static Color get expenseBg => _dark ? const Color(0xFF3E2429) : const Color(0xFFFFEAE8);

  static Color get shadow => const Color(0xFF80A1D4).withOpacity(_dark ? 0.30 : 0.10);

  static const List<Color> pinnedGoalBg = [Color(0xFFC1E4F3), Color(0xFFFFE698)];
  static Color get pinnedGoalIcon => const Color(0xFF3D568F);
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

/// ฟอนต์กลางของแอป — 'Mali' (มะลิ) ฟอนต์ไทยลายเส้นกลมมนน่ารัก อ่านง่าย
///
/// เวอร์ชันนี้ "บันเดิลไฟล์ฟอนต์ไว้ในเครื่อง" (assets/fonts/) แทนการเรียกผ่าน
/// แพ็กเกจ google_fonts ที่ดาวน์โหลดไฟล์ฟอนต์จากเน็ตตอนรันครั้งแรก
///
/// เหตุผลที่เปลี่ยนมาบันเดิลเอง: เวลาใช้ google_fonts มันจะไปดาวน์โหลดไฟล์ฟอนต์
/// จริง (.ttf) แบบ asynchronous ตอนแอปเรียกใช้ครั้งแรก ถ้าเน็ตช้า/ตอนนั้นยังโหลด
/// ไม่เสร็จ หน้าที่ render ไปแล้วก่อนโหลดเสร็จจะค้างใช้ฟอนต์ระบบเดิม (fallback)
/// ไปก่อน ส่วนหน้าที่ถูกเปิดทีหลัง (หลังโหลดฟอนต์เสร็จแล้ว) จะได้ฟอนต์ใหม่ทันที
/// - นี่คือสาเหตุที่ "บางหน้าเปลี่ยนฟอนต์ บางหน้าไม่เปลี่ยน" แบบสุ่มๆ ตามจังหวะ
/// การโหลด ไม่เกี่ยวกับโค้ดหน้านั้นๆ เลย
///
/// การบันเดิลไฟล์ฟอนต์ไว้ในแอปเอง (ผ่าน pubspec.yaml) ทำให้ฟอนต์พร้อมใช้งาน
/// ทันทีตั้งแต่เฟรมแรกที่แอปเปิด ไม่ต้องพึ่งอินเทอร์เน็ต และแสดงผลสม่ำเสมอ
/// เหมือนกันทุกหน้า ทุกเครื่อง ทุกครั้งที่เปิดแอป
///
/// หมายเหตุ: ต้องประกาศฟอนต์ 6 น้ำหนัก (200-700) ใน pubspec.yaml (ดูท้ายไฟล์)
/// เพื่อให้ FontWeight.w200 ... FontWeight.w700 ที่ใช้อยู่ทั่วแอป (w600, w700,
/// FontWeight.bold ฯลฯ) เลือกไฟล์ฟอนต์น้ำหนักที่ถูกต้องได้อัตโนมัติ
const String appFontFamily = 'Mali';

class AppTextStyles {
  static TextStyle get title => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static TextStyle get heading => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static TextStyle get label => TextStyle(
      fontFamily: appFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static TextStyle get hint => TextStyle(
      fontFamily: appFontFamily, color: AppColors.textMuted, fontSize: 14);
  static TextStyle get caption => TextStyle(
      fontFamily: appFontFamily, color: AppColors.textSecondary, fontSize: 12.5);
}

/// สร้าง ThemeData ของแอปสำหรับ MaterialApp(theme:, darkTheme:, themeMode:)
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141A2C) : const Color(0xFFF6F9FF);
    final ink = isDark ? const Color(0xFFC1E4F3) : const Color(0xFF3D568F);
    final surface = isDark ? const Color(0xFF1E2740) : const Color(0xFFEFF4FE);
    final onSurface = isDark ? const Color(0xFFEDF2FF) : const Color(0xFF283350);

    // .apply(fontFamily:) เซ็ตฟอนต์ให้ทุก TextStyle มาตรฐานใน textTheme
    // (bodyMedium, titleLarge, labelSmall ฯลฯ) ที่ widget ต่างๆ ในแอปอาจใช้
    // แบบ implicit (ผ่าน Theme.of(context).textTheme หรือ Text('...') เฉยๆ)
    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final appTextTheme = baseTextTheme.apply(fontFamily: appFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dialogBackgroundColor: isDark ? const Color(0xFF1E2740) : Colors.white,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF80A1D4),
        onPrimary: Colors.white,
        secondary: const Color(0xFFC08B9D),
        onSecondary: Colors.white,
        error: isDark ? const Color(0xFFF0A0A0) : const Color(0xFFE0645F),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            fontFamily: appFontFamily, fontSize: 17, fontWeight: FontWeight.w600, color: ink),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2740) : Colors.white,
        selectedItemColor: ink,
        unselectedItemColor: isDark ? const Color(0xFF69759A) : const Color(0xFFBCC8E2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? const Color(0xFFC1E4F3) : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? const Color(0xFF80A1D4) : null),
      ),
      textTheme: appTextTheme,
      // สำคัญ: เซ็ต fontFamily ตรงนี้ด้วย เผื่อ widget บางตัวอ้างอิง
      // ThemeData.fontFamily ตรงๆ แทนที่จะผ่าน textTheme
      fontFamily: appFontFamily,
    );
  }
}

/// Header พาสเทลโค้งมนด้านล่าง ใช้ซ้ำได้ทุกหน้า
class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppHeader({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(6, MediaQuery.of(context).padding.top + 4, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.brightness == Brightness.dark ? AppColors.surface : AppColors.accent,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
            onPressed: onBack ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: appFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 44,
            child: trailing ??
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.auto_awesome_rounded, color: AppColors.accentAlt, size: 20),
                ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดพื้นฐานที่ใช้ซ้ำได้ทั่วแอป
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoratedChild = Material(
      type: MaterialType.transparency,
      child: child,
    );
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: decoratedChild,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// ปุ่มหลักของแอป (พื้น ink ตัวอักษรตัดกัน มุมโค้ง)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.ink;
    final fg = AppColors.inkOn;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          animationDuration: const Duration(milliseconds: 120),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Text(label,
                style: TextStyle(
                    fontFamily: appFontFamily,
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// ฟิลด์กรอกข้อความสไตล์เดียวกันทั้งแอป
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? toggleObscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final String? prefixText;
  final String? errorText;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.toggleObscure,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.prefixText,
    this.errorText,
    this.style,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      autofocus: autofocus,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: style ?? TextStyle(fontFamily: appFontFamily, fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        prefixText: prefixText,
        prefixStyle: style ?? TextStyle(fontFamily: appFontFamily, fontSize: 15, color: AppColors.textPrimary),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 21) : null,
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accentDeep, width: 1.4),
        ),
        errorText: errorText,
        errorStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.danger, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}

/// แบนเนอร์ error/success ใช้ซ้ำได้ทุกฟอร์ม
class MessageBanner extends StatelessWidget {
  final String text;
  final bool isError;

  const MessageBanner({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    final bg = isError ? AppColors.dangerBg : AppColors.successBg;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm + 2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontFamily: appFontFamily, color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// ไอคอนวงกลมหัวเรื่อง
class HeaderIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? iconColor;

  const HeaderIconBadge({super.key, required this.icon, this.background, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: background ?? AppColors.accentBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 38, color: iconColor ?? AppColors.ink),
      ),
    );
  }
}

/// ตัวการ์ตูนน่ารักๆ วาดด้วย CustomPainter
enum CuteMascotKind { bell, coin, star, flagTH, flagEN, flagUS, income, expense }

class CuteMascot extends StatelessWidget {
  final CuteMascotKind kind;
  final double size;
  final Color? color;

  const CuteMascot({super.key, required this.kind, this.size = 22, this.color});

  Color _defaultColor() {
    switch (kind) {
      case CuteMascotKind.income:
        return const Color(0xFFA9E0BC);
      case CuteMascotKind.expense:
        return const Color(0xFFF5C2B3);
      default:
        return AppColors.accentDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CuteMascotPainter(kind: kind, color: color ?? _defaultColor()),
      ),
    );
  }
}

class _CuteMascotPainter extends CustomPainter {
  final CuteMascotKind kind;
  final Color color;

  _CuteMascotPainter({required this.kind, required this.color});

  Color get _face => Color.lerp(color, Colors.black, 0.55)!;

  double get _tilt {
    switch (kind) {
      case CuteMascotKind.income:
        return -0.1;
      case CuteMascotKind.expense:
        return 0.1;
      default:
        return 0.0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_tilt);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.92), width: r * 1.3, height: r * 0.22),
      Paint()..color = Colors.black.withOpacity(0.05),
    );

    canvas.drawCircle(Offset.zero, r * 0.86, Paint()..color = color);

    final eyeR = r * 0.09;
    final eyeOffsetX = r * 0.28;
    final eyeY = -r * 0.08;
    canvas.drawCircle(Offset(-eyeOffsetX, eyeY), eyeR, Paint()..color = _face);
    canvas.drawCircle(Offset(eyeOffsetX, eyeY), eyeR, Paint()..color = _face);

    final smile = Path()
      ..moveTo(-r * 0.18, r * 0.2)
      ..quadraticBezierTo(0, r * 0.34, r * 0.18, r * 0.2);
    canvas.drawPath(
      smile,
      Paint()
        ..color = _face
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );

    if (kind == CuteMascotKind.flagTH ||
        kind == CuteMascotKind.flagEN ||
        kind == CuteMascotKind.flagUS) {
      final label = kind == CuteMascotKind.flagTH
          ? 'TH'
          : kind == CuteMascotKind.flagEN
              ? 'EN'
              : 'US';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontFamily: appFontFamily, fontSize: r * 0.36, fontWeight: FontWeight.w700, color: _face),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, r * 0.34));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CuteMascotPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/*
==================== วิธีติดตั้งฟอนต์ Mali (บันเดิลในเครื่อง) ====================
1) วางไฟล์ฟอนต์ทั้ง 6 ไฟล์ (แนบมาให้แล้วในโฟลเดอร์ fonts/) ไว้ที่:
     assets/fonts/Mali-ExtraLight.ttf
     assets/fonts/Mali-Light.ttf
     assets/fonts/Mali-Regular.ttf
     assets/fonts/Mali-Medium.ttf
     assets/fonts/Mali-SemiBold.ttf
     assets/fonts/Mali-Bold.ttf

2) เปิด pubspec.yaml แล้วเพิ่มส่วนนี้ใต้ flutter: (ลบ dependency
   google_fonts ออกจาก pubspec ได้เลยถ้าไม่ได้ใช้ที่อื่นในโปรเจกต์แล้ว):

   flutter:
     fonts:
       - family: Mali
         fonts:
           - asset: assets/fonts/Mali-ExtraLight.ttf
             weight: 200
           - asset: assets/fonts/Mali-Light.ttf
             weight: 300
           - asset: assets/fonts/Mali-Regular.ttf
             weight: 400
           - asset: assets/fonts/Mali-Medium.ttf
             weight: 500
           - asset: assets/fonts/Mali-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Mali-Bold.ttf
             weight: 700

3) รันคำสั่งนี้ในโปรเจกต์:
     flutter pub get

4) ทำ hot restart (ไม่ใช่แค่ hot reload) — สำคัญมาก เพราะการเพิ่ม/แก้ font
   assets ใน pubspec.yaml ต้อง restart แอปใหม่ทั้งหมด hot reload อย่างเดียว
   จะไม่ดึงฟอนต์ใหม่มาโหลด

การบันเดิลฟอนต์แบบนี้ทำให้ทุกหน้าในแอปได้ฟอนต์ Mali ทันทีตั้งแต่เปิดแอป
ไม่มีปัญหา "บางหน้าเปลี่ยน บางหน้าไม่เปลี่ยน" อีกต่อไป เพราะไม่ต้องพึ่ง
การดาวน์โหลดฟอนต์จากอินเทอร์เน็ตแบบที่ google_fonts package ทำ

ไฟล์ OFL.txt (สัญญาอนุญาต SIL Open Font License) แนบมาด้วย — ใช้งาน/แจกจ่าย
ในแอปได้ฟรีทั้งเชิงพาณิชย์และไม่เชิงพาณิชย์ ไม่ต้องขออนุญาตเพิ่มเติม
*/