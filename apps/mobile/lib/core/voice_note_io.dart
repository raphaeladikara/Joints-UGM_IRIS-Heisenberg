import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> tempPath(String ext) async => '${(await getTemporaryDirectory()).path}/pesan_suara_${DateTime.now().millisecondsSinceEpoch}.$ext';

/// Baca rekaman lalu hapus berkas sementaranya.
Future<Uint8List> readRecording(String path) async {
  final f = File(path);
  final bytes = await f.readAsBytes();
  try {
    await f.delete();
  } catch (_) {}
  return bytes;
}
