import 'dart:io';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

const List<String> _languageOptions = ['ไทย', 'English'];

/// หน้า Account Setting (3.4.5) - จัดการข้อมูลบัญชีผู้ใช้งานและการตั้งค่าแอป
class AccountSettingScreen extends StatelessWidget {
  const AccountSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final user = service.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Account Setting', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _AvatarPicker(service: service),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '-',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Account'),
          _tile(context, 'Manage Profile',
              icon: Icons.badge_outlined, onTap: () => _editNameDialog(context, service)),
          _tile(context, 'Password & Security',
              icon: Icons.lock_outline_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          _tile(context, 'Language',
              icon: Icons.language_rounded,
              trailing: user?.language ?? 'ไทย',
              onTap: () => _languageDialog(context, service)),
          const SizedBox(height: 20),
          _sectionLabel('Preferences'),
          _tile(context, 'About Us',
              icon: Icons.info_outline_rounded, onTap: () => _aboutDialog(context)),
          _switchTile(
            title: 'Theme',
            icon: Icons.dark_mode_outlined,
            subtitle: service.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
            value: service.themeMode == ThemeMode.dark,
            onChanged: (_) => service.toggleTheme(),
          ),
          _switchTile(
            title: 'Success Notes',
            icon: Icons.notifications_outlined,
            subtitle: service.successNotesEnabled ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
            value: service.successNotesEnabled,
            onChanged: (_) => service.toggleSuccessNotes(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: () async {
                await service.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false);
              },
              child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: AppTextStyles.heading),
      );

  Widget _tile(BuildContext context, String title,
      {IconData? icon, String? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: icon != null ? Icon(icon, color: Colors.grey.shade600, size: 21) : null,
          title: Text(title, style: const TextStyle(fontSize: 14.5)),
          trailing: trailing != null
              ? Text(trailing, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
              : Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required IconData icon,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.grey.shade600, size: 21),
          title: Text(title, style: const TextStyle(fontSize: 14.5)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
          trailing: Switch(
            value: value,
            activeColor: Colors.orange,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  void _editNameDialog(BuildContext context, DataService service) {
    final ctrl = TextEditingController(text: service.currentUser?.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('แก้ไขชื่อผู้ใช้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ชื่อที่แสดง',
                style: AppTextStyles.label.copyWith(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            AppTextField(controller: ctrl, hint: 'ชื่อผู้ใช้', icon: Icons.person_outline_rounded),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await service.updateProfile(name: ctrl.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _languageDialog(BuildContext context, DataService service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('เลือกภาษา'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languageOptions.map((lang) {
            final selected = (service.currentUser?.language ?? 'ไทย') == lang;
            return ListTile(
              title: Text(lang),
              trailing: selected
                  ? Icon(Icons.check_circle_rounded, color: Colors.orange.shade700)
                  : null,
              onTap: () async {
                await service.updateProfile(language: lang);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _aboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('About BUDGETMATE'),
        content: const Text(
          'BUDGETMATE คือแอปช่วยจัดการรายรับ-รายจ่ายและเป้าหมายการออมเงินส่วนตัว '
          'พัฒนาโดยนิสิตคณะวิศวกรรมศาสตร์ มหาวิทยาลัยเกษตรศาสตร์\n\nเวอร์ชัน 1.0.0',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: const Text('ปิด')),
        ],
      ),
    );
  }
}

/// รูปโปรไฟล์ที่แตะเพื่อเปลี่ยนได้ (ถ่ายรูปใหม่ / เลือกจากคลังภาพ / ลบรูป)
class _AvatarPicker extends StatelessWidget {
  final DataService service;
  const _AvatarPicker({required this.service});

  @override
  Widget build(BuildContext context) {
    final path = service.avatarPath;
    final hasImage = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => _showPickerSheet(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.shade50,
            backgroundImage: hasImage ? FileImage(File(path)) : null,
            child: hasImage
                ? null
                : Icon(Icons.person, size: 28, color: Colors.orange.shade700),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        final hasImage = service.avatarPath != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('ถ่ายรูปใหม่'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await service.pickAvatar(fromCamera: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('เลือกจากคลังภาพ'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await service.pickAvatar(fromCamera: false);
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text('ลบรูปโปรไฟล์', style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await service.removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}