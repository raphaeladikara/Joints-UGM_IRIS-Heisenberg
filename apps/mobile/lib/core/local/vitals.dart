/// Data jam tangan & aplikasi kesehatan offline (port `vitals.py`).
library;

import 'clock.dart';
import 'escalation.dart' as esc;
import 'safety.dart' as safety;
import 'store.dart';

const sourceLabel = {'health_connect': 'Health Connect', 'apple_health': 'Apple Health', 'watch_sim': 'Jam tangan (simulasi)'};

final _db = Store.instance;

String _at(String? raw) => raw == null || raw.isEmpty ? nowIso() : iso(fromIso(raw));

String? _openOnce(String patientId, String code, String quote) {
  final since = iso(startOfDay(wibNow()));
  for (final a in _db.where('alerts', (a) => a['patient_id'] == patientId && '${a['created_at']}'.compareTo(since) >= 0 && a['status'] != 'closed')) {
    if ((a['reasons'] as List).any((r) => r['code'] == code)) return null;
  }
  return esc.openAlert(patientId, null, 'yellow', 'event:wearable', [
    {'path': 'event', 'code': code, 'label': Content.label(code), 'quote': quote},
  ]);
}

Map<String, dynamic> ingest(String patientId, String source, String device, List<Map<String, dynamic>> samples) {
  final cfg = Content.wearable;
  final rows = <Row>[];
  for (final s in samples) {
    final kind = s['type'] as String;
    final at = _at(s['at'] as String?);
    final Map<String, dynamic> value;
    if (kind == 'blood_pressure') {
      value = {'systolic': (s['systolic'] as num).toInt(), 'diastolic': (s['diastolic'] as num).toInt(), 'confirmed': true};
    } else if (kind == 'steps' || kind == 'sleep') {
      value = {'value': (s['value'] as num).toInt(), 'date': at.substring(0, 10)};
    } else {
      value = {'value': (s['value'] as num).toDouble()};
    }
    rows.add({'id': newId(), 'patient_id': patientId, 'session_id': null, 'kind': kind, 'value': value, 'verbatim': device,
      'source': source, 'observed_at': at});
  }
  for (final r in rows) {
    if (r['kind'] == 'steps' || r['kind'] == 'sleep') {
      final day = (r['observed_at'] as String).substring(0, 10);
      _db.delete('observations', (o) => o['patient_id'] == patientId && o['kind'] == r['kind'] && (o['observed_at'] as String).startsWith(day));
    }
  }
  for (final r in rows) {
    _db.insert('observations', r);
  }
  _db.insert('device_syncs', {'id': newId(), 'patient_id': patientId, 'source': source, 'device': device, 'sample_count': rows.length, 'synced_at': nowIso()});

  final latest = <String, Map<String, dynamic>>{};
  for (final s in samples) {
    final t = s['type'] as String;
    if (!latest.containsKey(t) || _at(s['at'] as String?).compareTo(_at(latest[t]!['at'] as String?)) >= 0) latest[t] = s;
  }
  final alerts = <String?>[];
  final label = sourceLabel[source] ?? source;
  final sp = latest['spo2'];
  if (sp != null && (sp['value'] as num) < (cfg['spo2_low'] as num)) {
    alerts.add(_openOnce(patientId, 'SPO2_LOW', 'SpO2 ${(sp['value'] as num).round()}% ($label)'));
  }
  final rhr = latest['resting_hr'];
  if (rhr != null && (rhr['value'] as num) >= (cfg['hr_high_rest'] as num)) {
    alerts.add(_openOnce(patientId, 'HR_HIGH_REST', 'detak istirahat ${(rhr['value'] as num).round()}/menit'));
  }
  final hr = latest['heart_rate'];
  if (hr != null && (hr['value'] as num) <= (cfg['hr_low'] as num)) {
    alerts.add(_openOnce(patientId, 'HR_LOW', 'detak ${(hr['value'] as num).round()}/menit'));
  }
  final bp = latest['blood_pressure'];
  if (bp != null) {
    final sys = (bp['systolic'] as num).toInt(), dia = (bp['diastolic'] as num).toInt();
    final f = safety.assessBp(sys, dia, {}, '$label: $sys/$dia');
    if (f != null) alerts.add(_openOnce(patientId, f.code, f.quote));
  }
  final opened = alerts.whereType<String>().toList();
  return {'stored': rows.length, 'level': opened.isEmpty ? 'green' : 'yellow', 'alert_ids': opened};
}

