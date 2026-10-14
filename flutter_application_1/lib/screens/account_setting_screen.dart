import '../widgets/data_action.dart';
import 'dart:convert';
import 'dart:io';
import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

const List<String> _languageOptions = ['ไทย', 'English'];


const List<Color> _menuTintIcon = [
  Color(0xFF80A1D4),
  Color(0xFFC08B9D),
  Color(0xFFC79A3B),
  Color(0xFF3D568F),
];


class AccountSettingScreen extends StatelessWidget {
  const AccountSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final user = service.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CuteMenuHeader(title: service.t('account_setting_title')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppLayout.pageInset(context), vertical: 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(service: service, user: user),
                  const SizedBox(height: 18),
                  _sectionLabel(service.t('account_section'), Icons.favorite_rounded, AppColors.accentPink),
                  _settingsGroup([
                  _tile(context, service.t('manage_profile'),
                      icon: Icons.badge_outlined,
                      tintIndex: 0,
                      onTap: () => _editNameDialog(context, service)),
                  _tile(context, service.t('password_security'),
                      icon: Icons.lock_outline_rounded,
                      tintIndex: 1,
                      onTap: () => Navigator.push(
                          context, noAnimationRoute(const ChangePasswordScreen()))),
                  _tile(context, service.t('language'),
                      icon: Icons.language_rounded,
                      tintIndex: 2,
                      trailing: user?.language ?? 'ไทย',
                      onTap: () => _languageDialog(context, service)),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel(service.t('preferences_section'), Icons.auto_awesome_rounded, AppColors.accentDeep),
                  _settingsGroup([
                  _tile(context, service.t('about_us'),
                      icon: Icons.info_outline_rounded,
                      tintIndex: 3,
                      onTap: () => _aboutDialog(context, service)),
                  _switchTile(
                    title: service.t('theme'),
                    icon: Icons.dark_mode_outlined,
                    tintIndex: 0,
                    subtitle: service.themeMode == ThemeMode.dark ? service.t('theme_dark') : service.t('theme_light'),
                    value: service.themeMode == ThemeMode.dark,
                    onChanged: (_) => service.toggleTheme(),
                  ),
                  _switchTile(
                    title: service.t('success_notes'),
                    icon: Icons.notifications_outlined,
                    tintIndex: 1,
                    subtitle: service.successNotesEnabled ? service.t('enabled') : service.t('disabled'),
                    value: service.successNotesEnabled,
                    onChanged: (_) => service.toggleSuccessNotes(),
                  ),
                  ]),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        backgroundColor: AppColors.dangerBg.withOpacity(0.5),
                        side: BorderSide(color: AppColors.danger.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                      onPressed: () async {
                        await service.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                            context,
                            noAnimationRoute(const LoginScreen()),
                            (route) => false);
                      },
                      icon: const Icon(Icons.waving_hand_rounded, size: 18),
                      label: Text(service.t('logout'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: AppTextStyles.heading)),
          ],
        ),
      );

