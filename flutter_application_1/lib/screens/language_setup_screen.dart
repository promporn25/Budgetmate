import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/app_strings.dart';

const List<String> _languages = ['ไทย', 'English'];
const List<String> _currencies = ['THB', 'USD', 'EUR', 'JPY', 'GBP'];

/// หน้า "My wallet" (3.4.2) - ตั้งค่าภาษาและสกุลเงินเริ่มต้นของแอป
class LanguageSetupScreen extends StatefulWidget {
  const LanguageSetupScreen({super.key});

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  String _language = 'ไทย';
  String _currency = 'THB';
  bool _saving = false;
  bool _loading = true;
  String? _error;

  String _t(String key) => AppStrings.of(_language)[key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final service = context.read<DataService>();
    try {
      final defaults = await service.getDefaultPreferences();
      if (!mounted) return;
      final language = service.currentUser?.language ?? defaults['language'];
      final currency = service.currentUser?.currency ?? defaults['currency'];
      setState(() {
        _language = _languages.contains(language) ? language! : 'ไทย';
        _currency = _currencies.contains(currency) ? currency! : 'THB';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _next() async {
    if (_saving || _loading) return;
    setState(() { _saving = true; _error = null; });
    final service = context.read<DataService>();
    try {
      await service.completeSetup(language: _language, currency: _currency);
      if (!mounted) return;
      Navigator.pushReplacement(context, noAnimationRoute(
        service.currentUser == null ? const LoginScreen() : const HomeScreen()));
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = '${_t('save_failed')}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HeaderIconBadge(icon: Icons.tune_rounded),
                const SizedBox(height: 20),
                Text(_t('setup_title'),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(_t('setup_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 40),
                _dropdownRow(
                  icon: Icons.language_rounded,
                  label: _t('language_label'),
                  value: _language,
                  items: _languages,
                  onChanged: (v) {
                    if (v != null) setState(() => _language = v);
                  },
                ),
                const SizedBox(height: 16),
                _dropdownRow(
                  icon: Icons.payments_outlined,
                  label: _t('currency_label'),
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: _t('next'),
                    loading: _saving || _loading,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownRow({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                dropdownColor: AppColors.bg,
                style: TextStyle(color: AppColors.textPrimary),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _saving || _loading ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}