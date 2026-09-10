import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'receipt_parser.dart';

class ReceiptService {
  Future<ReceiptDraft> scan(Uint8List bytes) async {
    final result = await FirebaseFunctions.instanceFor(
            region: 'asia-southeast1')
        .httpsCallable('scanReceipt',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
        .call<Map<String, dynamic>>({'image': base64Encode(bytes)});
    final text = result.data['text'] as String? ?? '';
    if (text.trim().isEmpty) throw const FormatException('No receipt text');
    return ReceiptDraft.fromText(text);
  }
}
