import '../widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/pastel_artwork.dart';
import '../widgets/transaction_sheet_style.dart';
import 'edit_transaction_screen.dart';

enum _Action { edit, duplicate, delete }

Future<void> showTransactionDetails(
    BuildContext context, TransactionModel transaction) async {
  final service = context.read<DataService>();
  final action = await showModalBottomSheet<_Action>(
      context: context,
      isScrollControlled: true,
        useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _TransactionDetails(transaction: transaction));
  if (action == null || !context.mounted) return;
  if (action != _Action.delete) {
    await showEditTransactionSheet(context, transaction,
        duplicate: action == _Action.duplicate);
    return;
  }
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            backgroundColor: TransactionSheetColors.background,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            titlePadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            icon: Center(
                child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFEAE8), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: TransactionSheetColors.red, size: 25))),
            title: Text(
                service.currentLanguage == 'English'
                    ? 'Delete transaction?'
                    : 'ลบรายการนี้ใช่ไหม?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: TransactionSheetColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  service.currentLanguage == 'English'
                      ? 'This transaction will be removed from your history.'
                      : 'รายการนี้จะถูกนำออกจากประวัติ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: TransactionSheetColors.muted)),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    CategoryIcon(category: transaction.category, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(service.categoryName(transaction.category),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: TransactionSheetColors.ink)),
                          const SizedBox(height: 4),
                          Text(service.formatMoney(transaction.amount),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TransactionSheetColors.ink)),
                        ])),
                  ])),
            ]),
            actions: [
              Row(children: [
                Expanded(
                    child: TextButton(
                        style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: TransactionSheetColors.ink,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(service.t('cancel')))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextButton(
                        style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEAE8),
                            foregroundColor: const Color(0xFFB74745),
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(service.t('delete')))),
              ])
            ],
          ));
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteTransaction(transaction.id);
    if (context.mounted) showSuccessNotice(context, 'transaction_deleted');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(service.t('save_failed'))));
  }
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    String t(String th, String en) =>
        service.currentLanguage == 'English' ? en : th;
    final isIncome = transaction.type == CategoryType.income;
    final amountColor =
        isIncome ? TransactionSheetColors.green : TransactionSheetColors.red;
    Widget line(String label, String value, {bool amount = false}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: TransactionSheetColors.muted, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color:
                          amount ? amountColor : TransactionSheetColors.muted,
                      fontSize: amount ? 23 : 14,
                      fontWeight: amount ? FontWeight.w700 : FontWeight.w500))),
        ]));
    return TransactionSheetFrame(
      title: t('รายละเอียด', 'Details'),
      actions: Row(children: [
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(destructive: true),
                onPressed: () => Navigator.pop(context, _Action.delete),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(service.t('delete')))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(),
                onPressed: () => Navigator.pop(context, _Action.duplicate),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(t('ทำซ้ำ', 'Copy')))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                style: transactionActionStyle(primary: true),
                onPressed: () => Navigator.pop(context, _Action.edit),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(service.t('edit')))),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        transactionWhiteCard(
            child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF8FB), shape: BoxShape.circle),
              child: CategoryIcon(category: transaction.category, size: 38)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.categoryName(transaction.category),
                    style: const TextStyle(
                        color: TransactionSheetColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(
                    t('หมวดหมู่ ', 'Category: ') +
                        service.categoryName(transaction.category),
                    style: const TextStyle(
                        color: TransactionSheetColors.muted, fontSize: 14)),
              ])),
        ])),
        const SizedBox(height: 10),
        transactionWhiteCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('กระเป๋าเงิน', 'Wallet'),
              style: const TextStyle(
                  color: TransactionSheetColors.muted, fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: [
            const PastelArtwork(categoryNumber: 14, size: 40),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'BUDGETMATE - ${transaction.currency ?? service.currentCurrency}',
                    style: const TextStyle(
                        color: TransactionSheetColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)))
          ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFE3EBFB))),
          Text(t('บันทึกช่วยจำ', 'Note'),
              style: const TextStyle(
                  color: TransactionSheetColors.muted, fontSize: 14)),
          const SizedBox(height: 8),
          Text(transaction.note?.isNotEmpty == true ? transaction.note! : '—',
              style: const TextStyle(
                  color: TransactionSheetColors.ink, fontSize: 14)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFE3EBFB))),
          Text(t('รายละเอียด', 'Details'),
              style: const TextStyle(
                  color: TransactionSheetColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          line(t('วันที่ทำรายการ', 'Date'),
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)),
          line(t('ประเภทรายการ', 'Type'),
              service.t(isIncome ? 'income' : 'expense')),
          line(
              t('จำนวนเงิน', 'Amount'), service.formatMoney(transaction.amount),
              amount: true),
        ])),
      ]),
    );
  }
}
