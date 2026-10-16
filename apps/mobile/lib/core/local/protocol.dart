/// F-19 Protokol "tidak diangkat" offline (port `protocol.py`): telepon ulang 15 menit kemudian → masih tidak diangkat →
/// Sahabat Kring diminta mengecek ke rumah, keluarga diberi tahu di setiap langkah.
library;

import 'clock.dart';
import 'dialog.dart' as dialog;
import 'escalation.dart' as esc;
import 'store.dart';

const retryMinutes = 15;

final _db = Store.instance;

(Row, Row?, Row?) _people(String pid) {
  final contacts = esc.contactsFor(pid);
  return (
    _db.byId('patients', pid)!,
    contacts.where((c) => c['role'] == 'sahabat_tilik').firstOrNull,
    contacts.where((c) => c['role'] == 'child').firstOrNull,
  );
}

/// Dipanggil dialog.noAnswer untuk panggilan harian/ulang. Hasil: (id alert kuning bila ada, hints).
(String?, List<String>) onNoAnswer(Row s, Map<String, dynamic> ctx) {
  final pid = s['patient_id'] as String, sid = s['id'] as String;
  final (patient, sahabat, child) = _people(pid);
  final name = patient['display_name'];
  if (ctx['trigger'] == 'retry') {
    final retry = _db.one('call_retries', (r) => r['session_id'] == sid);
    final origin = _db.byId('call_sessions', retry?['origin_session_id'] as String?);
    final missed = [(origin?['started_at'] ?? s['started_at']) as String, s['started_at'] as String];
    retry?['status'] = 'missed';
    final reasons = [
      {'path': 'rule', 'code': 'NO_ANSWER_RETRY', 'label': Content.label('NO_ANSWER_RETRY'),
       'quote': 'tidak diangkat pukul ${fmtHm(missed[0])} dan ${fmtHm(missed[1])}'},
    ];
    final alertId = esc.openAlert(pid, sid, 'yellow', 'scheduler', reasons);
    if (sahabat != null) requestHomeCheck(patient, sahabat, child, alertId, missed, sid);
    return (alertId, ['home_check_requested']);
  }
  final due = iso(wibNow().add(const Duration(minutes: retryMinutes)));
  for (final r in _db.where('call_retries', (r) => r['patient_id'] == pid && r['status'] == 'pending')) {
    r['status'] = 'cancelled';
  }
  _db.insert('call_retries', {'id': newId(), 'patient_id': pid, 'origin_session_id': sid, 'due_at': due, 'status': 'pending', 'session_id': null,
    'created_at': nowIso()});
  if (child != null) {
    esc.notify(child, pid, 'retry_scheduled', 'whatsapp_sim', '📞 $name belum mengangkat',
        'Telepon pagi KRING pukul ${fmtHm(s['started_at'] as String)} belum diangkat. KRING menelepon ulang pukul ${fmtHm(due)}. '
        'Kalau tetap tidak diangkat, ${sahabat?['name'] ?? 'tetangga'} diminta menengok ke rumah.',
        payload: {'due_at': due}, sessionId: sid);
  }
  return (null, ['retry_scheduled']);
}

String requestHomeCheck(Row patient, Row sahabat, Row? child, String? alertId, List<String> missed, String? sid) {
  final pid = patient['id'] as String, name = patient['display_name'];
  final hid = newId();
  _db.insert('home_checks', {'id': hid, 'patient_id': pid, 'contact_id': sahabat['id'], 'alert_id': alertId, 'status': 'requested', 'note': '',
    'missed_at': missed, 'created_at': nowIso(), 'responded_at': null});
  final brief = Content.briefing('home_check', {'sahabat': sahabat['name'], 'puskesmas': esc.puskesmasName, 'sapaan': name,
    'jam1': fmtHm(missed.first), 'jam2': fmtHm(missed.last)});
  esc.notify(sahabat, pid, 'home_check', 'whatsapp_sim', '🏠 Mohon tengok $name', brief, payload: {'home_check_id': hid}, alertId: alertId, sessionId: sid);
  if (child != null) {
    esc.notify(child, pid, 'home_check_sent', 'whatsapp_sim', '🏠 ${sahabat['name']} diminta mengecek $name',
        'KRING sudah menelepon pukul ${fmtHm(missed.first)} dan ${fmtHm(missed.last)}, belum diangkat. ${sahabat['name']} '
        '(${sahabat['relation']}) diminta menengok ke rumah dan akan mengabari di sini.',
        payload: {'home_check_id': hid}, alertId: alertId, sessionId: sid);
  }
  return hid;
}

