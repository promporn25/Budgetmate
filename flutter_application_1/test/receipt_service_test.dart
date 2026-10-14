import 'dart:async';
import 'dart:typed_data';
import 'package:budgetmate/services/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-receipt text cannot proceed to saving', () async {
    final service = ReceiptService(readText: (_) async => 'Holiday photo 2026');
    await expectLater(service.scan(Uint8List(0)), throwsFormatException);
  });
  test('unresponsive scanner times out instead of waiting indefinitely',
      () async {
    final service = ReceiptService(
        readText: (_) => Completer<String>().future,
        timeout: const Duration(milliseconds: 10));
    await expectLater(
        service.scan(Uint8List(0)), throwsA(isA<TimeoutException>()));
  });
  test('valid receipt and transfer slip return a reviewable amount', () async {
    for (final text in [
      'SHOP\nGrand total 250.00',
      'โอนเงินสำเร็จ\nจำนวนเงิน 1,200.00 บาท'
    ]) {
      final result =
          await ReceiptService(readText: (_) async => text).scan(Uint8List(0));
      expect(result.amount, text.startsWith('SHOP') ? 250 : 1200);
    }
  });
}
