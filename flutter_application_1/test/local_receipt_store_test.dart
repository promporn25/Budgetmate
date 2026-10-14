import 'dart:io';
import 'dart:typed_data';
import 'package:budgetmate/services/local_receipt_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalReceiptStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt-store-test-');
    store = LocalReceiptStore(directory: () async => root);
  });
  tearDown(() async => root.delete(recursive: true));

  test('persists bytes locally with distinct account namespaces', () async {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final first = await store.save(bytes, owner: 'user-a', isPng: true);
    final second = await store.save(bytes, owner: 'user-b', isPng: true);
    expect(first.split('/').first, isNot(second.split('/').first));
    expect(first, startsWith('local-receipt:'));
    final files =
        await root.list(recursive: true).where((f) => f is File).toList();
    expect(files, hasLength(2));
    expect(await (files.first as File).readAsBytes(), bytes);
    await store.delete(first);
    expect(await root.list(recursive: true).where((f) => f is File).length, 1);
    await store.delete(first); // Retry cleanup is safe.
    await store.delete(second);
  });

  test('cleanup cannot delete arbitrary paths or cloud receipts', () async {
    for (final marker in [
      'local-receipt:../../outside',
      '/tmp/file',
      'receipts/user/id'
    ]) {
      await expectLater(store.delete(marker), throwsArgumentError);
    }
  });
}