  Widget _settingsGroup(List<Widget> children) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Divider(height: 1, indent: 44, color: AppColors.border),
        children[i],
      ],
    ]),
  );

  Widget _tile(BuildContext context, String title,
      {IconData? icon, String? trailing, VoidCallback? onTap, int tintIndex = 0}) =>
    ListTile(
      onTap: onTap,
      dense: false,
      minTileHeight: 58,
      minLeadingWidth: 26,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: icon == null ? null : Icon(icon, size: 24,
        color: _menuTintIcon[tintIndex % _menuTintIcon.length]),
      title: Text(title, style: TextStyle(fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) Text(trailing,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ]),
    );

  Widget _switchTile({required String title, required IconData icon,
    required String subtitle, required bool value,
    required ValueChanged<bool> onChanged, int tintIndex = 0}) =>
    ListTile(
      dense: false,
      minTileHeight: 58,
      minLeadingWidth: 26,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 24,
        color: _menuTintIcon[tintIndex % _menuTintIcon.length]),
      title: Text(title, style: TextStyle(fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: Semantics(label: subtitle, child: SizedBox(width: 48, height: 48,
        child: FittedBox(child: Switch(
          value: value, activeColor: AppColors.ink, onChanged: onChanged,
        )))),
    );

  void _editNameDialog(BuildContext context, DataService service) {
    final ctrl = TextEditingController(text: service.currentUser?.name);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        bool saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                setState(() => errorText = service.t('enter_username'));
                return;
              }
              setState(() {
                saving = true;
                errorText = null;
              });
              try {
                await service.updateProfile(name: name);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) setState(() {
                  saving = false;
                  errorText = '${service.t('save_failed')}: $e';
                });
              }
            }

            return Dialog(
              backgroundColor: AppColors.bg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.accentBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.badge_outlined, color: AppColors.ink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(service.t('edit_username'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(service.t('display_name'),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: ctrl,
                      hint: service.t('username_hint'),
                      icon: Icons.person_outline_rounded,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) setState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : () => Navigator.pop(dialogContext),
                            child: Text(service.t('cancel'),
                                style:
                                    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            onPressed: saving ? null : save,
                            child: saving
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.inkOn))
                                : Text(service.t('save_action'), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkOn)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _languageDialog(BuildContext context, DataService service) {
    // แสดงธงไทยสำหรับภาษาไทย และธงสหรัฐฯ สำหรับ English
    Widget flagFor(String lang) => Text(
        lang == 'ไทย' ? '🇹🇭' : '🇺🇸',
        style: const TextStyle(fontSize: 23));

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.language_rounded, color: AppColors.ink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(service.t('choose_language'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._languageOptions.map((lang) {
                  final selected = (service.currentUser?.language ?? 'ไทย') == lang;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected ? AppColors.accentBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () async {
                          await runDataAction(context, () async { await service.setLanguage(lang); });
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected ? AppColors.ink : AppColors.border,
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              flagFor(lang),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(lang,
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                        color: selected ? AppColors.ink : AppColors.textPrimary)),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.ink, size: 20)
                              else
                                Icon(Icons.circle_outlined,
                                    color: AppColors.border, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _aboutDialog(BuildContext context, DataService service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(service.t('about_title'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          service.t('about_body'),
          style: TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: Text(service.t('close'))),
        ],
      ),
    );
  }
}

/// หัวข้อพาสเทลไล่เฉดโค้งมนด้านล่าง พร้อมประกายดาวตกแต่ง — ใช้โทนเดียวกับ
/// _SkyHeader ในหน้า Home เพื่อให้หน้าเมนูดูเข้าชุดกับส่วนอื่นของแอปและน่ารักขึ้น
class _CuteMenuHeader extends StatelessWidget {
  final String title;
  const _CuteMenuHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // บวก MediaQuery.of(context).padding.top (ความสูง status bar / notch) เข้าไปกับ
    // padding บนของ header เสมอ (เหมือน _SkyHeader ในหน้า Home) เพราะหน้านี้ใช้
    // extendBodyBehindAppBar: true ทำให้เนื้อหาเลื่อนขึ้นไปอยู่ใต้ status bar/เกาะกล้อง
    // ถ้าไม่บวกส่วนนี้ ข้อความหัวข้อ "ตั้งค่าบัญชี" จะไปชนซ้อนกับนาฬิกา/แบตเตอรี่บนจอ
    final topSafeArea = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topSafeArea + 8, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentDeep.withOpacity(0.9), AppColors.accent, AppColors.bg],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 60,
            top: topSafeArea,
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white.withOpacity(0.85)),
          ),
          Positioned(
            right: 86,
            top: topSafeArea + 20,
            child: Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white.withOpacity(0.6)),
          ),
          Positioned(
            left: 8,
            top: topSafeArea + 10,
            child: Icon(Icons.favorite_rounded, size: 12, color: Colors.white.withOpacity(0.55)),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.settings_suggest_rounded, color: AppColors.accentDeep, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF3D568F)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// การ์ดโปรไฟล์พาสเทลพร้อมฟองสบู่ตกแต่งมุม — ให้ความรู้สึกนุ่มนวลน่ารักเหมือนขนม
/// เช่นเดียวกับการ์ดรายรับ/รายจ่ายในหน้า Wallet
class _ProfileCard extends StatelessWidget {
  final DataService service;
  final dynamic user;
  const _ProfileCard({required this.service, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.accentPink.withOpacity(0.18), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 34,
              bottom: -18,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: AppColors.accentDeep.withOpacity(0.12), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _AvatarPicker(service: service),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '-',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '-',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รูปโปรไฟล์ที่แตะเพื่อเปลี่ยนได้ (ถ่ายรูปใหม่ / เลือกจากคลังภาพ / ลบรูป)
///
/// อัปเดต: ลอง decode รูปจาก `service.currentUser.avatarBase64` (Base64 string
/// ที่เก็บอยู่ใน Firestore) ก่อนเป็นอันดับแรก เพราะเป็นแหล่งข้อมูลจริงที่ผูกกับบัญชี
/// และตามไปทุกเครื่องที่ล็อกอิน ถ้ายังไม่มีจะ fallback ไปที่ไฟล์แคชในเครื่อง
/// (avatarPath) แล้วค่อย fallback สุดท้ายเป็นไอคอนคน default — เดิมโค้ดจุดนี้ดูแค่
/// avatarPath (ไฟล์ในเครื่อง) อย่างเดียว ทำให้เปลี่ยนมือถือเครื่องใหม่แล้วเห็นแต่
/// ไอคอน default เสมอแม้จะเคยตั้งรูปโปรไฟล์ไว้แล้วก็ตาม
class _AvatarPicker extends StatelessWidget {
  final DataService service;
  const _AvatarPicker({required this.service});

  @override
  Widget build(BuildContext context) {
    final avatarBase64 = service.currentUser?.avatarBase64;
    final path = service.avatarPath;
    final hasLocalImage = path != null && File(path).existsSync();

    ImageProvider? avatarImage;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarBase64));
      } catch (_) {
        avatarImage = null;
      }
    }
    if (avatarImage == null && hasLocalImage) {
      avatarImage = FileImage(File(path));
    }

    return GestureDetector(
      onTap: () => _showPickerSheet(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.accentDeep, AppColors.accentPink],
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.bg,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.accentBg,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(Icons.person, size: 30, color: AppColors.ink)
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.accentDeep,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
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
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        final hasImage = service.avatarPath != null || service.currentUser?.avatarBase64 != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.accentBg, shape: BoxShape.circle),
                    child: Icon(Icons.photo_camera_outlined, color: AppColors.accentDeep, size: 18),
                  ),
                  title: Text(service.t('take_photo'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await runDataAction(context, () async { await service.pickAvatar(fromCamera: true); });
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.accentAltBg, shape: BoxShape.circle),
                    child: Icon(Icons.photo_library_outlined, color: const Color(0xFFC79A3B), size: 18),
                  ),
                  title: Text(service.t('choose_from_gallery'), style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await runDataAction(context, () async { await service.pickAvatar(fromCamera: false); });
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                      child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                    ),
                    title: Text(service.t('remove_photo'), style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await runDataAction(context, () async { await service.removeAvatar(); });
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