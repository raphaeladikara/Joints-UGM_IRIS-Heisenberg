import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Suara simulator telepon: TTS perangkat (pengganti ElevenLabs di prototype) dan STT perangkat (pengganti Scribe).
/// Semua panggilan plugin diberi timeout; bila gagal, layar tetap bisa dipakai lewat ketik/tombol jawaban.
class Voice {
  Voice._();
  static final Voice instance = Voice._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _ttsReady = false;
  bool _sttReady = false;
  bool sttAvailable = false;
  bool muted = false;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('id-ID').timeout(const Duration(seconds: 3));
      // Tempo pelan untuk lansia (prinsip suara KRING).
      await _tts.setSpeechRate(kIsWeb ? 0.85 : 0.42).timeout(const Duration(seconds: 3));
      await _tts.setPitch(1.0).timeout(const Duration(seconds: 3));
      await _tts.awaitSpeakCompletion(true).timeout(const Duration(seconds: 3));
    } catch (_) {}
    _ttsReady = true;
  }

  Future<void> speak(String text) async {
    if (muted || text.trim().isEmpty) return;
    await _initTts();
    try {
      await _tts.stop();
      // Batas atas supaya UI tidak menggantung bila mesin TTS tidak memanggil balik.
      await _tts.speak(text).timeout(Duration(seconds: 4 + text.length ~/ 10));
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<bool> initStt() async {
    if (_sttReady) return sttAvailable;
    _sttReady = true;
    try {
      sttAvailable = await _stt.initialize().timeout(const Duration(seconds: 5));
    } catch (_) {
      sttAvailable = false;
    }
    return sttAvailable;
  }

  /// Dengarkan satu ucapan. [onPartial] untuk teks sementara; future selesai dengan teks final (atau '').
  Future<String> listenOnce({void Function(String)? onPartial}) async {
    if (!await initStt()) return '';
    await stop(); // barge-in: pasien bicara → KRING berhenti
    final done = Completer<String>();
    var last = '';
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3), // lansia butuh jeda lebih panjang
          partialResults: true,
          cancelOnError: true,
          // Bias pengenalan ke kosakata layanan (Android 13+/iOS).
          contextualPhrases: const ['tensi', 'amlodipin', 'pelo', 'lemes', 'sampun', 'dereng', 'inggih', 'seratus', 'per'],
        ),
        onResult: (r) {
          last = r.recognizedWords;
          onPartial?.call(last);
          if (r.finalResult && !done.isCompleted) done.complete(last);
        },
      );
    } catch (_) {
      return '';
    }
    _stt.statusListener = (s) {
      if ((s == 'done' || s == 'notListening') && !done.isCompleted) done.complete(last);
    };
    return done.future.timeout(const Duration(seconds: 25), onTimeout: () => last);
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