/// Jalankan telepon ulang yang sudah jatuh tempo (dipanggil saat HP Mbah/Puskesmas/keluarga memuat data).
void runDue([String? pid]) {
  final now = nowIso();
  final due = _db
      .where('call_retries', (r) => r['status'] == 'pending' && (r['due_at'] as String).compareTo(now) <= 0 && (pid == null || r['patient_id'] == pid))
      .toList();
  for (final r in due) {
    final origin = _db.byId('call_sessions', r['origin_session_id'] as String?);
    final after = (origin?['started_at'] ?? r['created_at']) as String;
    final answered = _db.one('call_sessions',
        (c) => c['patient_id'] == r['patient_id'] && (c['started_at'] as String).compareTo(after) > 0 && c['status'] == 'completed');
    if (answered != null) {
      r['status'] = 'cancelled';
      continue;
    }
    if (_db.one('call_sessions', (c) => c['patient_id'] == r['patient_id'] && (c['status'] == 'ringing' || c['status'] == 'in_progress')) != null) {
      continue;
    }
    final s = dialog.createSession(r['patient_id'] as String, trigger: 'retry');
    r['status'] = 'calling';
    r['session_id'] = s['id'];
  }
}

Map<String, dynamic>? fireNow(String rid) {
  final r = _db.byId('call_retries', rid);
  if (r == null) return null;
  if (r['status'] == 'pending') {
    r['due_at'] = nowIso();
    runDue(r['patient_id'] as String);
  }
  return state(r['patient_id'] as String);
}

/// Sahabat Kring melapor hasil cek rumah: ok (baik), not_home (tidak ada di rumah), help (butuh bantuan).
Map<String, dynamic>? respond(String hid, String result, String note) {
  final hc = _db.byId('home_checks', hid);
  if (hc == null) return null;
  final pid = hc['patient_id'] as String;
  final (patient, sahabat, child) = _people(pid);
  final name = patient['display_name'], who = sahabat?['name'] ?? 'Sahabat Kring';
  hc.addAll({'status': result, 'note': note, 'responded_at': nowIso()});
  final extra = note.isNotEmpty ? ' Catatan: "$note"' : '';
  final alertId = hc['alert_id'] as String?;
  if (result == 'ok') {
    _db.byId('alerts', alertId)?.addAll({'status': 'closed', 'updated_at': nowIso()});
    if (child != null) {
      esc.notify(child, pid, 'home_check_result', 'whatsapp_sim', '✅ $name baik-baik saja', '$who sudah menengok: $name dalam keadaan baik.$extra',
          payload: {'home_check_id': hid, 'result': result});
    }
  } else if (result == 'not_home') {
    if (alertId != null) {
      esc.updateAlert(alertId, reasons: [
        {'path': 'rule', 'code': 'HOME_CHECK_NOT_HOME', 'label': Content.label('HOME_CHECK_NOT_HOME'), 'quote': note.isNotEmpty ? note : who},
      ]);
    }
    if (child != null) {
      esc.notify(child, pid, 'home_check_result', 'whatsapp_sim', '⚠️ $name tidak ada di rumah',
          '$who sudah ke rumah, tetapi $name tidak ada. Mohon coba hubungi kerabat atau tetangga lain. Petugas Puskesmas ikut memantau.$extra',
          payload: {'home_check_id': hid, 'result': result});
    }
  } else {
    esc.openAlert(pid, null, 'red', 'home_check', [
      {'path': 'rule', 'code': 'HOME_CHECK_HELP', 'label': Content.label('HOME_CHECK_HELP'), 'quote': note.isNotEmpty ? note : who},
    ]);
  }
  return state(pid);
}

/// Tahap protokol hari ini untuk satu pasien (null bila semua panggilan hari ini terangkat).
Map<String, dynamic>? state(String pid) {
  final start = iso(startOfDay(wibNow()));
  final hc = _db.sorted(_db.where('home_checks', (h) => h['patient_id'] == pid && (h['created_at'] as String).compareTo(start) >= 0), 'created_at',
      desc: true).firstOrNull;
  final retry = _db.sorted(_db.where('call_retries', (r) => r['patient_id'] == pid && (r['created_at'] as String).compareTo(start) >= 0), 'created_at',
      desc: true).firstOrNull;
  if (hc == null && retry == null) return null;
  String? stage;
  var missed = <String>[];
  if (hc != null) {
    stage = switch (hc['status']) { 'requested' => 'home_check', 'ok' => 'checked_ok', final s => s as String };
    missed = (hc['missed_at'] as List).cast<String>();
  } else if (retry != null) {
    final origin = _db.byId('call_sessions', retry['origin_session_id'] as String?);
    if (origin != null) missed = [origin['started_at'] as String];
    final sess = _db.byId('call_sessions', retry['session_id'] as String?);
    if (retry['status'] == 'pending') {
      stage = 'retry_scheduled';
    } else if (retry['status'] == 'cancelled' || sess?['status'] == 'completed') {
      stage = 'answered';
    } else if (retry['status'] == 'missed') {
      stage = 'missed';
    } else {
      stage = 'retrying';
    }
  }
  return {
    'stage': stage,
    'missed_at': missed,
    'retry': retry == null ? null : {'id': retry['id'], 'due_at': retry['due_at'], 'status': retry['status']},
    'home_check': hc == null
        ? null
        : {
            for (final k in ['id', 'status', 'contact_id', 'note', 'created_at', 'responded_at']) k: hc[k],
            'contact_name': _db.byId('contacts', hc['contact_id'] as String)?['name'],
          },
  };
}
