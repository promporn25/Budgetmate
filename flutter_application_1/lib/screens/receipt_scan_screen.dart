import '../widgets/success_notice.dart';
import 'package:flutter/services.dart';
import '../services/local_receipt_store.dart';
import '../widgets/receipt_scan_error_dialog.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/receipt_category_picker.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/data_service.dart';
import '../services/receipt_service.dart';
import '../widgets/pastel_artwork.dart';
import 'app_theme.dart';
import 'history_screen.dart'; // ปรับชื่อไฟล์/คลาสให้ตรงกับโปรเจกต์

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});
  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Uint8List? _image;
  String _contentType = 'image/jpeg';
  DateTime _date = DateTime.now();
  CategoryModel? _category;
  String? _localReceiptPath;
  String? _currency;
  String? _owner;
  String? _message;
  bool _busy = false;
  bool _scanSucceeded = false;
  bool get _thai => context.read<DataService>().currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      final bytes = await file.readAsBytes();
      final String contentType;
      if (bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff) {
        contentType = 'image/jpeg';
      } else if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        contentType = 'image/png';
      } else {
        if (mounted) {
          setState(() => _message = _t('กรุณาเลือกรูป JPG หรือ PNG',
              'Please select a JPG or PNG image.'));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _scanSucceeded = false;
        _image = bytes;
        _contentType = contentType;
        _localReceiptPath = null;
        _currency = context.read<DataService>().currentCurrency;
        _owner = FirebaseAuth.instance.currentUser?.uid;
        _amount.clear();
        _note.clear();
        _category = null;
        _date = DateTime.now();
      });
      await _scan();
    } catch (_) {
      if (mounted) {
        setState(() => _message = _t(
            'เปิดรูปไม่ได้ กรุณาอนุญาตกล้อง/คลังรูป และใช้รูปไม่เกิน 5 MB',
            'Cannot open image. Check permissions and use an image under 5 MB.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    try {
      final draft = await ReceiptService().scan(_image!);
      if (!mounted) return;
      setState(() {
        _scanSucceeded = true;
        _amount.text = draft.amount?.toStringAsFixed(2) ?? '';
        _note.text = draft.merchant;
        _date = draft.date ?? DateTime.now();
        _message = _t(
            'ตรวจยอดเงิน สกุลเงิน และวันที่ แล้วเลือกหมวดหมู่ก่อนบันทึก หากไม่พบวันที่จะใช้วันนี้',
            'Review amount, currency and date, then choose a category. Missing dates default to today.');
      });
    } catch (error) {
      if (!mounted) return;
      final serviceError = error is PlatformException ||
          error is MissingPluginException ||
          error is UnsupportedError;
      final timedOut = error is TimeoutException;
      final message = timedOut
          ? _t(
              'อ่านรูปใช้เวลานานเกินไป กรุณาลองใช้รูปที่ครอปเฉพาะสลิปหรือใบเสร็จ',
              'Reading took too long. Try a photo cropped to the slip or receipt.')
          : error is StateError
              ? _t('ตัวอ่านรูปยังทำงานอยู่ กรุณารอสักครู่แล้วลองใหม่',
                  'The previous scan is still finishing. Please wait and retry.')
              : error is UnsupportedError
                  ? _t(
                      'การสแกนออฟไลน์รองรับ Android และ iPhone กรุณาเปิดแอปบนมือถือ',
                      'Offline scanning supports Android and iPhone. Please use the mobile app.')
                  : serviceError
                      ? _t(
                          'ตัวอ่านรูปบนเครื่องไม่พร้อมใช้งาน กรุณาปิดแล้วเปิดแอปใหม่ หากยังไม่ได้ให้ติดตั้งแอปรุ่นล่าสุด',
                          'The on-device scanner is unavailable. Restart the app or install the latest version.')
                      : _t(
                          'อ่านยอดเงินจากรูปนี้ไม่ได้ กรุณาใช้ภาพใบเสร็จหรือสลิปที่ชัดเจน แล้วลองใหม่',
                          'Could not read a total. Choose a clear receipt or payment slip and try again.');
      setState(() {
        _scanSucceeded = false;
        _message = message;
      });
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.ink.withValues(alpha: 0.28),
        builder: (_) => ReceiptScanErrorDialog(
            isThai: _thai,
            timedOut: timedOut,
            serviceUnavailable: serviceError,
            message: message),
      );
    }
  }

  Future<void> _save() async {
    if (_busy || !_scanSucceeded) return;
    final service = context.read<DataService>();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _category == null) {
      setState(() => _message = _t(
          'กรุณากรอกยอดเงินที่มากกว่า 0 และเลือกหมวดหมู่',
          'Enter a positive amount and choose a category.'));
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != _owner || service.currentCurrency != _currency) {
      setState(() => _message = _t('บัญชีหรือสกุลเงินเปลี่ยน กรุณาเลือกรูปใหม่',
          'Account or currency changed. Select the image again.'));
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var saved = false;
    final receiptStore = LocalReceiptStore();
    try {
      _localReceiptPath ??= await receiptStore.save(_image!,
          owner: uid, isPng: _contentType == 'image/png');

      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          service.currentCurrency != _currency) {
        throw StateError('Account or currency changed');
      }
      final error = await service.addTransaction(
          type: CategoryType.expense,
          amount: amount,
          category: _category!,
          date: _date,
          note: _note.text.trim(),
          receiptPath: _localReceiptPath);
      saved = error == null;
      if (!mounted) return;
      if (error != null) {
        setState(() => _message = error);
        return;
      }
      showSuccessNotice(context, 'transaction_saved');
      // บันทึกสำเร็จ → ไปหน้าประวัติ (แทนที่หน้าสแกน กดย้อนกลับแล้วไม่วนกลับมาหน้าสแกน)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HistoryScreen()),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = _t(
            'บันทึกไม่สำเร็จ ตรวจพื้นที่ว่างและการเชื่อมต่อ แล้วลองอีกครั้ง ข้อมูลยังอยู่',
            'Could not save. Check free storage and your connection, then retry. Your details are retained.'));
      }
    } finally {
      if (!saved && _localReceiptPath != null) {
        final orphan = _localReceiptPath!;
        _localReceiptPath = null;
        try {
          await receiptStore.delete(orphan);
        } catch (_) {
          // Cleanup failure must not hide the original save error.
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  BoxDecoration _cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      );

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 21, color: AppColors.ink),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.ink, width: 1.5)),
      );

  Widget _pickButton(
      {required ImageSource source,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _busy ? null : () => _pick(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: AppColors.ink, size: 27)),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _step(String number, String label, bool active) => Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: active ? AppColors.ink : AppColors.surface,
                  shape: BoxShape.circle),
              child: Text(number,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          active ? AppColors.card : AppColors.textSecondary))),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color:
                          active ? AppColors.ink : AppColors.textSecondary))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DataService>();
    final categories = service.categoriesByType(CategoryType.expense);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: AbsorbPointer(
          absorbing: _busy,
          child: Column(children: [
            AppHeader(title: _t('สลิป / ใบเสร็จ', 'Slip / receipt')),
            Expanded(
                child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Center(
                          child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                _step('1', _t('เลือกรูป', 'Choose'),
                                    _image == null),
                                Icon(Icons.chevron_right_rounded,
                                    size: 17, color: AppColors.textSecondary),
                                _step('2', _t('ตรวจข้อมูล', 'Review'),
                                    _scanSucceeded),
                                Icon(Icons.chevron_right_rounded,
                                    size: 17, color: AppColors.textSecondary),
                                _step('3', _t('บันทึก', 'Save'), false),
                              ]),
                              const SizedBox(height: 16),
                              Container(
                                decoration: _cardDecoration(),
                                padding: const EdgeInsets.all(12),
                                child: Column(children: [
                                  if (_image == null) ...[
                                    SizedBox(
                                        height: 88,
                                        width: 136,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                  width: 80,
                                                  height: 76,
                                                  decoration: BoxDecoration(
                                                      color: AppColors.accentBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              34))),
                                              const _ReceiptArtwork(),
                                              Positioned(
                                                  top: 5,
                                                  right: 14,
                                                  child: Icon(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      color:
                                                          AppColors.accentPink,
                                                      size: 26)),
                                              Positioned(
                                                  bottom: 10,
                                                  left: 14,
                                                  child: Icon(
                                                      Icons.favorite_rounded,
                                                      color:
                                                          AppColors.accentPink,
                                                      size: 18)),
                                            ])),
                                    const SizedBox(height: 12),
                                    Text(
                                        _t('เพิ่มรายจ่ายจากสลิปธนาคาร',
                                            'Add an expense from a bank slip'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                    const SizedBox(height: 8),
                                    Text(
                                        _t('เลือกรูปสลิปธนาคารหรือใบเสร็จ เพื่ออ่านยอดเงิน',
                                            'Choose a bank slip or receipt to read the amount'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary)),
                                  ] else ...[
                                    Row(children: [
                                      Icon(Icons.receipt_long_rounded,
                                          color: AppColors.ink, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              _t('สลิป / ใบเสร็จของคุณ',
                                                  'Your slip / receipt'),
                                              style: AppTextStyles.heading)),
                                      Icon(Icons.favorite_rounded,
                                          color: AppColors.accentPink,
                                          size: 18),
                                    ]),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                            width: double.infinity,
                                            color: AppColors.surface,
                                            child: Image.memory(_image!,
                                                height: 240,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            36),
                                                    child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        color: AppColors
                                                            .textSecondary))))),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: _pickButton(
                                                source: ImageSource.gallery,
                                                icon: Icons
                                                    .add_photo_alternate_outlined,
                                                title: _t(
                                                    _image == null
                                                        ? 'เลือกรูป'
                                                        : 'เปลี่ยนรูป',
                                                    _image == null
                                                        ? 'Choose photo'
                                                        : 'Change photo'),
                                                subtitle: _t('จากคลังรูปของคุณ',
                                                    'From your gallery'),
                                                color: AppColors.surfaceAlt)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: _pickButton(
                                                source: ImageSource.camera,
                                                icon: Icons.camera_alt_outlined,
                                                title: _t(
                                                    'ถ่ายรูป', 'Take a photo'),
                                                subtitle: _t(
                                                    'ถ่ายสลิป / ใบเสร็จ',
                                                    'Capture a slip or receipt'),
                                                color: AppColors.accentBg)),
                                      ]),
                                  const SizedBox(height: 12),
                                  Text(
                                      'JPG / PNG · ${_t('ไม่เกิน 5 MB', 'Up to 5 MB')}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ]),
                              ),
                              if (_busy && _message == null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: _cardDecoration(
                                            color: AppColors.accentBg),
                                        child: Row(children: [
                                          SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: AppColors.ink)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Text(
                                                  _t('กำลังดำเนินการ รอสักครู่นะ…',
                                                      'Working on it, one moment…'),
                                                  style: TextStyle(
                                                      color: AppColors.ink,
                                                      fontSize: 14))),
                                        ]))),
                              ],
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: _cardDecoration(
                                            color: AppColors.accentAltBg),
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.info_outline_rounded,
                                                  color: AppColors.ink,
                                                  size: 21),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(_message!,
                                                      key: const Key(
                                                          'receipt-message'),
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          height: 1.6,
                                                          color: AppColors
                                                              .textPrimary))),
                                            ]))),
                              ],
                              if (_image != null && _scanSucceeded) ...[
                                const SizedBox(height: 16),
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: _cardDecoration(),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              _t('เช็กอีกนิด ก่อนบันทึก',
                                                  'A quick check before saving'),
                                              style: AppTextStyles.heading),
                                          const SizedBox(height: 6),
                                          Text(
                                              _t('ตรวจยอดเงิน ชื่อผู้รับ และวันที่ให้ตรงกับรูป',
                                                  'Check the amount, recipient and date against your image'),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary)),
                                          const SizedBox(height: 16),
                                          TextField(
                                              controller: _amount,
                                              readOnly: true,
                                              keyboardType: TextInputType.none,
                                              onTap: () => showAmountKeypad(
                                                  context,
                                                  controller: _amount,
                                                  title: _t(
                                                      'ยอดเงิน ($_currency)',
                                                      'Amount ($_currency)')),
                                              decoration: _fieldDecoration(
                                                  _t('ยอดเงิน ($_currency)',
                                                      'Amount ($_currency)'),
                                                  Icons.payments_outlined)),
                                          const SizedBox(height: 14),
                                          TextField(
                                              controller: _note,
                                              decoration: _fieldDecoration(
                                                  _t('ร้านค้า / ผู้รับ / หมายเหตุ',
                                                      'Merchant / recipient / note'),
                                                  Icons.storefront_outlined)),
                                          const SizedBox(height: 14),
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: _busy
                                                ? null
                                                : () async {
                                                    final selected =
                                                        await showReceiptCategoryPicker(
                                                      context,
                                                      categories: categories,
                                                      selectedId: _category?.id,
                                                      thai: _thai,
                                                    );
                                                    if (selected != null &&
                                                        mounted) {
                                                      setState(() =>
                                                          _category = selected);
                                                    }
                                                  },
                                            child: InputDecorator(
                                              decoration: _fieldDecoration(
                                                  _t('หมวดรายจ่าย',
                                                      'Expense category'),
                                                  Icons.grid_view_rounded),
                                              child: Row(children: [
                                                if (_category != null) ...[
                                                  CategoryIcon(
                                                      category: _category!,
                                                      size: 30),
                                                  const SizedBox(width: 10),
                                                ],
                                                Expanded(
                                                    child: Text(
                                                        _category?.name ??
                                                            _t('เลือกหมวดหมู่',
                                                                'Choose a category'),
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textPrimary))),
                                                Icon(Icons.expand_more_rounded,
                                                    color: AppColors.ink),
                                              ]),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Material(
                                              color: AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: ListTile(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(
                                                          16)),
                                                  leading: Icon(Icons.calendar_month_rounded,
                                                      color: AppColors.ink),
                                                  title: Text(_t('วันที่ทำรายการ', 'Transaction date'),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .textSecondary)),
                                                  subtitle:
                                                      Text(DateFormat('dd/MM/yyyy').format(_date),
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .textPrimary,
                                                              fontSize: 14)),
                                                  trailing: Icon(Icons.edit_outlined,
                                                      color: AppColors.ink,
                                                      size: 19),
                                                  onTap: () async {
                                                    final date =
                                                        await showDatePicker(
                                                            context: context,
                                                            initialDate: _date,
                                                            firstDate:
                                                                DateTime(2000),
                                                            lastDate:
                                                                DateTime(2200));
                                                    if (date != null &&
                                                        mounted) {
                                                      setState(
                                                          () => _date = date);
                                                    }
                                                  })),
                                          const SizedBox(height: 18),
                                          FilledButton.icon(
                                              onPressed: _busy ? null : _save,
                                              style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.accentDeep,
                                                  foregroundColor: Colors.white,
                                                  minimumSize:
                                                      const Size.fromHeight(54),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18))),
                                              icon: const Icon(Icons.check_circle_outline_rounded,
                                                  size: 21),
                                              label: Text(
                                                  _t('ยืนยันและบันทึกรายจ่าย',
                                                      'Confirm and save expense'),
                                                  textAlign: TextAlign.center)),
                                        ])),
                              ] else ...[
                                const SizedBox(height: 16),
                                Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: _cardDecoration(
                                        color: AppColors.accentAltBg),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.lightbulb_outline_rounded,
                                              color: AppColors.ink, size: 25),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    _t('รูปชัด อ่านง่ายกว่า',
                                                        'A clear photo works best'),
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 14)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    _t('ใช้รูปสลิปจากแอปธนาคาร หรือใบเสร็จที่เห็นยอดเงินครบ\nวางให้ตรง และหลีกเลี่ยงแสงสะท้อน',
                                                        'Use a bank app slip or a full receipt with the amount visible. Keep it straight and avoid glare.'),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        height: 1.6,
                                                        color: AppColors.ink)),
                                              ])),
                                        ])),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                  _t('อ่านรูปบนเครื่องฟรี ไม่ส่งรูปไปบริการสแกน\nรูปแนบเก็บเฉพาะเครื่องนี้และไม่ซิงก์ข้ามเครื่อง ตรวจข้อมูลก่อนบันทึก ระบบไม่ได้ยืนยันการโอนเงินจริง',
                                      'Scanned on your device for free. Attachments stay on this device and do not sync. Review before saving. This does not verify the bank transfer.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.6,
                                      color: AppColors.textSecondary)),
                            ]),
                      )),
                    ))),
          ]),
        ),
      ),
    );
  }
}

class _ReceiptArtwork extends StatelessWidget {
  const _ReceiptArtwork();
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.10,
        child: const GoalArtwork(Icons.receipt_long, size: 60),
      );
}
