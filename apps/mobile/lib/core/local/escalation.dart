/// Mesin eskalasi offline (port `escalation.py`). Telepon/WA ke keluarga = notifikasi simulasi di aplikasi.
library;

import 'clock.dart';
import 'store.dart';

const puskesmasName = 'Puskesmas Wonosari I (simulasi)';
const doctor = {'name': 'dr. Ayu Lestari (simulasi)', 'role': 'Dokter jaga', 'facility': puskesmasName, 'hours': '24 jam'};

final _db = Store.instance;

List<Row> contactsFor(String patientId) =>
    _db.where('contacts', (c) => c['patient_id'] == patientId).toList()
      ..sort((a, b) => (a['escalation_order'] as int).compareTo(b['escalation_order'] as int));

(Row?, int?) nearestCtHospital(String village) {
  Row? best;
  int? mins;
  for (final t in _db.where('travel_times', (t) => t['village'] == village)) {
    final h = _db.byId('hospitals', t['hospital_id'] as String);
    if (h == null || h['has_ct_24h'] != 1) continue;
    if (mins == null || (t['minutes'] as int) < mins) {
      best = h;
      mins = t['minutes'] as int;
    }
  }
  return (best, mins);
}

String notify(Row contact, String patientId, String kind, String channel, String title, String body,
    {Map<String, dynamic>? payload, String? alertId, String? sessionId, String status = 'sent'}) {
  final id = newId();
  _db.insert('notifications', {
    'id': id, 'contact_id': contact['id'], 'patient_id': patientId, 'alert_id': alertId, 'session_id': sessionId, 'kind': kind,
    'channel': channel, 'title': title, 'body': body, 'payload': payload ?? {}, 'status': status, 'created_at': nowIso(), 'read_at': null,
  });
  return id;
}

/// 🔴: pre-alert IGD + telepon Sahabat Kring lalu anak + WA keduanya. 🟡: WA ke anak.
String openAlert(String patientId, String? sessionId, String level, String source, List<Map<String, dynamic>> reasons) {
  final patient = _db.byId('patients', patientId)!;
  final now = nowIso();
  final (hospital, eta) = level == 'red' ? nearestCtHospital(patient['village'] as String) : (null, null);
  final alertId = newId();
  final contacts = contactsFor(patientId);
  final sahabat = contacts.where((c) => c['role'] == 'sahabat_tilik').firstOrNull;
  final child = contacts.where((c) => c['role'] == 'child').firstOrNull;
  final summary = reasons.map((r) => r['label']).join(', ');
  final ringkas = summary.isEmpty ? 'tanda bahaya' : summary;
  _db.insert('alerts', {
    'id': alertId, 'patient_id': patientId, 'session_id': sessionId, 'level': level, 'source': source, 'reasons': reasons,
    'screening': <String, dynamic>{}, 'last_known_well': null, 'lkw_note': null, 'golden_period_deadline': null,
    'target_hospital_id': hospital?['id'], 'eta_minutes': eta, 'status': 'open', 'acknowledged_by': null, 'acknowledged_at': null,
    'created_at': now, 'updated_at': now,
  });
  final name = patient['display_name'];
  if (level != 'red') {
    if (child != null) {
      notify(child, patientId, 'yellow_notice', 'whatsapp_sim', '🟡 $name perlu tindak lanjut',
          'KRING mencatat: $ringkas. Petugas Puskesmas akan menghubungi hari ini. Tidak darurat.',
          payload: {'reasons': reasons}, alertId: alertId, sessionId: sessionId);
    }
    return alertId;
  }
  final rs = hospital != null ? '${hospital['name']} (±$eta menit)' : 'RS ber-CT terdekat';
  final waBody = '🔴 DARURAT: $name menunjukkan tanda bahaya ($ringkas). Terakhir normal: menunggu jawaban. '
      'RS ber-CT terdekat: $rs. Hubungi 119 / ambulans desa. (Mode demo: KRING tidak menelepon 119.)';
  final payload = {'reasons': reasons, 'hospital': hospital, 'eta_minutes': eta};
  for (final c in [sahabat, child]) {
    if (c == null) continue;
    final key = c['role'] == 'sahabat_tilik' ? 'sahabat_tilik' : 'child';
    final brief = Content.briefing(key, {
      'sahabat': sahabat?['name'] ?? 'tetangga', 'anak': child?['name'] ?? 'keluarga', 'sapaan': name, 'puskesmas': puskesmasName,
      'lkw': 'belum diketahui (skrining berjalan)', 'ringkas': ringkas, 'rs': hospital?['name'] ?? 'RS terdekat', 'eta': eta ?? '?',
    });
    notify(c, patientId, 'red_call', 'call_sim', '📞 KRING menelepon: darurat $name', brief,
        payload: {...payload, 'conference': 'tilik-${alertId.substring(0, 8)}'}, alertId: alertId, sessionId: sessionId, status: 'ringing');
    notify(c, patientId, 'red_alert', 'whatsapp_sim', '🔴 Darurat $name', waBody, payload: payload, alertId: alertId, sessionId: sessionId);
  }
  return alertId;
}

