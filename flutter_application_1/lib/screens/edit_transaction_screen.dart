import '../widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/data_service.dart';
import '../widgets/transaction_sheet_style.dart';
import '../widgets/period_selector.dart' show PastelCalendarDialog;
import '../widgets/pastel_artwork.dart';
import '../widgets/amount_keypad.dart';

Future<bool?> showEditTransactionSheet(
        BuildContext context, TransactionModel transaction,
        {bool duplicate = false}) =>
    showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black38,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => EditTransactionScreen(
            transaction: transaction, asSheet: true, duplicate: duplicate));

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen(
      {super.key,
      required this.transaction,
      this.asSheet = false,
      this.duplicate = false});
  final TransactionModel transaction;
  final bool asSheet;
  final bool duplicate;
  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late final _amount =
      TextEditingController(text: widget.transaction.amount.toString());
  late final _note = TextEditingController(text: widget.transaction.note ?? '');
  late CategoryType _type = widget.transaction.type;
  late CategoryModel? _category = widget.transaction.category;
  late DateTime _date =
      widget.duplicate ? DateTime.now() : widget.transaction.date;
  bool _saving = false;
  bool _showAmountKeypad = false;
  bool _showNote = true;
  String? _error;
  String _t(String th, String en) =>
      context.read<DataService>().currentLanguage == 'English' ? en : th;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _error = _t('กรอกจำนวนเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.duplicate) {
        final error = await service.addTransaction(
            type: _type,
            amount: amount,
            category: _category!,
            date: _date,
            note: _note.text.trim());
        if (error != null) throw StateError(error);
      } else {
        await service.editTransaction(widget.transaction.id,
            type: _type,
            amount: amount,
            category: _category,
            date: _date,
            note: _note.text.trim());
      }
      if (!mounted) return;
      showSuccessNotice(context,
          widget.duplicate ? 'transaction_duplicated' : 'transaction_updated');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = service.t('save_failed');
        });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDialog<DateTime>(
        context: context,
        builder: (_) => PastelCalendarDialog(
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2200),
            isThai: context.read<DataService>().currentLanguage != 'English'));
    if (date != null && mounted)
      setState(() => _date = DateTime(date.year, date.month, date.day,
          _date.hour, _date.minute, _date.second));
  }

  InputDecoration _field(String hint) => InputDecoration(
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        hintText: hint,
        hintStyle: const TextStyle(color: TransactionSheetColors.muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: TransactionSheetColors.accent, width: 2)),
      );

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: TransactionSheetColors.muted, fontSize: 14)));

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(_type);
    if (_category != null && !categories.any((c) => c.id == _category!.id))
      categories.add(_category!);
    final content = TransactionSheetFrame(
      title: widget.duplicate
          ? _t('ทำซ้ำรายการ', 'Duplicate transaction')
          : _t('แก้ไขรายการ', 'Edit transaction'),
      busy: _saving,
      actions: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_showAmountKeypad && MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            AmountKeypad(controller: _amount),
            const SizedBox(height: 8),
          ],
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  style: transactionActionStyle(primary: true),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.duplicate
                          ? _t('บันทึกรายการใหม่', 'Save new transaction')
                          : service.t('save')))),
      ]),
      child: AbsorbPointer(
          absorbing: _saving,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const PastelArtwork(categoryNumber: 14, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(service.t('wallet_title'),
                                style: const TextStyle(
                                    color: TransactionSheetColors.ink,
                                    fontWeight: FontWeight.w700)))
                      ]))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: TransactionSheetColors.muted, size: 18)),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      key: ValueKey(_type),
                      initialValue: _category?.id,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 320,
                      decoration: _field(_t('หมวดหมู่', 'Category')).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10)),
                      items: categories
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Row(children: [
                                CategoryIcon(category: c, size: 27),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(service.categoryName(c),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: TransactionSheetColors.ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)))
                              ])))
                          .toList(),
                      onChanged: (id) => setState(() => _category =
                          categories.firstWhere((c) => c.id == id)))),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<CategoryType>(
                segments: [
                  ButtonSegment(
                      value: CategoryType.income,
                      label: Text(service.t('income'))),
                  ButtonSegment(
                      value: CategoryType.expense,
                      label: Text(service.t('expense')))
                ],
                selected: {
                  _type
                },
                style: ButtonStyle(
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected)
                            ? TransactionSheetColors.accent
                            : Colors.white),
                    foregroundColor: const WidgetStatePropertyAll(
                        TransactionSheetColors.ink)),
                onSelectionChanged: (value) => setState(() {
                      _type = value.single;
                      if (_category?.type != _type) _category = null;
                    })),
            _label(_t('จำนวนเงิน', 'Amount')),
            TextField(
                controller: _amount,
                readOnly: true,
                showCursor: true,
                keyboardType: TextInputType.none,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _amount.selection = TextSelection(
                      baseOffset: 0, extentOffset: _amount.text.length);
                  setState(() => _showAmountKeypad = true);
                },
                style: const TextStyle(
                    color: TransactionSheetColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                decoration: _field('0.00')
                    .copyWith(suffixText: service.currentCurrency)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 10, children: [
              ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined,
                      color: TransactionSheetColors.muted, size: 20),
                  label: Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
                  onPressed: _pickDate,
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle:
                      const TextStyle(color: TransactionSheetColors.muted)),
              ActionChip(
                  avatar: const Icon(Icons.edit_note_rounded,
                      color: TransactionSheetColors.muted, size: 20),
                  label: Text(_t('บันทึกช่วยจำ', 'Note')),
                  onPressed: () => setState(() => _showNote = !_showNote),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle:
                      const TextStyle(color: TransactionSheetColors.muted)),
            ]),
            if (_showNote) ...[
              _label(_t('บันทึกช่วยจำ', 'Note')),
              TextField(
                  controller: _note,
                  onTap: () => setState(() => _showAmountKeypad = false),
                  minLines: 1,
                  maxLines: 6,
                  decoration: _field(_t('เพิ่มข้อความช่วยจำ…', 'Add a note…')),
                  style: const TextStyle(
                      color: TransactionSheetColors.ink, fontSize: 14)),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: TransactionSheetColors.red))),
            const SizedBox(height: 6),
          ])),
    );
    return PopScope(
        canPop: !_saving,
        child: widget.asSheet
            ? content
            : Scaffold(
                // The sheet frame owns keyboard insets, including in page mode.
                resizeToAvoidBottomInset: false,
                backgroundColor: TransactionSheetColors.background,
                body:
                    Align(alignment: Alignment.bottomCenter, child: content)));
  }
}
