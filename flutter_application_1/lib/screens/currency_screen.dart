import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});
  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}
class _CurrencyScreenState extends State<CurrencyScreen> {
  String? selected;
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final english = service.currentLanguage == 'English';
    return Scaffold(
      appBar: AppBar(title: Text(service.t('currency_label'))),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        DropdownButtonFormField<String>(
          initialValue: selected ?? service.currentCurrency,
          decoration: InputDecoration(labelText: service.t('currency_label')),
          items: DataService.supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: saving ? null : (value) => setState(() => selected = value),
        ),
        const SizedBox(height: 20),
        Text(english ? 'New entries use the selected currency. Existing entries keep their original currency. Wallet, history and goals show the selected currency only; switch back to view earlier entries.'
          : 'รายการใหม่บันทึกตามสกุลเงินที่เลือก รายการเดิมคงสกุลเงินเดิม กระเป๋า ประวัติ และเป้าหมายแสดงเฉพาะสกุลเงินที่เลือก เปลี่ยนกลับเพื่อดูรายการเดิมได้'),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 20),
        FilledButton(onPressed: saving ? null : () async {
          setState(() { saving = true; error = null; });
          try {
            await service.setCurrency(selected ?? service.currentCurrency);
            if (context.mounted) Navigator.pop(context);
          } catch (e) { if (mounted) setState(() { saving = false; error = '$e'; }); }
        }, child: Text(saving ? (english ? 'Saving…' : 'กำลังบันทึก…') : service.t('save'))),
      ]),
    );
  }
}
