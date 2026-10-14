import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'receipt_parser.dart';

class ReceiptService {
  ReceiptService(
      {Future<String> Function(Uint8List)? readText,
      this.timeout = const Duration(seconds: 55)})
      : _readText = readText ?? _localRead;
  final Future<String> Function(Uint8List) _readText;
  final Duration timeout;

  static bool _nativeBusy = false;

  static Future<String> _localRead(Uint8List bytes) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError('Offline scanning requires Android or iOS');
    }
    if (_nativeBusy) {
      throw StateError('The previous native scan is still finishing');
    }
    _nativeBusy = true;
    try {
      String? appleText;
      if (Platform.isIOS) {
        try {
          appleText = await const MethodChannel('budgetmate/receipt_ocr')
              .invokeMethod<String>('readText', bytes);
          if (appleText != null &&
              ReceiptDraft.fromText(appleText).amount != null) {
            return appleText;
          }
        } on PlatformException {
          // Older systems and native errors can still use bundled Tesseract.
        } on MissingPluginException {
          // A full native rebuild registers the Apple OCR channel.
        }
      }
      final root = await getTemporaryDirectory();
      final directory =
          await Directory('${root.path}/receipt-ocr-').createTemp();
      final image = File('${directory.path}/receipt');
      try {
        await image.writeAsBytes(bytes, flush: true);
        final text = await FlutterTesseractOcr.extractText(image.path,
            language: 'tha+eng', args: {'psm': '4'});
        if (ReceiptDraft.fromText(text).amount != null) return text;
        return appleText ?? text;
      } finally {
        // Keep the input until native OCR completes, even if scan() times out.
        await directory.delete(recursive: true);
      }
    } finally {
      _nativeBusy = false;
    }
  }

  Future<ReceiptDraft> scan(Uint8List bytes) async {
    final text = await _readText(bytes).timeout(timeout);
    final draft = ReceiptDraft.fromText(text);
    if (draft.amount == null) {
      throw const FormatException('No readable receipt or slip amount');
    }
    return draft;
  }
}
