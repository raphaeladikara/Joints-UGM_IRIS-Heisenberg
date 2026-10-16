import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'api.dart';

/// Sinkron data jam tangan ke server KRING.
///
/// * Android: Health Connect. Jam Samsung (Samsung Health), Wear OS, Fitbit, Xiaomi/Mi Fitness, Huawei Health, dll.
///   sudah menyalin datanya ke Health Connect, jadi KRING cukup membaca satu sumber.
/// * iOS: Apple Health (HealthKit) dengan Apple Watch atau jam lain yang menulis ke Apple Health.
/// * Web / laptop demo: tidak ada akses kesehatan perangkat, pakai [simulate].
///
/// KRING hanya MEMBACA (tidak pernah menulis) dan hanya tipe yang dipakai skrining.
class HealthSync {
  HealthSync._();
  static final instance = HealthSync._();
  final _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static bool get isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get nativeSupported => isIos || isAndroid;
  static String get sourceKey => isIos ? 'apple_health' : 'health_connect';
  static String get sourceLabel => isIos ? 'Apple Health' : 'Health Connect';

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// null = siap; selain itu pesan yang bisa ditampilkan ke pengguna.
  Future<String?> availability() async {
    if (!nativeSupported) return 'Akses data kesehatan hanya ada di aplikasi Android/iPhone. Di laptop, pakai simulasi jam tangan.';
    await _configure();
    if (isAndroid) {
      final s = await _health.getHealthConnectSdkStatus();
      if (s != HealthConnectSdkStatus.sdkAvailable) {
        return 'Health Connect belum terpasang atau perlu diperbarui.';
      }
    }
    return null;
  }

  Future<void> installHealthConnect() async {
    await _configure();
    await _health.installHealthConnect();
  }

  Future<bool> connect() async {
    await _configure();
    return _health.requestAuthorization(_types, permissions: [for (final _ in _types) HealthDataAccess.READ]);
  }

  /// Baca 7 hari terakhir lalu kirim ke server. Mengembalikan respons server (berisi ringkasan terbaru).
  Future<Json> syncNow(String patientId) async {
    await _configure();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final samples = <Json>[];

    // Langkah: total per hari (Health Connect/HealthKit sudah menghapus duplikat antar sumber).
    for (var d = 0; d < 7; d++) {
      final from = start.add(Duration(days: d));
      final to = d == 6 ? now : from.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(from, to);
      if (steps != null) samples.add({'type': 'steps', 'value': steps, 'at': to.toIso8601String()});
    }

    final points = _health.removeDuplicates(
      await _health.getHealthDataFromTypes(types: _types.where((t) => t != HealthDataType.STEPS).toList(), startTime: start, endTime: now),
    );
    num v(HealthDataPoint p) => (p.value as NumericHealthValue).numericValue;

    // Tidur: jumlahkan menit tidur per malam, dicatat di tanggal bangun.
    final sleep = <String, num>{};
    final sys = <DateTime, num>{}, dia = <DateTime, num>{};
    for (final p in points) {
      switch (p.type) {
        case HealthDataType.HEART_RATE:
          samples.add({'type': 'heart_rate', 'value': v(p), 'at': p.dateFrom.toIso8601String()});
        case HealthDataType.RESTING_HEART_RATE:
          samples.add({'type': 'resting_hr', 'value': v(p), 'at': p.dateFrom.toIso8601String()});
        case HealthDataType.BLOOD_OXYGEN:
          final pct = v(p) <= 1 ? v(p) * 100 : v(p); // HealthKit: pecahan 0..1
          samples.add({'type': 'spo2', 'value': pct, 'at': p.dateFrom.toIso8601String()});
        case HealthDataType.SLEEP_ASLEEP:
          final key = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day).toIso8601String();
          sleep[key] = (sleep[key] ?? 0) + p.dateTo.difference(p.dateFrom).inMinutes;
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          sys[p.dateFrom] = v(p);
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          dia[p.dateFrom] = v(p);
        default:
      }
    }
    sleep.forEach((day, mins) => samples.add({'type': 'sleep', 'value': mins.round(), 'at': DateTime.parse(day).add(const Duration(hours: 6)).toIso8601String()}));
    for (final t in sys.keys) {
      if (dia[t] != null) samples.add({'type': 'blood_pressure', 'systolic': sys[t]!.round(), 'diastolic': dia[t]!.round(), 'at': t.toIso8601String()});
    }

    // Detak jantung bisa ribuan sampel: kirim paling banyak 1 per 15 menit.
    final thinned = _thinHeartRate(samples);
    if (thinned.isEmpty) throw ApiException('Belum ada data di $sourceLabel untuk 7 hari terakhir. Pastikan jam tangan sudah tersinkron ke HP.');
    return Api.instance.postVitals(patientId, sourceKey, sourceLabel, thinned);
  }

  List<Json> _thinHeartRate(List<Json> samples) {
    final out = <Json>[];
    final seen = <String>{};
    for (final s in samples) {
      if (s['type'] != 'heart_rate') {
        out.add(s);
        continue;
      }
      final t = DateTime.parse(s['at'] as String);
      if (seen.add('${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute ~/ 15}')) out.add(s);
    }
    return out.take(2000).toList();
  }

  /// Simulasi jam tangan untuk demo di laptop/web. [scenario]: normal | spo2_low | bp_high.
  Future<Json> simulate(String patientId, {String scenario = 'normal'}) {
    final rng = math.Random();
    final now = DateTime.now();
    final samples = <Json>[
      {'type': 'heart_rate', 'value': 74 + rng.nextInt(12), 'at': now.toIso8601String()},
      {'type': 'resting_hr', 'value': 68 + rng.nextInt(6), 'at': now.toIso8601String()},
      {'type': 'spo2', 'value': scenario == 'spo2_low' ? 87 : 96 + rng.nextInt(3), 'at': now.toIso8601String()},
      {'type': 'steps', 'value': 1800 + rng.nextInt(2400), 'at': now.toIso8601String()},
      if (scenario == 'bp_high') {'type': 'blood_pressure', 'systolic': 186, 'diastolic': 104, 'at': now.toIso8601String()},
    ];
    return Api.instance.postVitals(patientId, 'watch_sim', 'Jam tangan (simulasi)', samples);
  }
}
