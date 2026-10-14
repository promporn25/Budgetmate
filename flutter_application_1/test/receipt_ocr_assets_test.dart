import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline Thai and English models are bundled, not download error pages',
      () async {
    final config =
        jsonDecode(await File('assets/tessdata_config.json').readAsString());
    expect(
        config['files'], containsAll(['tha.traineddata', 'eng.traineddata']));
    for (final name in config['files']) {
      final file = File('assets/tessdata/$name');
      expect(await file.length(), greaterThan(1000000));
      final handle = await file.open();
      final header = await handle.read(4);
      await handle.close();
      // Tesseract traineddata starts with a little-endian component count.
      expect(header, [24, 0, 0, 0]);
    }
  });
}
