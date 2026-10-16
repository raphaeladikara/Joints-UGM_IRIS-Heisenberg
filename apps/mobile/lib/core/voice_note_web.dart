import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Di web, rekaman tidak ditulis ke berkas: `stop()` mengembalikan blob URL.
Future<String> tempPath(String ext) async => '';

Future<Uint8List> readRecording(String blobUrl) async => (await http.get(Uri.parse(blobUrl))).bodyBytes;
