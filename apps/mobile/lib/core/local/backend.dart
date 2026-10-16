/// Backend offline KRING: endpoint yang sama dengan `apps/api/app/main.py`, berjalan di dalam aplikasi.
/// Dipakai bila server tidak diatur (APK demo bisa dipasang di HP mana pun, tanpa internet).
///
/// Endpoint tambahan (fitur keluarga): /care, /meds/dose, /meds/refill, /intake, /family-calls, /report.
library;

import 'clock.dart';
import 'dialog.dart' as dialog;
import 'escalation.dart' as esc;
import 'safety.dart' as safety;
import 'seed.dart';
import 'store.dart';
import 'vitals.dart' as vitals;

class LocalHttpError implements Exception {
  LocalHttpError(this.status, this.detail);
  final int status;
  final String detail;
}

typedef J = Map<String, dynamic>;

class LocalBackend {
  LocalBackend._();
  static final LocalBackend instance = LocalBackend._();

  final _db = Store.instance;
  Future<void>? _ready;

  Future<void> ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    await Content.load();
    final ok = await _db.load();
    // Data demo selalu "hari ini": kalau tersimpan dari hari lain, isi ulang.
    if (!ok || _db.seededOn != dateIso(wibNow()) || _db.rows('patients').isEmpty) {
      runSeed();
      await _db.save();
    }
  }

  Future<dynamic> handle(String method, String rawPath, Object? body) async {
    await ensureReady();
    final uri = Uri.parse(rawPath);
    final seg = uri.pathSegments;
    final q = uri.queryParameters;
    final b = (body as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    try {
      final Object? result = _route(method, seg, q, b);
      if (method != 'GET') _db.scheduleSave();
      final Object? out = deep<Object?>(result);
      return out;
    } on dialog.DialogError catch (e) {
      throw LocalHttpError(e.status, e.message);
    }
  }

  dynamic _route(String m, List<String> s, Map<String, String> q, J b) {
    if (s.length < 2 || s[0] != 'v1') throw LocalHttpError(404, 'Not Found');
    final r = s.sublist(1);
    final get = m == 'GET';
    switch (r) {
      case ['health'] when get:
        return {'ok': true, 'demo_mode': true, 'llm': false, 'offline': true, 'time': nowIso()};
      case ['demo', 'reset']:
        runSeed();
        return {'ok': true};
      case ['patients'] when get:
        return (_db.where('patients', (p) => p['active'] == 1).toList()..sort((a, c) => '${a['display_name']}'.compareTo('${c['display_name']}')))
            .map(_publicPatient)
            .toList();
      case ['patients', final pid] when get:
        return _patientDetail(pid);
      case ['puskesmas', 'today'] when get:
        return _daftarTilik();
      case ['calls'] when !get:
        return _startCall(b);
      case ['calls'] when get:
        return _liveCalls();
      case ['patients', final pid, 'incoming'] when get:
        final s = _db.sorted(_db.where('call_sessions', (c) => c['patient_id'] == pid && c['status'] == 'ringing'), 'started_at', desc: true).firstOrNull;
        return {'ringing': s != null, 'session': s == null ? null : {'id': s['id'], 'trigger': s['trigger'], 'started_at': s['started_at']}};
      case ['calls', final sid, 'answer']:
        return dialog.answer(sid).asMap();
      case ['calls', final sid, 'turns']:
        final text = '${b['text'] ?? ''}'.trim();
        if (text.isEmpty) throw LocalHttpError(422, 'Teks kosong');
        return dialog.handle(sid, text.length > 600 ? text.substring(0, 600) : text).asMap();
      case ['calls', final sid, 'no-answer']:
        return dialog.noAnswer(sid).asMap();
      case ['calls', final sid, 'hangup']:
        return dialog.hangup(sid).asMap();
      case ['calls', final sid] when get:
        return _callDetail(sid);
      case ['events']:
        return _postEvent(b);
      case ['patients', final pid, 'vitals'] when !get:
        _patientOr404(pid);
        final samples = (b['samples'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        final src = '${b['source']}';
        final device = '${b['device'] ?? ''}';
        return {...vitals.ingest(pid, src, device.isEmpty ? (vitals.sourceLabel[src] ?? src) : device, samples), 'summary': vitals.summary(pid)};
      case ['patients', final pid, 'vitals'] when get:
        _patientOr404(pid);
        return vitals.summary(pid, (int.tryParse(q['days'] ?? '') ?? 7).clamp(1, 30));
      case ['alerts'] when get:
        var l = _db.where('alerts', (a) => (q['level'] == null || a['level'] == q['level']) && (q['status'] == null || a['status'] == q['status']));
        return _db.sorted(l, 'created_at', desc: true).take(50).map(_alertView).toList();
      case ['alerts', final aid] when get:
        return _alertView(_alertOr404(aid));
      case ['alerts', final aid, 'ack']:
        final a = _alertOr404(aid);
        a.addAll({'status': 'acknowledged', 'acknowledged_by': b['by'], 'acknowledged_at': nowIso(), 'updated_at': nowIso()});
        return {'ok': true};
      case ['alerts', final aid, 'close']:
        final a = _db.byId('alerts', aid);
        a?.addAll({'status': 'closed', 'updated_at': nowIso()});
        return {'ok': true};
      case ['hospitals'] when get:
        return _db.sorted(_db.rows('hospitals'), 'name');
      case ['contacts'] when get:
        final rows = [
          for (final c in _db.rows('contacts'))
            {'id': c['id'], 'role': c['role'], 'name': c['name'], 'relation': c['relation'], 'patient_id': c['patient_id'],
             'patient_name': _db.byId('patients', c['patient_id'] as String)?['display_name'], '_o': c['escalation_order']},
        ]..sort((a, c) {
            final x = '${a['patient_name']}'.compareTo('${c['patient_name']}');
            return x != 0 ? x : (a['_o'] as int).compareTo(c['_o'] as int);
          });
        return [for (final r in rows) r..remove('_o')];
      case ['contacts', final cid, 'feed'] when get:
        return _contactFeed(cid);
      case ['patients', final pid, 'doctor-consults']:
        return _requestConsult(pid, b);
      case ['doctor-consults'] when get:
        final active = q['active'] != 'false';
        final l = _db.where('doctor_consults', (c) => !active || c['status'] == 'ringing' || c['status'] == 'in_call');
        return _db.sorted(l, 'created_at', desc: true).take(30).map(_consultView).toList();
      case ['doctor-consults', final cid] when get:
        return _consultView(_consultOr404(cid));
      case ['doctor-consults', final cid, 'status']:
        return _updateConsult(cid, b);
      case ['notifications', final nid, 'action']:
        final n = _db.byId('notifications', nid);
        if (n == null) throw LocalHttpError(404, 'Notifikasi tidak ditemukan');
        final action = b['action'];
        if (action == 'answer') {
          n.addAll({'status': 'joined', 'read_at': nowIso()});
        } else if (action == 'decline') {
          n.addAll({'status': 'declined', 'read_at': nowIso()});
        } else {
          n['read_at'] ??= nowIso();
        }
        return {'ok': true};
      case ['patients', final pid, 'family-messages']:
        _patientOr404(pid);
        final c = _db.one('contacts', (c) => c['id'] == b['contact_id'] && c['patient_id'] == pid);
        if (c == null) throw LocalHttpError(400, 'Kontak bukan keluarga pasien ini');
        final mid = newId();
        _db.insert('family_messages', {'id': mid, 'patient_id': pid, 'from_contact_id': c['id'], 'kind': 'text', 'text': '${b['text']}'.trim(),
          'status': 'pending', 'delivered_session_id': null, 'created_at': nowIso()});
        return {'id': mid, 'status': 'pending'};
      // ---------- fitur keluarga ----------
      case ['patients', final pid, 'care'] when get:
        _patientOr404(pid);
        return care(pid);
      case ['patients', final pid, 'meds', 'dose']:
        _patientOr404(pid);
        dialog.observe(pid, null, 'dose', {'name': b['name'], 'time': b['time'], 'status': b['status'] ?? 'taken'}, 'dicatat keluarga', source: 'family');
        if ((b['status'] ?? 'taken') == 'taken') {
          final st = _db.one('med_stock', (m) => m['patient_id'] == pid && m['name'] == b['name']);
          if (st != null) st['pills_left'] = ((st['pills_left'] as int) - (st['per_dose'] as int)).clamp(0, 999);
        }
        return care(pid);
      case ['patients', final pid, 'meds', 'refill']:
        _patientOr404(pid);
        for (final st in _db.where('med_stock', (m) => m['patient_id'] == pid && (b['name'] == null || m['name'] == b['name']))) {
          st['pills_left'] = (st['pills_left'] as int) + (st['refill_size'] as int);
          st['last_refill'] = nowIso();
        }
        // Obat sudah diambil: tindak lanjut "obat habis" hari ini selesai.
        for (final a in _db.where('alerts', (a) => a['patient_id'] == pid && a['status'] != 'closed')) {
          if ((a['reasons'] as List).every((r) => r['code'] == 'MED_OUT')) a.addAll({'status': 'closed', 'updated_at': nowIso()});
        }
        return care(pid);
      case ['patients', final pid, 'intake']:
        _patientOr404(pid);
        final today = dateIso(wibNow());
        var row = _db.one('intake', (r) => r['patient_id'] == pid && r['date'] == today);
        if (row == null) {
          row = {'id': newId(), 'patient_id': pid, 'date': today, 'water': 0, 'salt': 0.0};
          _db.insert('intake', row);
        }
        final delta = (b['delta'] as num?) ?? 1;
        if (b['kind'] == 'water') {
          row['water'] = ((row['water'] as num) + delta).clamp(0, 16).toInt();
        } else {
          row['salt'] = ((row['salt'] as num) + delta).clamp(0, 6).toDouble();
        }
        return care(pid);
      case ['patients', final pid, 'family-calls']:
        _patientOr404(pid);
        _db.insert('family_calls', {'id': newId(), 'patient_id': pid, 'contact_id': b['contact_id'], 'at': nowIso(), 'minutes': (b['minutes'] as num?)?.toInt() ?? 5});
        return care(pid);
      case ['patients', final pid, 'report'] when get:
        _patientOr404(pid);
        return report(pid, (int.tryParse(q['days'] ?? '') ?? 30).clamp(7, 30));
    }
    throw LocalHttpError(404, 'Not Found');
  }

  // ---------- util ----------

  int _age(int birthYear) => wibNow().year - birthYear;
  String _todayStart() => iso(startOfDay(wibNow()));

  Row _patientOr404(String pid) => _db.byId('patients', pid) ?? (throw LocalHttpError(404, 'Pasien tidak ditemukan'));
  Row _alertOr404(String aid) => _db.byId('alerts', aid) ?? (throw LocalHttpError(404, 'Alert tidak ditemukan'));
  Row _consultOr404(String cid) => _db.byId('doctor_consults', cid) ?? (throw LocalHttpError(404, 'Konsultasi tidak ditemukan'));

  J _publicPatient(Row p) => {
    'id': p['id'], 'display_name': p['display_name'], 'full_name': p['full_name'], 'age': _age(p['birth_year'] as int), 'sex': p['sex'],
    'village': p['village'], 'preferred_language': p['preferred_language'], 'call_time_local': p['call_time_local'], 'conditions': p['conditions'],
    'medications': p['medications'], 'has_bp_monitor': p['has_bp_monitor'] == 1,
  };

  Iterable<Row> _obsSince(String pid, String kind, int days) {
    final since = iso(wibNow().subtract(Duration(days: days)));
    return _db.sorted(_db.where('observations', (o) => o['patient_id'] == pid && o['kind'] == kind && (o['observed_at'] as String).compareTo(since) >= 0),
        'observed_at');
  }

  List<J> _bpHistory(String pid, [int days = 7]) =>
      [for (final r in _obsSince(pid, 'blood_pressure', days)) {...(r['value'] as Map).cast<String, dynamic>(), 'at': r['observed_at'], 'source': r['source']}];

  J _adherence(String pid, [int days = 7]) {
    final items = [for (final r in _obsSince(pid, 'adherence', days)) {...(r['value'] as Map).cast<String, dynamic>(), 'at': r['observed_at']}];
    return {'taken': items.where((i) => i['status'] == 'sudah').length, 'total': items.length, 'days': items};
  }

  Row? _todayCall(String pid) => _db
      .sorted(_db.where('call_sessions', (c) => c['patient_id'] == pid && (c['started_at'] as String).compareTo(_todayStart()) >= 0), 'started_at', desc: true)
      .firstOrNull;

  J _alertView(Row a) {
    final p = _db.byId('patients', a['patient_id'] as String)!;
    final hospital = _db.byId('hospitals', a['target_hospital_id'] as String?);
    final meds = (p['medications'] as List).cast<Map>();
    final initials = (p['full_name'] as String).replaceAll('(fiktif)', '').split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
    return {
      'id': a['id'], 'level': a['level'], 'status': a['status'], 'source': a['source'], 'session_id': a['session_id'], 'reasons': a['reasons'],
      'screening': a['screening'], 'last_known_well': a['last_known_well'], 'lkw_note': a['lkw_note'], 'golden_period_deadline': a['golden_period_deadline'],
      'hospital': hospital == null ? null : {'id': hospital['id'], 'name': hospital['name'], 'has_ct_24h': hospital['has_ct_24h'] == 1},
      'eta_minutes': a['eta_minutes'], 'acknowledged_by': a['acknowledged_by'], 'acknowledged_at': a['acknowledged_at'],
      'created_at': a['created_at'], 'updated_at': a['updated_at'],
      'patient': {'id': p['id'], 'display_name': p['display_name'], 'initials': initials, 'age': _age(p['birth_year'] as int), 'sex': p['sex'],
        'village': p['village'], 'medications': meds, 'anticoagulant': meds.any((m) => m['is_anticoagulant'] == true)},
      'contacts': [for (final c in esc.contactsFor(p['id'] as String)) {'name': c['name'], 'role': c['role'], 'relation': c['relation'], 'phone': c['phone_e164']}],
    };
  }

  // ---------- pasien & puskesmas ----------

  J _patientDetail(String pid) {
    final p = _patientOr404(pid);
    final sessions = _db.sorted(_db.where('call_sessions', (c) => c['patient_id'] == pid), 'started_at', desc: true).take(10);
    return {
      ..._publicPatient(p),
      'contacts': [for (final c in esc.contactsFor(pid)) {'id': c['id'], 'role': c['role'], 'name': c['name'], 'relation': c['relation']}],
      'bp_history': _bpHistory(pid, 14),
      'adherence_7d': _adherence(pid),
      'memories': [
        for (final m in _db.sorted(_db.where('memories', (m) => m['patient_id'] == pid), 'created_at', desc: true).take(5))
          {'fact': m['fact'], 'category': m['category'], 'created_at': m['created_at']},
      ],
      'vitals': vitals.summary(pid),
      'sessions': [
        for (final s in sessions)
          {for (final k in ['id', 'trigger', 'status', 'final_level', 'outcome', 'started_at', 'ended_at', 'summary', 'family_talking_points']) k: s[k]},
      ],
      'alerts': _db.sorted(_db.where('alerts', (a) => a['patient_id'] == pid), 'created_at', desc: true).take(5).map(_alertView).toList(),
      'care': care(pid),
    };
  }

  J _daftarTilik() {
    final start = _todayStart();
    final rows = <J>[];
    for (final p in _db.where('patients', (p) => p['active'] == 1)) {
      final pid = p['id'] as String;
      final call = _todayCall(pid);
      final alerts = _db.sorted(
          _db.where('alerts', (a) => a['patient_id'] == pid && a['status'] != 'closed' && (a['created_at'] as String).compareTo(start) >= 0), 'created_at',
          desc: true);
      final bp = _bpHistory(pid, 30);
      final adh = _adherence(pid);
      String status;
      if (alerts.any((a) => a['level'] == 'red')) {
        status = 'red';
      } else if (alerts.any((a) => a['level'] == 'yellow')) {
        status = 'yellow';
      } else if (call != null && (call['status'] == 'ringing' || call['status'] == 'in_progress')) {
        status = 'in_progress';
      } else if (call != null && call['status'] == 'no_answer') {
        status = 'no_answer';
      } else if (call != null && call['status'] == 'completed') {
        status = (call['final_level'] as String?) ?? 'green';
      } else {
        status = 'scheduled';
      }
      rows.add({
        'patient': _publicPatient(p), 'status': status,
        'call': call == null ? null : {for (final k in ['id', 'status', 'final_level', 'outcome', 'started_at', 'ended_at', 'summary']) k: call[k]},
        'last_bp': bp.lastOrNull, 'adherence_7d': {'taken': adh['taken'], 'total': adh['total']},
        'follow_up': [for (final a in alerts) for (final r in (a['reasons'] as List)) r['label']], 'open_alerts': [for (final a in alerts) a['id']],
      });
    }
    const order = {'red': 0, 'yellow': 1, 'no_answer': 2, 'in_progress': 3, 'scheduled': 4, 'green': 5};
    rows.sort((a, c) {
      final x = (order[a['status']] ?? 9).compareTo(order[c['status']] ?? 9);
      return x != 0 ? x : '${a['patient']['display_name']}'.compareTo('${c['patient']['display_name']}');
    });
    return {
      'date': dateIso(wibNow()), 'puskesmas': esc.puskesmasName,
      'counts': {for (final k in order.keys) k: rows.where((r) => r['status'] == k).length}, 'rows': rows,
    };
  }

  // ---------- panggilan ----------

  J _startCall(J b) {
    final pid = '${b['patient_id']}';
    _patientOr404(pid);
    for (final old in _db.where('call_sessions', (c) => c['patient_id'] == pid && c['status'] == 'ringing')) {
      old.addAll({'status': 'failed', 'outcome': 'superseded', 'ended_at': nowIso()});
    }
    final s = dialog.createSession(pid);
    if (b['auto_answer'] == true) return dialog.answer(s['id'] as String).asMap();
    return {'session_id': s['id'], 'state': 'RINGING', 'status': 'ringing'};
  }

  List<J> _liveCalls() => [
    for (final c in _db.sorted(_db.where('call_sessions', (c) => c['status'] == 'ringing' || c['status'] == 'in_progress'), 'started_at', desc: true))
      {'id': c['id'], 'patient_id': c['patient_id'], 'display_name': _db.byId('patients', c['patient_id'] as String)?['display_name'], 'status': c['status'],
       'state': c['state'], 'trigger': c['trigger'], 'started_at': c['started_at']},
  ];

  J _callDetail(String sid) {
    final s = _db.byId('call_sessions', sid) ?? (throw LocalHttpError(404, 'Sesi tidak ditemukan'));
    final p = _patientOr404(s['patient_id'] as String);
    final ctx = (s['ctx'] as Map).cast<String, dynamic>();
    final codeword = p['family_codeword'] as String;
    final turns = [
      for (final t in _db.where('call_turns', (t) => t['session_id'] == sid))
        {'speaker': t['speaker'], 'state': t['state'], 'text': (t['text'] as String).replaceAll(codeword, '•••••'), 'ts': t['ts']},
    ];
    final obs = _db.sorted(_db.where('observations', (o) => o['session_id'] == sid), 'observed_at');
    return {
      'id': sid, 'patient': _publicPatient(p), 'status': s['status'], 'state': s['state'], 'state_label': dialog.stateLabels[s['state']] ?? s['state'],
      'level': ctx['level'] ?? s['final_level'] ?? 'green', 'final_level': s['final_level'], 'outcome': s['outcome'], 'summary': s['summary'],
      'talking_points': s['family_talking_points'], 'findings': ctx['findings'] ?? [], 'screen': ctx['screen'] ?? {}, 'alert_id': ctx['alert_id'],
      'turns': turns,
      'observations': [for (final o in obs) {'kind': o['kind'], 'value': o['value'], 'verbatim': o['verbatim'], 'source': o['source'], 'observed_at': o['observed_at']}],
      'started_at': s['started_at'], 'ended_at': s['ended_at'],
    };
  }

  J _postEvent(J b) {
    final pid = '${b['patient_id']}';
    _patientOr404(pid);
    final type = '${b['type']}';
    final source = '${b['source'] ?? 'wearable'}';
    final payload = (b['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    if (type == 'fall_detected') {
      _db.insert('events', {'id': newId(), 'patient_id': pid, 'source': source, 'type': type, 'payload': payload, 'occurred_at': nowIso(), 'handled_level': 'pending'});
      final s = dialog.createSession(pid, trigger: 'fall');
      return {'action': 'calling_patient', 'session_id': s['id'], 'level': 'green'};
    }
    if (type == 'bp_reading') {
      final sys = (payload['systolic'] as num? ?? 0).toInt(), dia = (payload['diastolic'] as num? ?? 0).toInt();
      final f = safety.assessBp(sys, dia, {}, 'tensimeter: $sys/$dia');
      _db.insert('observations', {'id': newId(), 'patient_id': pid, 'session_id': null, 'kind': 'blood_pressure',
        'value': {'systolic': sys, 'diastolic': dia, 'confirmed': true}, 'verbatim': 'perangkat', 'source': source, 'observed_at': nowIso()});
      if (f != null) return {'action': 'follow_up', 'level': f.level, 'alert_id': esc.openAlert(pid, null, f.level, 'event:$source', [f.asReason()])};
      return {'action': 'logged', 'level': 'green'};
    }
    return esc.handleEvent(pid, source, type, payload);
  }

  // ---------- keluarga ----------

  J _contactFeed(String cid) {
    final c = _db.byId('contacts', cid) ?? (throw LocalHttpError(404, 'Kontak tidak ditemukan'));
    final pid = c['patient_id'] as String;
    final p = _patientOr404(pid);
    final notes = _db.sorted(_db.where('notifications', (n) => n['contact_id'] == cid), 'created_at', desc: true).take(40).toList();
    final red = _db.sorted(_db.where('alerts', (a) => a['patient_id'] == pid && a['level'] == 'red' && a['status'] != 'closed'), 'created_at', desc: true).firstOrNull;
    final today = _todayCall(pid);
    final dc = _db.sorted(_db.where('doctor_consults', (d) => d['contact_id'] == cid && (d['status'] == 'ringing' || d['status'] == 'in_call')), 'created_at',
        desc: true).firstOrNull;
    return {
      'contact': {for (final k in ['id', 'role', 'name', 'relation']) k: c[k]},
      'patient': {..._publicPatient(p), 'phone': p['phone_e164']},
      'today': today == null ? null : {'status': today['status'], 'final_level': today['final_level']},
      'latest_report': notes.where((n) => n['kind'] == 'daily_report').firstOrNull,
      'bp_history': _bpHistory(pid, 7),
      'adherence_7d': _adherence(pid),
      'vitals': vitals.summary(pid),
      'red_alert': red == null ? null : _alertView(red),
      'incoming_call': notes.where((n) => n['channel'] == 'call_sim' && n['status'] == 'ringing').firstOrNull,
      'notifications': notes,
      'pending_messages': [
        for (final m in _db.sorted(_db.where('family_messages', (m) => m['from_contact_id'] == cid), 'created_at', desc: true).take(5))
          {'id': m['id'], 'text': m['text'], 'status': m['status'], 'created_at': m['created_at']},
      ],
      'doctor': {...esc.doctor, 'suggest': _healthConcerns(pid)},
      'doctor_consult': dc == null ? null : _consultView(dc),
      'care': care(pid),
    };
  }

  J _healthConcerns(String pid) {
    final reasons = <String>[];
    var level = 'green';
    final today = _todayCall(pid);
    if (today != null && (today['final_level'] == 'yellow' || today['final_level'] == 'red')) {
      level = safety.maxLevel([level, today['final_level'] as String]);
      reasons.add('Telepon pagi menandai ${today['final_level'] == 'red' ? 'darurat' : 'perlu tindak lanjut'}');
    }
    final alert = _db.sorted(_db.where('alerts', (a) => a['patient_id'] == pid && a['status'] != 'closed'), 'created_at', desc: true).firstOrNull;
    if (alert != null) {
      level = safety.maxLevel([level, alert['level'] as String]);
      reasons.addAll([for (final r in (alert['reasons'] as List)) if ((r['label'] ?? '') != '') r['label'] as String].take(3));
    }
    final v = vitals.summary(pid, 7);
    final th = v['thresholds'] as Map, latest = v['latest'] as Map;
    final bp = (latest['blood_pressure'] as Map?) ?? _bpHistory(pid, 7).lastOrNull;
    if (bp != null && (bp['systolic'] as num? ?? 0) >= 160) {
      level = safety.maxLevel([level, 'yellow']);
      reasons.add('Tensi tinggi ${bp['systolic']}/${bp['diastolic']} mmHg');
    }
    final s = latest['spo2'] as Map?;
    if (s != null && (s['value'] as num) < (th['spo2_low'] as num)) {
      level = safety.maxLevel([level, 'yellow']);
      reasons.add('Oksigen rendah ${(s['value'] as num).round()}%');
    }
    final r = latest['resting_hr'] as Map?;
    if (r != null && (r['value'] as num) >= (th['hr_high_rest'] as num)) {
      level = safety.maxLevel([level, 'yellow']);
      reasons.add('Detak istirahat tinggi ${(r['value'] as num).round()}/menit');
    }
    final adh = _adherence(pid, 7);
    final missed = (adh['total'] as int) - (adh['taken'] as int);
    if (adh['total'] != 0 && missed >= 2) {
      level = safety.maxLevel([level, 'yellow']);
      reasons.add('Obat terlewat $missed hari minggu ini');
    }
    final seen = <String>{};
    return {'level': level, 'reasons': [for (final x in reasons) if (seen.add(x)) x], 'recommended': level != 'green'};
  }

  J _consultView(Row c) {
    final p = _db.byId('patients', c['patient_id'] as String);
    final who = _db.byId('contacts', c['contact_id'] as String);
    return {
      for (final k in ['id', 'patient_id', 'contact_id', 'mode', 'reason', 'level', 'status', 'doctor_note', 'created_at', 'answered_at', 'ended_at']) k: c[k],
      'context': c['context'], 'patient_name': p?['display_name'], 'patient_age': p == null ? null : _age(p['birth_year'] as int),
      'requested_by': who?['name'], 'doctor': esc.doctor,
    };
  }

  J _requestConsult(String pid, J b) {
    final p = _patientOr404(pid);
    final c = _db.one('contacts', (c) => c['id'] == b['contact_id'] && c['patient_id'] == pid);
    if (c == null) throw LocalHttpError(400, 'Kontak bukan wali pasien ini');
    final active = _db.one('doctor_consults', (d) => d['patient_id'] == pid && (d['status'] == 'ringing' || d['status'] == 'in_call'));
    if (active != null) return _consultView(active);
    final concern = _healthConcerns(pid);
    final v = vitals.summary(pid, 7)['latest'] as Map;
    final adh = _adherence(pid, 7);
    final reasons = (concern['reasons'] as List).cast<String>();
    final reason = '${b['reason'] ?? ''}'.trim();
    final id = newId();
    _db.insert('doctor_consults', {
      'id': id, 'patient_id': pid, 'contact_id': c['id'], 'mode': b['mode'] ?? 'video',
      'reason': reason.isNotEmpty ? reason : (reasons.isNotEmpty ? reasons.join('; ') : 'Wali ingin berkonsultasi'), 'level': concern['level'],
      'context': {
        'concerns': reasons, 'conditions': p['conditions'], 'medications': p['medications'], 'blood_pressure': _bpHistory(pid, 7).lastOrNull,
        'heart_rate': v['heart_rate'], 'spo2': v['spo2'], 'adherence_7d': {'taken': adh['taken'], 'total': adh['total']},
      },
      'status': 'ringing', 'doctor_note': null, 'created_at': nowIso(), 'answered_at': null, 'ended_at': null,
    });
    return _consultView(_db.byId('doctor_consults', id)!);
  }

  J _updateConsult(String cid, J b) {
    final c = _consultOr404(cid);
    final status = '${b['status']}';
    final note = '${b['note'] ?? ''}'.trim();
    if (status == 'in_call') {
      c['status'] = 'in_call';
      c['answered_at'] ??= nowIso();
    } else {
      c['status'] = status;
      c['ended_at'] = nowIso();
      if (note.isNotEmpty) c['doctor_note'] = note;
      if (note.isNotEmpty) {
        final contact = _db.byId('contacts', c['contact_id'] as String);
        if (contact != null) esc.notify(contact, c['patient_id'] as String, 'doctor_note', 'app', '🩺 Catatan ${esc.doctor['name']}', note);
      }
    }
    return _consultView(c);
  }

  // ---------- fitur keluarga: obat, asupan, streak, rapor ----------

  static const saltLimit = 1.0; // sdt garam per hari (±5 g, anjuran Kemenkes untuk hipertensi)
  static const waterGoal = 8; // gelas

  String? _adherenceOn(String pid, String date) {
    final l = _db.where('observations', (o) => o['patient_id'] == pid && o['kind'] == 'adherence' && (o['observed_at'] as String).startsWith(date)).toList();
    if (l.isEmpty) return null;
    return (l.last['value'] as Map)['status'] as String?;
  }

  J care(String pid) {
    final now = wibNow();
    final today = dateIso(now);
    final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final morning = _adherenceOn(pid, today);
    final doses = <J>[];
    final meds = <J>[];
    for (final st in _db.where('med_stock', (m) => m['patient_id'] == pid)) {
      final times = (st['times'] as List).cast<String>();
      final perDay = times.length * (st['per_dose'] as int);
      final left = st['pills_left'] as int;
      meds.add({
        'name': st['name'], 'schedule': st['schedule'], 'times': times, 'pills_left': left, 'per_day': perDay,
        'days_left': perDay == 0 ? null : left ~/ perDay, 'refill_size': st['refill_size'], 'last_refill': st['last_refill'],
      });
      for (final t in times) {
        final logged = _db.where('observations', (o) => o['patient_id'] == pid && o['kind'] == 'dose' && (o['observed_at'] as String).startsWith(today) &&
            (o['value'] as Map)['name'] == st['name'] && (o['value'] as Map)['time'] == t).lastOrNull;
        String status;
        String? by;
        if (logged != null) {
          status = (logged['value'] as Map)['status'] == 'taken' ? 'taken' : 'missed';
          by = 'keluarga';
        } else if (t.compareTo('12:00') < 0 && morning != null) {
          status = morning == 'sudah' ? 'taken' : 'missed';
          by = 'telepon KRING';
        } else if (left <= 0) {
          status = 'out';
        } else {
          final late = hm.compareTo(_addHours(t, 3)) > 0;
          status = late ? 'late' : (hm.compareTo(t) >= 0 ? 'due' : 'upcoming');
        }
        doses.add({'name': st['name'], 'time': t, 'status': status, 'by': by});
      }
    }
    doses.sort((a, c) => '${a['time']}'.compareTo('${c['time']}'));

    final intakeRows = _db.sorted(_db.where('intake', (r) => r['patient_id'] == pid), 'date');
    final last7 = intakeRows.length > 7 ? intakeRows.sublist(intakeRows.length - 7) : intakeRows;
    final todayIntake = intakeRows.where((r) => r['date'] == today).firstOrNull ?? {'water': 0, 'salt': 0.0};

    return {
      'meds': meds,
      'doses_today': doses,
      'intake': {
        'today': {'water': todayIntake['water'], 'salt': todayIntake['salt']},
        'goals': {'water': waterGoal, 'salt_max': saltLimit},
        'last7': [for (final r in last7) {'date': r['date'], 'water': r['water'], 'salt': r['salt']}],
      },
      'streaks': _streaks(pid),
    };
  }

  String _addHours(String hhmm, int h) {
    final p = hhmm.split(':').map(int.parse).toList();
    return '${((p[0] + h).clamp(0, 23)).toString().padLeft(2, '0')}:${p[1].toString().padLeft(2, '0')}';
  }

  J _streaks(String pid) {
    final now = wibNow();
    final today = startOfDay(now);
    // Obat: hitung mundur hari berturut-turut "sudah" (hari ini ikut bila sudah tercatat).
    var med = 0;
    for (var d = 0; d < 60; d++) {
      final st = _adherenceOn(pid, dateIso(today.subtract(Duration(days: d))));
      if (d == 0 && st == null) continue;
      if (st != 'sudah') break;
      med++;
    }
    final child = esc.contactsFor(pid).where((c) => c['role'] == 'child').firstOrNull;
    final calls = _db.where('family_calls', (c) => c['patient_id'] == pid).toList();
    bool calledOn(DateTime day) => calls.any((c) => (c['at'] as String).startsWith(dateIso(day)));
    var family = 0;
    for (var d = 0; d < 60; d++) {
      final day = today.subtract(Duration(days: d));
      if (d == 0 && !calledOn(day)) continue;
      if (!calledOn(day)) break;
      family++;
    }
    final weekAgo = iso(today.subtract(const Duration(days: 6)));
    final greenDays = _db
        .where('call_sessions', (c) => c['patient_id'] == pid && (c['started_at'] as String).compareTo(iso(today.subtract(const Duration(days: 29)))) >= 0)
        .where((c) => c['status'] == 'completed' && c['final_level'] == 'green')
        .map((c) => (c['started_at'] as String).substring(0, 10))
        .toSet()
        .length;
    return {
      'medication_days': med,
      'family_call_days': family,
      'family_calls_week': calls.where((c) => (c['at'] as String).compareTo(weekAgo) >= 0).length,
      'called_today': calledOn(today),
      'green_days_30': greenDays,
      'child_name': child?['name'],
    };
  }

  J report(String pid, int days) {
    final p = _patientOr404(pid);
    final today = startOfDay(wibNow());
    final dates = [for (var d = days - 1; d >= 0; d--) dateIso(today.subtract(Duration(days: d)))];
    final bpRows = _bpHistory(pid, days);
    final bpDaily = [
      for (final date in dates)
        () {
          final l = bpRows.where((r) => (r['at'] as String).startsWith(date)).toList();
          return {'date': date, 'systolic': l.lastOrNull?['systolic'], 'diastolic': l.lastOrNull?['diastolic']};
        }(),
    ];
    final adherence = [for (final date in dates) {'date': date, 'status': _adherenceOn(pid, date)}];
    final taken = adherence.where((a) => a['status'] == 'sudah').length;
    final recorded = adherence.where((a) => a['status'] != null).length;
    final since = iso(today.subtract(Duration(days: days - 1)));
    final sessions = _db.where('call_sessions', (c) => c['patient_id'] == pid && (c['started_at'] as String).compareTo(since) >= 0).toList();
    final completed = sessions.where((s) => s['status'] == 'completed').length;
    final noAnswer = sessions.where((s) => s['status'] == 'no_answer').length;
    final alerts = _db.sorted(_db.where('alerts', (a) => a['patient_id'] == pid && (a['created_at'] as String).compareTo(since) >= 0), 'created_at', desc: true);
    final v = vitals.summary(pid, days);
    double? avg(List l) {
      final xs = [for (final x in l) if (x['value'] != null) (x['value'] as num).toDouble()];
      return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    }

    final intake = _db.where('intake', (r) => r['patient_id'] == pid && dates.contains(r['date'])).toList();
    final saltOver = intake.where((r) => (r['salt'] as num) > saltLimit).length;
    final calls = _db.where('family_calls', (c) => c['patient_id'] == pid && (c['at'] as String).compareTo(since) >= 0).toList();
    List<int> sys(Iterable<J> l) => [for (final r in l) if (r['systolic'] != null) r['systolic'] as int];
    final half = bpDaily.length ~/ 2;
    final first = sys(bpDaily.take(half)), second = sys(bpDaily.skip(half));
    double? mean(List<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    final allSys = sys(bpDaily);
    final allDia = [for (final r in bpDaily) if (r['diastolic'] != null) r['diastolic'] as int];
    return {
      'patient': _publicPatient(p),
      'days': days,
      'from': dates.first,
      'to': dates.last,
      'bp_daily': bpDaily,
      'bp_avg': allSys.isEmpty ? null : {'systolic': mean(allSys)!.round(), 'diastolic': mean(allDia)!.round()},
      'bp_trend': {'first_half': mean(first)?.round(), 'second_half': mean(second)?.round()},
      'bp_high_days': allSys.where((s) => s >= 160).length,
      'adherence': adherence,
      'adherence_pct': recorded == 0 ? null : (taken * 100 / recorded).round(),
      'calls': {'completed': completed, 'no_answer': noAnswer, 'total': sessions.length},
      'alerts': [for (final a in alerts) {'level': a['level'], 'created_at': a['created_at'], 'labels': [for (final r in (a['reasons'] as List)) r['label']]}],
      'vitals': {
        'steps_avg': avg((v['daily'] as Map)['steps'] as List)?.round(),
        'sleep_avg_min': avg((v['daily'] as Map)['sleep'] as List)?.round(),
        'resting_hr_avg': avg((v['daily'] as Map)['resting_hr'] as List)?.round(),
        'spo2_min': ((v['daily'] as Map)['spo2'] as List).map((x) => x['value'] as num?).whereType<num>().fold<num?>(null, (a, b) => a == null || b < a ? b : a),
        'steps_daily': (v['daily'] as Map)['steps'],
      },
      'intake': {
        'water_avg': intake.isEmpty ? null : intake.map((r) => r['water'] as num).reduce((a, b) => a + b) / intake.length,
        'salt_avg': intake.isEmpty ? null : intake.map((r) => r['salt'] as num).reduce((a, b) => a + b) / intake.length,
        'salt_over_days': saltOver,
      },
      'family_calls': {'count': calls.length, 'minutes': calls.fold<int>(0, (a, c) => a + (c['minutes'] as int))},
      'streaks': _streaks(pid),
    };
  }
}
