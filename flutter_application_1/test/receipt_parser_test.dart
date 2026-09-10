import 'package:flutter_test/flutter_test.dart';
import 'package:budgetmate/services/receipt_parser.dart';

void main() {
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
  test('empty scan has no invented fields', () {
    final draft = ReceiptDraft.fromText('');
    expect(draft.amount, isNull);
    expect(draft.date, isNull);
    expect(draft.merchant, isEmpty);
  });
}
