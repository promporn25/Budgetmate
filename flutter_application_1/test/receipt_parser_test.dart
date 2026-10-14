import 'package:flutter_test/flutter_test.dart';
import 'package:budgetmate/services/receipt_parser.dart';

void main() {
  test('MAKE selects recipient above second masked account, not heading', () {
    final draft = ReceiptDraft.fromText(
        'โอนเงินสำเร็จ make\n30 ก.ย. 2569 16:27\nพรหมพร แรงจบ\nxxx-x-x4606-x\nศิรายุ ภูกลิ่น\nxxx-x-x4570-x\nจำนวน\n350.00 บาท');
    expect(draft.merchant, 'ศิรายุ ภูกลิ่น');
    expect(draft.amount, 350);
  });
  test('recipient labels preserve spacing and ignore sender', () {
    for (final text in [
      'โอนเงินสำเร็จ\nผู้โอน: สมชาย ใจดี\nผู้รับ: สมหญิง ใจงาม\nจำนวนเงิน 350.00',
      'Transfer successful\nFrom: John Smith\nTo\nJane Smith\nAmount 350.00',
    ]) {
      expect(ReceiptDraft.fromText(text).merchant,
          text.startsWith('Transfer') ? 'Jane Smith' : 'สมหญิง ใจงาม');
    }
  });
  test('incomplete or conflicting recipient evidence stays blank', () {
    for (final text in [
      'โอนเงินสำเร็จ make\nจำนวนเงิน 350.00',
      'โอนเงินสำเร็จ\nสมชาย ใจดี\nxxx-x-x4606-x\nจำนวนเงิน 350.00',
      'โอนเงินสำเร็จ\nผู้รับ: สมชาย ใจดี\nผู้รับ: สมหญิง ใจงาม\nจำนวนเงิน 350.00',
    ]) {
      expect(ReceiptDraft.fromText(text).merchant, isEmpty);
    }
  });
  test('SCB separated amount columns and decomposed Thai OCR label', () {
    for (final text in [
      'SCB\nโอนเงินสำเร็จ\n29 ก.ย. 2569 - 22:26\nจำนวนเงิน 350.00',
      'SCB\nโอนเงินสำเร็จ\n29 ก.ย. 2569 - 22:26\nจํานวน เงิน\n350.00',
      'SCB\nโอน เงิน สําเร็จ\n29 ก.ย. 2569 - 22:26\nจํา นวน เงิน 350.00',
    ]) {
      final draft = ReceiptDraft.fromText(text);
      expect(draft.amount, 350.00, reason: text);
      expect(draft.date, DateTime(2026, 9, 29));
    }
  });
  test('uses grand total rather than subtotal, cash, change or VAT', () {
    final draft = ReceiptDraft.fromText(
        'SHOP\nSubtotal 100.00\nVAT 7.00\nGrand Total 107.00\nCash 200.00\nChange 93.00\nTotal 100.00');
    expect(draft.amount, 107);
    expect(draft.merchant, 'SHOP');
  });
  test('reads Thai digits, Buddhist date and amount on next line', () {
    final draft =
        ReceiptDraft.fromText('ร้านค้า\n๐๙/๐๙/๒๕๖๙\nรวมสุทธิ\n๑,๒๓๔.๕๐ บาท');
    expect(draft.amount, 1234.50);
    expect(draft.date, DateTime(2026, 9, 9));
  });
  test('does not guess from prices, phone numbers or invalid dates', () {
    final draft =
        ReceiptDraft.fromText('SHOP\n0812345678\n31/02/2026\nItem 999.00');
    expect(draft.amount, isNull);
    expect(draft.date, isNull);
  });
  test('does not take next line item description as a total', () {
    expect(ReceiptDraft.fromText('Total\n2 items 100.00').amount, isNull);
  });
  test('reads bank transfer labels and split currency without choosing fees',
      () {
    for (final label in [
      'จำนวนเงินที่โอน',
      'ยอดเงินที่โอน',
      'Transfer amount',
      'Amount (THB)'
    ]) {
      final draft = ReceiptDraft.fromText(
          'โอนเงินสำเร็จ\n$label\nTHB\n1,250.50\nค่าธรรมเนียม 10.00');
      expect(draft.amount, 1250.50);
    }
  });
  test('reads an unlabelled bank slip amount and abbreviated Buddhist date',
      () {
    final draft = ReceiptDraft.fromText(
        'โอนเงินสำเร็จ\n29 ก.ย. 69 - 10:30\n1,250.50 บาท\nค่าธรรมเนียม\n10.00 บาท');
    expect(draft.amount, 1250.50);
    expect(draft.date, DateTime(2026, 9, 29));
    expect(
        ReceiptDraft.fromText('โอนเงินสำเร็จ\n31 ก.พ. 2569\n100.00 บาท').date,
        isNull);
  });
  test('rejects ambiguous amounts, negative totals and reference numbers', () {
    for (final text in [
      'Transfer successful\nTHB 100.00\nTHB 200.00',
      'Total -100.00',
      'Amount\nReference 123456789012',
      'Amount\n123456789012',
      'โอนเงินสำเร็จ\nค่าธรรมเนียม\n10.00 บาท',
      'Holiday photo\n100.00 บาท',
    ]) {
      expect(ReceiptDraft.fromText(text).amount, isNull, reason: text);
    }
  });
  test('empty scan has no invented fields', () {
    final draft = ReceiptDraft.fromText('');
    expect(draft.amount, isNull);
    expect(draft.date, isNull);
    expect(draft.merchant, isEmpty);
  });
}
