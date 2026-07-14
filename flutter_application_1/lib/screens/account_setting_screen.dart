import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';

/// หน้า Account Setting (3.4.5) - จัดการข้อมูลบัญชีผู้ใช้งานและการตั้งค่าแอป
class AccountSettingScreen extends StatelessWidget {
  const AccountSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final user = service.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Setting')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(user?.email ?? '-', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
          _tile('Manage Profile', onTap: () => _editNameDialog(context, service)),
          _tile('Password & Security'),
          _tile('Language', trailing: user?.language ?? 'ไทย'),
          const SizedBox(height: 16),
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
          _tile('About Us'),
          _tile('Theme', trailing: 'Light'),
          _tile('Success Notes', trailing: 'รับทราบแล้ว'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () {
                service.logout();
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false);
              },
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _tile(String title, {String? trailing, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title),
        trailing: trailing != null
            ? Text(trailing, style: const TextStyle(color: Colors.grey))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _editNameDialog(BuildContext context, DataService service) {
    final ctrl = TextEditingController(text: service.currentUser?.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('แก้ไขชื่อผู้ใช้'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () {
              service.updateProfile(name: ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
