import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/app_theme.dart';
import '../services/data_service.dart';
import '../services/password_policy.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements(
      {super.key, required this.password, required this.confirmation});
  final TextEditingController password;
  final TextEditingController confirmation;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    return AnimatedBuilder(
      animation: Listenable.merge([password, confirmation]),
      builder: (context, _) {
        final invalid = passwordValidationKey(password.text);
        Widget check(String label, bool passed) => Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(children: [
                Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color:
                        passed ? AppColors.success : AppColors.textSecondary),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: passed
                                ? AppColors.success
                                : AppColors.textSecondary))),
              ]),
            );
        final value = password.text;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.t('password_requirements'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            check(
                service.currentLanguage == 'English'
                    ? 'At least 6 characters'
                    : 'ความยาว 6 ตัวอักษรขึ้นไป',
                value.runes.length >= passwordMinLength),
            check(service.t('password_lowercase'),
                RegExp(r'[a-z]').hasMatch(value)),
            check(service.t('password_uppercase'),
                RegExp(r'[A-Z]').hasMatch(value)),
            check(
                service.t('password_digit'), RegExp(r'[0-9]').hasMatch(value)),
            check(
                service.t('password_symbol'),
                RegExp(r'[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]')
                    .hasMatch(value)),
            if (password.text.isNotEmpty)
              Text(service.t(invalid ?? 'password_valid'),
                  style: TextStyle(
                      fontSize: 12,
                      color: invalid == null
                          ? AppColors.success
                          : AppColors.danger)),
            if (confirmation.text.isNotEmpty)
              Text(
                  service.t(password.text == confirmation.text
                      ? 'password_confirmed'
                      : 'password_mismatch'),
                  style: TextStyle(
                      fontSize: 12,
                      color: password.text == confirmation.text
                          ? AppColors.success
                          : AppColors.danger)),
          ]),
        );
      },
    );
  }
}
