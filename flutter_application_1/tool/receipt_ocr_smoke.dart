// Run on a device/simulator: flutter run -t tool/receipt_ocr_smoke.dart
// Synthetic data only; this does not initialize Firebase or create expenses.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:budgetmate/services/receipt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Testing offline OCR…')))));
  String status;
  try {
    final loader = FontLoader('ReceiptTest')
      ..addFont(rootBundle.load('assets/fonts/Mali-Regular.ttf'));
    await loader.load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final painter = TextPainter(
      text: const TextSpan(
        text:
            'ร้านทดสอบ\nใบเสร็จรับเงิน\n30/09/2026\nยอดสุทธิ 125.50 บาท\nGrand Total 125.50',
        style: TextStyle(
            fontFamily: 'ReceiptTest',
            fontSize: 42,
            color: Colors.black,
            height: 1.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 850);
    painter.paint(canvas, const Offset(40, 40));
    final picture = recorder.endRecording();
    final image = await picture.toImage(950, 600);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final draft = await ReceiptService().scan(data!.buffer.asUint8List());
    if (draft.amount != 125.50 || draft.date != DateTime(2026, 9, 30)) {
      throw StateError('Unexpected result: ${draft.amount}, ${draft.date}');
    }
    image.dispose();
    picture.dispose();
    painter.dispose();
    status = 'PASS: offline OCR amount=125.50 date=2026-09-30';
  } catch (error) {
    status = 'FAIL: $error';
  }
  final dir = await getApplicationSupportDirectory();
  await File('${dir.path}/receipt-ocr-smoke.txt').writeAsString(status);
  debugPrint(status);
  runApp(MaterialApp(home: Scaffold(body: Center(child: Text(status)))));
}
