import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'voice_note_io.dart' if (dart.library.js_interop) 'voice_note_web.dart' as io;

/// Rekaman pesan suara anak (F-03) dan pemutarnya di HP Mbah. Suara asli, tidak dibacakan ulang oleh AI.
class VoiceNote {
  VoiceNote._();
  static final VoiceNote instance = VoiceNote._();

  static const maxSeconds = 60;

  AudioRecorder? _rec;
  final AudioPlayer _player = AudioPlayer();
  DateTime? _startedAt;

  String get mime => kIsWeb ? 'audio/webm' : 'audio/mp4';

  /// Mulai merekam. false bila izin mikrofon ditolak / perangkat tidak mendukung.
  Future<bool> start() async {
    try {
      final rec = _rec ??= AudioRecorder();
      if (!await rec.hasPermission()) return false;
      final cfg = RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      );
      await rec.start(cfg, path: await io.tempPath(kIsWeb ? 'webm' : 'm4a'));
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  int get elapsed => _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds;

  /// Selesai merekam → (byte rekaman, durasi detik). null bila gagal/terlalu pendek.
  Future<(Uint8List, int)?> stop() async {
    final secs = elapsed;
    _startedAt = null;
    try {
      final path = await _rec?.stop();
      if (path == null || secs < 1) return null;
      return (await io.readRecording(path), secs.clamp(1, maxSeconds));
    } catch (_) {
      return null;
    }
  }

  Future<void> cancel() async {
    _startedAt = null;
    try {
      await _rec?.cancel();
    } catch (_) {}
  }

  /// Putar rekaman sampai selesai (dengan batas waktu supaya alur telepon tidak menggantung).
  Future<void> play(Uint8List bytes, {String? mimeType, int seconds = 30}) async {
    try {
      await _player.stop();
      final done = _player.onPlayerComplete.first;
      await _player.play(BytesSource(bytes, mimeType: mimeType));
      await done.timeout(Duration(seconds: seconds + 4));
    } catch (_) {}
  }

  Future<void> stopPlaying() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
