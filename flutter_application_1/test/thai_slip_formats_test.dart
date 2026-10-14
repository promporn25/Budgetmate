import 'dart:typed_data';
import 'package:budgetmate/services/receipt_parser.dart';
import 'package:budgetmate/services/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic OCR variants, not a claim of verification against every bank's app.
void main() {
  const labels = [
    'จำนวนเงิน',
    'จำนวนเงินที่โอน',
    'ยอดเงินที่โอน',
    'ยอดเงินโอน',
    'ยอดโอน',
    'ยอดเงิน',
    'ยอดชำระ',
    'จำนวนเงินที่ชำระ',
    'ยอดเงินที่ชำระ',
    'ยอดที่ชำระ',
    'ยอดเงินสุทธิ',
    'ยอดชำระสุทธิ',
    'รวมทั้งสิ้น',
    'ยอดรวม',
    'Transfer Amount',
    'Amount Transferred',
    'Payment Amount',
    'Amount Paid',
    'จำนวนเงิน / Amount',
    'Amount / จำนวนเงิน',
  ];
  for (final label in labels) {
    test('bank-independent label: $label', () async {
      for (final value in [
        '1,250.50 บาท',
        '(THB) 1,250.50',
        '๑,๒๕๐.๕๐',
        '1, 250 . 50 THB'
      ]) {
        final text =
            'ทำรายการสำเร็จ\n30 กันยายน 2569\n$label\n$value\nค่าธรรมเนียม 10.00 บาท\nยอดคงเหลือ 9,999.00 บาท';
        final draft = await ReceiptService(readText: (_) async => text)
            .scan(Uint8List(0));
        expect(draft.amount, 1250.50, reason: '$label: $value');
        expect(draft.date, DateTime(2026, 9, 30));
      }
    });
  }
  test('split currency and payment success variants', () {
    for (final header in [
      'โอนเงินสำเร็จ',
      'ชำระเงินสำเร็จ',
      'ทำรายการสำเร็จ',
      'Payment successful'
    ]) {
      for (final layout in ['บาท\n350.00', '350.00\nTHB', '฿ 350.00']) {
        expect(ReceiptDraft.fromText('$header\n$layout').amount, 350);
      }
    }
  });
  test('preserves transfer principal and does not select a same-row fee', () {
    expect(
        ReceiptDraft.fromText('จำนวนเงิน 350.00 บาท ค่าธรรมเนียม 10.00 บาท')
            .amount,
        350);
    expect(ReceiptDraft.fromText('ยอดโอน 350.00\nยอดรวม 360.00').amount, 350);
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\nค่าธรรมเนียม\nบาท\n10.00').amount,
        isNull);
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\nยอดรวมค่าธรรมเนียม\n10.00 บาท')
            .amount,
        isNull);
  });
  test('rejects conflicting amounts instead of silently taking the last', () {
    for (final text in [
      'จำนวนเงิน 100.00\nAmount 200.00',
      'Amount 100.00 Total 200.00',
      'โอนเงินสำเร็จ\n100.00 บาท\n200.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
    expect(
        ReceiptDraft.fromText('จำนวนเงิน 100.00\nAmount 100.00').amount, 100);
  });
  test('does not invent an amount from references, accounts or OCR letters',
      () {
    for (final text in [
      'โอนเงินสำเร็จ\nรหัสอ้างอิง\n350.00 THB',
      'โอนเงินสำเร็จ\nบัญชี\nTHB\n1234567',
      'จำนวนเงิน 35O.OO',
      'จำนวนเงิน -350.00',
      'จำนวนเงิน\nxxx-xxx-1234',
      'จำนวนเงิน 1,25.50',
      'รายการทดสอบ\n350.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
  });
  test('Thai, English, ISO and abbreviated years', () {
    for (final date in [
      '30 กันยายน 2569',
      '30 ก.ย. 69',
      '๓๐ ก.ย. ๒๕๖๙',
      '30ก.ย.2569',
      '30 ก. ย. 2569',
      '30 กันยายน พ.ศ. 2569',
      '30 กันยายน ค.ศ. 26',
      '30 September 2026',
      '30 Sep 26',
      '30/09/2569',
      '30-09-2026',
      '2026-09-30',
      '30 / 09 / 69',
      '30/09/26',
    ]) {
      expect(
          ReceiptDraft.fromText('ทำรายการสำเร็จ\n$date\nยอดเงิน 350.00').date,
          DateTime(2026, 9, 30),
          reason: date);
    }
  });
  test('all twelve Thai month names and invalid dates', () {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    for (var i = 0; i < months.length; i++) {
      expect(ReceiptDraft.fromText('15 ${months[i]} 2569').date,
          DateTime(2026, i + 1, 15));
    }
    for (final date in ['31 กุมภาพันธ์ 2569', '2026-13-30', '29/02/2026']) {
      expect(ReceiptDraft.fromText(date).date, isNull, reason: date);
    }
  });
  test('keeps Thai display names intact while normalizing OCR labels', () {
    final draft =
        ReceiptDraft.fromText('ร้าน อาหาร ทดสอบ\nจํา นวน เงิน 350.00');
    expect(draft.merchant, 'ร้าน อาหาร ทดสอบ');
    expect(draft.amount, 350);
  });
}
