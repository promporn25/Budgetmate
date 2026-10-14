import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Device-local attachments. The marker can be synced, but the image cannot.
class LocalReceiptStore {
  LocalReceiptStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;

  Future<String> save(Uint8List bytes,
      {required String owner, required bool isPng}) async {
    final account = sha256.convert(utf8.encode(owner)).toString();
    final relative = '$account/${const Uuid().v4()}.${isPng ? 'png' : 'jpg'}';
    final root = await _directory();
    final file = File(p.join(root.path, 'receipts', relative));
    await file.parent.create(recursive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return 'local-receipt:$relative';
  }

  Future<void> delete(String marker) async {
    final match =
        RegExp(r'^local-receipt:([a-f0-9]{64}/[a-f0-9-]{36}\.(?:jpg|png))$')
            .firstMatch(marker);
    if (match == null) throw ArgumentError('Invalid local receipt marker');
    final root = await _directory();
    final file = File(p.join(root.path, 'receipts', match[1]!));
    if (await file.exists()) await file.delete();
  }
}
