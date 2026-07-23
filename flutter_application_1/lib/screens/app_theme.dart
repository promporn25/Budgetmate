import 'package:flutter/material.dart';

/// ธีมกลางของแอป BUDGETMATE - ใช้ค่าจากไฟล์นี้แทนการ hardcode สี/มุมโค้งซ้ำๆ ในแต่ละหน้า
/// เพื่อให้ทุกหน้าไปในทิศทางเดียวกัน (สีดำ-ส้มเป็นหลัก โทนพื้นหลังขาว/เทาอ่อน)
class AppColors {
  static const ink = Colors.black; // ปุ่มหลัก/ข้อความสำคัญ
  static const accent = Colors.orange; // สีเน้น (SAVE, selected state, progress)
  static Color get surface => Colors.grey.shade100; // การ์ด/ฟิลด์พื้นหลัง
  static Color get surfaceAlt => Colors.grey.shade50;
  static Color get border => Colors.grey.shade300;
  static Color get textSecondary => Colors.grey.shade600;
  static Color get textMuted => Colors.grey.shade400;
  static Color get success => Colors.green.shade700;
  static Color get successBg => Colors.green.shade50;
  static Color get danger => Colors.red.shade700;
  static Color get dangerBg => Colors.red.shade50;
  static Color get income => Colors.green.shade800;
  static Color get incomeBg => Colors.green.shade100;
  static Color get expense => Colors.red.shade800;
  static Color get expenseBg => Colors.red.shade100;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppTextStyles {
  static const title = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
  static const heading = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static TextStyle get hint => TextStyle(color: AppColors.textMuted, fontSize: 14);
  static TextStyle get caption => TextStyle(color: AppColors.textSecondary, fontSize: 12.5);
}

/// การ์ดพื้นฐานที่ใช้ซ้ำได้ทั่วแอป (พื้นหลังเทาอ่อน มุมโค้ง)
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
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
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

/// ปุ่มหลักของแอป (พื้นดำ ตัวอักษรขาว มุมโค้ง) ใช้แทน ElevatedButton ธรรมดา
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
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// ฟิลด์กรอกข้อความสไตล์เดียวกันทั้งแอป (พื้นเทาอ่อน ไม่มีเส้นขอบ มุมโค้ง)
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? toggleObscure;
  final TextInputType? keyboardType;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.toggleObscure,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500, size: 21) : null,
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey.shade500,
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
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// ไอคอนวงกลมหัวเรื่อง (ใช้กับหน้า auth/ฟอร์มที่อยากมี visual anchor ด้านบน)
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
          color: background ?? Colors.orange.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 38, color: iconColor ?? Colors.orange.shade700),
      ),
    );
  }
}

/// ป้ายกลมๆ ว่าง (empty state) ใช้ตรงกลางลิสต์ที่ยังไม่มีข้อมูล
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
          Icon(icon, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}