void updateAlert(String alertId,
    {DateTime? lkw, String? lkwNote, Map<String, dynamic>? screening, List<Map<String, dynamic>>? reasons}) {
  final alert = _db.byId('alerts', alertId);
  if (alert == null) return;
  final now = nowIso();
  if (screening != null) {
    alert['screening'] = {...(alert['screening'] as Map), ...screening};
    alert['updated_at'] = now;
  }
  if (reasons != null && reasons.isNotEmpty) {
    final existing = (alert['reasons'] as List).cast<Map>();
    final codes = existing.map((r) => r['code']).toSet();
    alert['reasons'] = [...existing, ...reasons.where((r) => !codes.contains(r['code']))];
    alert['updated_at'] = now;
  }
  if (lkwNote != null) {
    alert['last_known_well'] = lkw == null ? null : iso(lkw);
    alert['lkw_note'] = lkwNote;
    alert['golden_period_deadline'] = lkw == null ? null : iso(lkw.add(goldenPeriod));
    alert['updated_at'] = now;
    final patient = _db.byId('patients', alert['patient_id'] as String)!;
    final name = patient['display_name'];
    String body;
    if (lkw != null) {
      final rem = lkw.add(goldenPeriod).difference(wibNow()).inMinutes;
      final r = rem < 0 ? 0 : rem;
      body = 'Update: $name terakhir normal jam ${fmtHm(iso(lkw))}. Sisa golden period ±${r ~/ 60} jam ${r % 60} menit. Pre-alert sudah dikirim ke IGD.';
    } else {
      body = 'Update: jam terakhir normal $name tidak diketahui. Pre-alert sudah dikirim ke IGD.';
    }
    for (final c in contactsFor(alert['patient_id'] as String)) {
      if (c['role'] == 'child' || c['role'] == 'sahabat_tilik') {
        notify(c, alert['patient_id'] as String, 'red_update', 'whatsapp_sim', '⏱️ Jam onset $name', body,
            payload: {'last_known_well': lkw == null ? null : iso(lkw)}, alertId: alertId, sessionId: alert['session_id'] as String?);
      }
    }
  }
}

Map<String, dynamic> handleEvent(String patientId, String source, String type, Map<String, dynamic> payload) {
  final eventId = newId();
  final ev = {'id': eventId, 'patient_id': patientId, 'source': source, 'type': type, 'payload': payload, 'occurred_at': nowIso(), 'handled_level': null};
  _db.insert('events', ev);
  final result = <String, dynamic>{'event_id': eventId, 'action': 'logged', 'level': 'green'};
  Map<String, dynamic> reason(String code) => {'path': 'event', 'code': code, 'label': Content.label(code), 'quote': source};
  if (type == 'sos_pressed') {
    result.addAll({'action': 'escalated', 'level': 'red', 'alert_id': openAlert(patientId, null, 'red', 'event:$source', [reason('SOS_PRESSED')])});
  } else if (type == 'irregular_rhythm') {
    result.addAll({'action': 'follow_up', 'level': 'yellow', 'alert_id': openAlert(patientId, null, 'yellow', 'event:$source', [reason('IRREGULAR_RHYTHM')])});
  } else if (type == 'missed_checkin') {
    result.addAll({'action': 'follow_up', 'level': 'yellow', 'alert_id': openAlert(patientId, null, 'yellow', 'event:$source', [reason('NO_ANSWER_2X')])});
  }
  ev['handled_level'] = result['level'];
  return result;
}