List<Map<String, dynamic>> series(String patientId, String kind, int days) {
  final since = iso(wibNow().subtract(Duration(days: days)));
  final rows = _db.sorted(
    _db.where('observations', (o) => o['patient_id'] == patientId && o['kind'] == kind && (o['observed_at'] as String).compareTo(since) >= 0),
    'observed_at',
  );
  return [for (final r in rows) {...(r['value'] as Map).cast<String, dynamic>(), 'at': r['observed_at'], 'source': r['source']}];
}

List<Map<String, dynamic>> _daily(List<Map<String, dynamic>> points, int days, String agg) {
  final today = startOfDay(wibNow());
  return [
    for (var d = days - 1; d >= 0; d--)
      () {
        final date = dateIso(today.subtract(Duration(days: d)));
        final vals = [for (final p in points) if ((p['at'] as String).startsWith(date) && p['value'] != null) p['value'] as num];
        num? v;
        if (vals.isNotEmpty) {
          v = agg == 'avg' ? vals.reduce((a, b) => a + b) / vals.length : (agg == 'min' ? vals.reduce((a, b) => a < b ? a : b) : vals.last);
        }
        return {'date': date, 'value': v is double ? (v * 10).round() / 10 : v};
      }(),
  ];
}

Map<String, dynamic> summary(String patientId, [int days = 7]) {
  final cfg = Content.wearable;
  final syncs = _db.sorted(_db.where('device_syncs', (s) => s['patient_id'] == patientId), 'synced_at', desc: true);
  final last = syncs.firstOrNull;
  final hr = series(patientId, 'heart_rate', days);
  final rhr = series(patientId, 'resting_hr', days);
  final spo2 = series(patientId, 'spo2', days);
  final steps = series(patientId, 'steps', days);
  final sleep = series(patientId, 'sleep', days);
  final bp = series(patientId, 'blood_pressure', days);
  final today = dateIso(wibNow());
  final stepsToday = steps.reversed.where((p) => (p['at'] as String).startsWith(today)).map((p) => p['value']).firstOrNull ?? 0;
  return {
    'connected': last != null,
    'last_sync': last == null
        ? null
        : {'source': last['source'], 'device': last['device'], 'synced_at': last['synced_at'], 'sample_count': last['sample_count'],
           'source_label': sourceLabel[last['source']] ?? last['source']},
    'goals': {'steps': cfg['goal_steps'], 'sleep_min': cfg['goal_sleep_min']},
    'thresholds': {'spo2_low': cfg['spo2_low'], 'hr_high_rest': cfg['hr_high_rest'], 'hr_low': cfg['hr_low']},
    'latest': {
      'heart_rate': hr.lastOrNull,
      'resting_hr': rhr.lastOrNull,
      'spo2': spo2.lastOrNull,
      'blood_pressure': bp.lastOrNull,
      'steps_today': stepsToday,
      'sleep_last_min': sleep.lastOrNull?['value'],
    },
    'daily': {
      'steps': _daily(steps, days, 'last'),
      'sleep': _daily(sleep, days, 'last'),
      'heart_rate': _daily(hr, days, 'avg'),
      'resting_hr': _daily(rhr, days, 'avg'),
      'spo2': _daily(spo2, days, 'min'),
    },
    'heart_rate_today': [for (final p in hr) if ((p['at'] as String).startsWith(today)) {'at': p['at'], 'value': p['value']}],
  };
}
