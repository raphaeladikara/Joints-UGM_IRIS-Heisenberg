/// Dialog Manager offline (port `dialog.py`): state machine panggilan harian + skrining stroke.
///
/// GREETING → MEDICATION (→ MED_REASON) → BLOOD_PRESSURE (→ BP_CONFIRM) → SYMPTOMS → STORY → CLOSING
/// Darurat dari state mana pun: STROKE_SCREEN (speech → arms → lkw) → ESCALATING.
library;

import 'clock.dart';
import 'escalation.dart' as esc;
import 'nlu.dart' as nlu;
import 'safety.dart' as safety;
import 'store.dart';

const screenSentence = 'Langit biru di atas desa';

const stateLabels = {
  'RINGING': 'Berdering', 'GREETING': 'Pembuka & kata sandi', 'MEDICATION': 'Cek obat', 'MED_REASON': 'Alasan obat',
  'BLOOD_PRESSURE': 'Cek tensi', 'BP_CONFIRM': 'Konfirmasi tensi', 'SYMPTOMS': 'Cek gejala', 'STORY': 'Cerita hari ini',
  'CLOSING': 'Penutup', 'STROKE_SCREEN': 'Skrining stroke', 'ESCALATING': 'Eskalasi darurat', 'ENDED': 'Selesai',
};

class DialogError implements Exception {
  DialogError(this.status, this.message);
  final int status;
  final String message;
}

class TurnResult {
  TurnResult(this.sessionId, this.tilikText, this.state, this.level, {this.ended = false, this.outcome, this.alertId, List<String>? hints})
      : hints = hints ?? [];
  final String sessionId, tilikText, state, level;
  final bool ended;
  final String? outcome, alertId;
  final List<String> hints;

  Map<String, dynamic> asMap() => {
    'session_id': sessionId, 'tilik_text': tilikText, 'state': state, 'state_label': stateLabels[state] ?? state, 'level': level,
    'ended': ended, 'outcome': outcome, 'alert_id': alertId, 'hints': hints,
  };
}

final _db = Store.instance;

// ---------- penyimpanan sesi ----------

Row createSession(String patientId, {String trigger = 'daily', String direction = 'outbound'}) {
  final patient = _patient(patientId);
  final sid = newId();
  final ctx = {
    'lang': patient['preferred_language'], 'trigger': trigger, 'retries': 0, 'findings': <Map<String, dynamic>>[],
    'symptom_codes': <String>[], 'level': 'green', 'step': null,
    'edu_index': _db.where('call_sessions', (s) => s['patient_id'] == patientId).length,
  };
  _db.insert('call_sessions', {
    'id': sid, 'patient_id': patientId, 'direction': direction, 'trigger': trigger, 'transport': 'app_sim', 'status': 'ringing',
    'state': 'RINGING', 'ctx': ctx, 'final_level': null, 'outcome': null, 'started_at': nowIso(), 'answered_at': null, 'ended_at': null,
    'summary': null, 'family_talking_points': <String>[],
  });
  return session(sid);
}

Row session(String sid) {
  final s = _db.byId('call_sessions', sid);
  if (s == null) throw DialogError(404, 'Sesi tidak ditemukan');
  return s;
}

Row _patient(String pid) {
  final p = _db.byId('patients', pid);
  if (p == null) throw DialogError(404, 'Pasien tidak ditemukan');
  return p;
}

Map<String, dynamic> _ctx(Row s) => s['ctx'] as Map<String, dynamic>;

void _save(String sid, String state, Map<String, dynamic> ctx, [Map<String, dynamic> cols = const {}]) {
  final s = session(sid);
  s['state'] = state;
  s['ctx'] = ctx;
  s.addAll(cols);
}

void _turn(String sid, String speaker, String state, String text) =>
    _db.insert('call_turns', {'session_id': sid, 'speaker': speaker, 'state': state, 'text': text, 'ts': nowIso()});

void observe(String pid, String? sid, String kind, Map<String, dynamic> value, String verbatim, {String source = 'patient_report'}) {
  if (kind == 'blood_pressure') {
    final bp = Content.bp;
    final s = value['systolic'] as int, d = value['diastolic'] as int;
    final vs = (bp['valid_systolic'] as List).cast<num>(), vd = (bp['valid_diastolic'] as List).cast<num>();
    if (!(vs[0] <= s && s <= vs[1] && vd[0] <= d && d <= vd[1])) return;
  }
  _db.insert('observations', {
    'id': newId(), 'patient_id': pid, 'session_id': sid, 'kind': kind, 'value': value, 'verbatim': verbatim, 'source': source,
    'observed_at': nowIso(),
  });
}

// ---------- konteks bahasa ----------

class Speaker {
  Speaker(this.p, this.ctx) {
    final contacts = esc.contactsFor(p['id'] as String);
    child = contacts.where((c) => c['role'] == 'child').firstOrNull;
    sahabat = contacts.where((c) => c['role'] == 'sahabat_tilik').firstOrNull;
  }
  final Row p;
  final Map<String, dynamic> ctx;
  Row? child, sahabat;

  String call(String key, [Map<String, Object?> extra = const {}]) {
    final meds = (p['medications'] as List).cast<Map>();
    final values = <String, Object?>{
      'sapaan': p['display_name'], 'puskesmas': esc.puskesmasName, 'codeword': p['family_codeword'],
      'obat': meds.isNotEmpty ? meds.first['name'] : '', 'anak': child?['name'] ?? 'keluarga', 'sahabat': sahabat?['name'] ?? 'tetangga',
      ...extra,
    };
    return Content.line(key, (ctx['lang'] as String?) ?? 'id', values).replaceAll(RegExp(r'\s+'), ' ').replaceAll(' ,', ',').trim();
  }
}

// ---------- alur utama ----------

TurnResult answer(String sid) {
  final s = session(sid);
  if (s['status'] != 'ringing') throw DialogError(409, 'Panggilan sudah tidak berdering');
  final ctx = _ctx(s);
  final say = Speaker(_patient(s['patient_id'] as String), ctx);
  final text = say.call(ctx['trigger'] == 'fall' ? 'greeting_event_fall' : 'greeting');
  ctx['last_question'] = text;
  _save(sid, 'GREETING', ctx, {'status': 'in_progress', 'answered_at': nowIso()});
  _turn(sid, 'tilik', 'GREETING', text);
  return TurnResult(sid, text, 'GREETING', ctx['level'] as String);
}

TurnResult noAnswer(String sid) {
  final s = session(sid);
  final ctx = _ctx(s);
  _save(sid, 'ENDED', ctx, {'status': 'no_answer', 'outcome': 'no_answer', 'ended_at': nowIso(), 'final_level': 'green'});
  final pid = s['patient_id'] as String;
  if (ctx['trigger'] == 'fall') {
    final reasons = [
      {'path': 'event', 'code': 'FALL_NO_RESPONSE', 'label': Content.label('FALL_NO_RESPONSE'), 'quote': 'panggilan tidak diangkat'},
    ];
    final alertId = esc.openAlert(pid, sid, 'red', 'event:wearable', reasons);
    s['final_level'] = 'red';
    return TurnResult(sid, '', 'ENDED', 'red', ended: true, outcome: 'no_answer', alertId: alertId, hints: ['escalation_started']);
  }
  final prev = _db.sorted(_db.where('call_sessions', (c) => c['patient_id'] == pid && c['id'] != sid && c['status'] != 'ringing'), 'started_at', desc: true);
  var level = 'green';
  String? alertId;
  if (prev.isNotEmpty && prev.first['status'] == 'no_answer') {
    final reasons = [
      {'path': 'rule', 'code': 'NO_ANSWER_2X', 'label': Content.label('NO_ANSWER_2X'), 'quote': '2 panggilan berturut-turut tidak diangkat'},
    ];
    alertId = esc.openAlert(pid, sid, 'yellow', 'scheduler', reasons);
    level = 'yellow';
    s['final_level'] = 'yellow';
  }
  return TurnResult(sid, '', 'ENDED', level, ended: true, outcome: 'no_answer', alertId: alertId);
}

TurnResult hangup(String sid) {
  final s = session(sid);
  if (s['status'] == 'completed' || s['status'] == 'no_answer') {
    return TurnResult(sid, '', 'ENDED', (s['final_level'] as String?) ?? 'green', ended: true, outcome: s['outcome'] as String?);
  }
  return _finish(s, _ctx(s), '', outcome: 'hung_up');
}

TurnResult handle(String sid, String rawText) {
  final s = session(sid);
  if (s['status'] != 'in_progress') throw DialogError(409, 'Panggilan tidak sedang berlangsung');
  final text = rawText.trim();
  final ctx = _ctx(s);
  final state = s['state'] as String;
  final patient = _patient(s['patient_id'] as String);
  final say = Speaker(patient, ctx);
  _turn(sid, 'patient', state, text);

  // 1) Safety Agent jalur aturan, setiap giliran.
  final found = safety.scanText(text);
  final codes = (ctx['symptom_codes'] as List).cast<String>();
  for (final f in found.findings) {
    if (!codes.contains(f.code)) codes.add(f.code);
  }
  ctx['symptom_codes'] = codes;
  final known = (ctx['findings'] as List).map((r) => r['code']).toSet();
  final newRed = found.red.where((f) => !known.contains(f.code)).toList();
  _recordFindings(ctx, found.findings);

  if (newRed.isNotEmpty && state != 'STROKE_SCREEN' && state != 'ESCALATING') {
    for (final f in newRed) {
      observe(patient['id'] as String, sid, 'symptom', {'code': f.code, 'label': Content.label(f.code)}, text, source: 'rule');
    }
    return _startEmergency(s, ctx, patient, say, newRed, text);
  }
  if (newRed.isNotEmpty && ctx['alert_id'] != null) {
    esc.updateAlert(ctx['alert_id'] as String, reasons: [for (final f in newRed) f.asReason()]);
  }

  // 2) Pertanyaan meta: identitas AI & dosis (guardrail).
  if (state != 'STROKE_SCREEN' && state != 'ESCALATING') {
    if (nlu.asksIfAi(text)) {
      return _reply(sid, state, ctx, '${say.call('ai_disclosure')} ${ctx['last_question'] ?? ''}'.trim());
    }
    if (nlu.asksDosage(text)) {
      _recordFindings(ctx, [safety.Finding('DOSAGE_QUESTION', 'yellow', 'follow_up', text)]);
      return _reply(sid, state, ctx, '${say.call('dosage_refusal')} ${ctx['last_question'] ?? ''}'.trim());
    }
  }

  return switch (state) {
    'GREETING' => _greeting(s, ctx, patient, say, text),
    'MEDICATION' => _medication(s, ctx, patient, say, text),
    'MED_REASON' => _applyMedReason(s, ctx, patient, say, text, nlu.medReason(text)),
    'BLOOD_PRESSURE' => _bloodPressure(s, ctx, patient, say, text),
    'BP_CONFIRM' => _bpConfirm(s, ctx, patient, say, text),
    'SYMPTOMS' => _symptoms(s, ctx, patient, say, text),
    'STORY' => _story(s, ctx, patient, say, text),
    'STROKE_SCREEN' => _strokeScreen(s, ctx, patient, say, text),
    _ => throw DialogError(409, 'State $state tidak menerima giliran'),
  };
}

void _recordFindings(Map<String, dynamic> ctx, List<safety.Finding> findings) {
  final list = (ctx['findings'] as List).cast<Map<String, dynamic>>();
  final known = list.map((r) => r['code']).toSet();
  for (final f in findings) {
    if (f.level == 'green' || known.contains(f.code)) continue;
    list.add({...f.asReason(), 'level': f.level});
    known.add(f.code);
  }
  ctx['findings'] = list;
  ctx['level'] = safety.maxLevel([ctx['level'] as String, ...list.map((r) => r['level'] as String)]);
}

TurnResult _reply(String sid, String state, Map<String, dynamic> ctx, String text, {List<String>? hints, bool question = true, String? alertId}) {
  if (question) ctx['last_question'] = text;
  _save(sid, state, ctx);
  _turn(sid, 'tilik', state, text);
  return TurnResult(sid, text, state, ctx['level'] as String, alertId: alertId ?? ctx['alert_id'] as String?, hints: hints);
}

TurnResult? _retry(Row s, Map<String, dynamic> ctx, Speaker say, [String key = 'not_understood']) {
  if (((ctx['retries'] as int?) ?? 0) >= 1) {
    ctx['retries'] = 0;
    return null;
  }
  ctx['retries'] = ((ctx['retries'] as int?) ?? 0) + 1;
  final last = (ctx['last_question'] as String?) ?? '';
  final text = key != 'not_understood' ? say.call(key) : '${say.call('not_understood')} $last'.trim();
  return _reply(s['id'] as String, s['state'] as String, ctx, text, question: false);
}

bool _re(String pattern, String t) => RegExp(pattern).hasMatch(t);

TurnResult _greeting(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  final t = nlu.normalize(text);
  final sid = s['id'] as String;
  if (ctx['trigger'] == 'fall') {
    if (_re(r'(baik|tidak apa|nggak papa|gapapa|ora popo|mboten napa|aman|sehat|ndak papa)', t) &&
        !_re(r'(tolong|sakit|tidak bisa bangun|ora iso tangi)', t)) {
      ctx['retries'] = 0;
      return _reply(sid, 'SYMPTOMS', ctx, 'Syukurlah. ${say.call('ask_symptoms')}');
    }
    if (_re(r'(tolong|sakit|tidak bisa|ora iso|jatuh|aduh)', t) || nlu.yesNo(text) == false) {
      return _startEmergency(s, ctx, patient, say, [safety.Finding('SYNCOPE_FALL', 'red', 'escalate', text)], text);
    }
    final retry = _retry(s, ctx, say);
    if (retry != null) return retry;
    return _startEmergency(s, ctx, patient, say,
        [safety.Finding('FALL_NO_RESPONSE', 'red', 'escalate', text.isEmpty ? 'tidak ada jawaban jelas' : text)], text);
  }
  final firstName = (patient['display_name'] as String).split(' ').last.toLowerCase();
  final yn = nlu.yesNo(text);
  if (yn == true || t.contains(firstName)) {
    ctx['retries'] = 0;
    return _afterIdentity(s, ctx, patient, say);
  }
  if (yn == false) return _finish(s, ctx, say.call('wrong_person'), outcome: 'wrong_person');
  final retry = _retry(s, ctx, say, 'identity_retry');
  if (retry != null) return retry;
  return _finish(s, ctx, say.call('wrong_person'), outcome: 'wrong_person');
}

TurnResult _afterIdentity(Row s, Map<String, dynamic> ctx, Row patient, Speaker say) {
  final parts = <String>[];
  final hints = <String>[];
  final msgs = _db.sorted(_db.where('family_messages', (m) => m['patient_id'] == patient['id'] && m['status'] == 'pending'), 'created_at');
  for (final m in msgs.take(2)) {
    final sender = _db.byId('contacts', m['from_contact_id'] as String)?['name'] ?? 'Keluarga';
    parts.add(say.call('family_message_text', {'pengirim': sender, 'pesan': m['text']}));
  }
  if (msgs.isNotEmpty) {
    ctx['delivered_messages'] = [for (final m in msgs.take(2)) m['id']];
    hints.add('family_message');
  }
  parts.add(say.call('ask_medication'));
  return _reply(s['id'] as String, 'MEDICATION', ctx, parts.join(' '), hints: hints);
}

TurnResult _nextAfterMed(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String prefix) {
  final sid = s['id'] as String;
  if (patient['has_bp_monitor'] == 1) return _reply(sid, 'BLOOD_PRESSURE', ctx, '$prefix ${say.call('ask_bp')}'.trim());
  observe(patient['id'] as String, sid, 'blood_pressure_skipped', {'reason': 'no_monitor'}, '', source: 'system');
  return _reply(sid, 'SYMPTOMS', ctx, '$prefix ${say.call('ask_symptoms')}'.trim());
}

TurnResult _medication(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  var status = nlu.adherence(text);
  if (status == null && nlu.yesNo(text) == true) status = 'sudah';
  if (status == null) {
    final retry = _retry(s, ctx, say);
    if (retry != null) return retry;
    status = 'tidak_tahu';
  }
  ctx['retries'] = 0;
  if (status == 'belum') {
    final reason = nlu.medReason(text);
    if (reason != 'other') return _applyMedReason(s, ctx, patient, say, text, reason);
    ctx['med'] = {'status': 'belum'};
    return _reply(s['id'] as String, 'MED_REASON', ctx, say.call('ask_med_reason'));
  }
  ctx['med'] = {'status': status};
  observe(patient['id'] as String, s['id'] as String, 'adherence', {'status': status}, text);
  _takeDose(patient['id'] as String, status);
  return _nextAfterMed(s, ctx, patient, say, status == 'sudah' ? say.call('med_ack_yes') : '');
}

/// Obat yang diminum mengurangi stok (fitur Jadwal & stok obat).
void _takeDose(String pid, String status) {
  if (status != 'sudah') return;
  for (final m in _db.where('med_stock', (m) => m['patient_id'] == pid && (m['times'] as List).any((t) => '$t'.compareTo('12:00') < 0))) {
    m['pills_left'] = ((m['pills_left'] as int) - (m['per_dose'] as int)).clamp(0, 999);
  }
}

TurnResult _applyMedReason(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text, String reason) {
  ctx['med'] = {'status': 'belum', 'reason': reason};
  observe(patient['id'] as String, s['id'] as String, 'adherence', {'status': 'belum', 'reason': reason}, text);
  final key = switch (reason) {
    'out_of_stock' => 'med_reason_out',
    'forgot' => 'med_reason_forgot',
    'feel_healthy' => 'med_reason_feel_healthy',
    'side_effect' => 'med_reason_side_effect',
    _ => 'med_reason_other',
  };
  if (reason == 'out_of_stock') {
    _recordFindings(ctx, [safety.Finding('MED_OUT', 'yellow', 'follow_up', text)]);
    for (final m in _db.where('med_stock', (m) => m['patient_id'] == patient['id'])) {
      m['pills_left'] = 0;
    }
  } else if (reason == 'side_effect') {
    _recordFindings(ctx, [safety.Finding('MED_SIDE_EFFECT', 'yellow', 'follow_up', text)]);
  }
  final missed = _missedDays(patient['id'] as String);
  if (missed >= 3) {
    _recordFindings(ctx, [safety.Finding('MED_MISSED', 'yellow', 'follow_up', '$missed hari tidak minum obat dalam 7 hari')]);
  }
  return _nextAfterMed(s, ctx, patient, say, say.call(key));
}

int _missedDays(String pid) {
  final since = iso(wibNow().subtract(const Duration(days: 7)));
  return _db
      .where('observations', (o) => o['patient_id'] == pid && o['kind'] == 'adherence' && (o['observed_at'] as String).compareTo(since) >= 0)
      .where((o) => (o['value'] as Map)['status'] == 'belum')
      .length;
}

TurnResult _bloodPressure(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  final sid = s['id'] as String;
  final bp = nlu.parseBp(text);
  if (bp != null) {
    ctx['bp_pending'] = {'systolic': bp.systolic, 'diastolic': bp.diastolic, 'verbatim': text};
    ctx['retries'] = 0;
    final kata = nlu.terbilang(bp.systolic);
    return _reply(sid, 'BP_CONFIRM', ctx, say.call('confirm_bp', {
      'sistolik_kata': kata[0].toUpperCase() + kata.substring(1), 'diastolik_kata': nlu.terbilang(bp.diastolic),
    }));
  }
  if (nlu.notMeasured(text)) {
    observe(patient['id'] as String, sid, 'blood_pressure_skipped', {'reason': 'not_measured'}, text);
    return _reply(sid, 'SYMPTOMS', ctx, '${say.call('bp_skip')} ${say.call('ask_symptoms')}');
  }
  final retry = _retry(s, ctx, say, 'bp_retry');
  if (retry != null) return retry;
  observe(patient['id'] as String, sid, 'blood_pressure_skipped', {'reason': 'not_understood'}, text);
  return _reply(sid, 'SYMPTOMS', ctx, '${say.call('bp_skip')} ${say.call('ask_symptoms')}');
}

TurnResult _bpConfirm(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  final sid = s['id'] as String;
  final corrected = nlu.parseBp(text);
  final pending = ctx['bp_pending'] as Map?;
  if (corrected != null && pending != null && (corrected.systolic != pending['systolic'] || corrected.diastolic != pending['diastolic'])) {
    return _bloodPressure(s, ctx, patient, say, text);
  }
  if (nlu.yesNo(text) == true && pending != null) {
    final sys = pending['systolic'] as int, dia = pending['diastolic'] as int;
    ctx['bp'] = {'systolic': sys, 'diastolic': dia};
    observe(patient['id'] as String, sid, 'blood_pressure', {'systolic': sys, 'diastolic': dia, 'confirmed': true}, pending['verbatim'] as String);
    var ack = say.call('bp_ack');
    if (safety.isHigh(sys, dia)) ack = '$ack ${say.call('bp_high_note')}';
    final f = safety.assessBp(sys, dia, (ctx['symptom_codes'] as List).cast<String>().toSet(), pending['verbatim'] as String);
    if (f != null && f.level == 'red') return _startEmergency(s, ctx, patient, say, [f], text);
    if (f != null) _recordFindings(ctx, [f]);
    ctx.remove('bp_pending');
    return _reply(sid, 'SYMPTOMS', ctx, '$ack ${say.call('ask_symptoms')}');
  }
  // Angka tidak terkonfirmasi tidak pernah dipakai untuk keputusan.
  ctx.remove('bp_pending');
  return _reply(sid, 'BLOOD_PRESSURE', ctx, say.call('bp_retry'));
}

TurnResult _symptoms(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  final sid = s['id'] as String;
  final codes = (ctx['symptom_codes'] as List).cast<String>().toSet();
  final bp = ctx['bp'] as Map?;
  if (bp != null) {
    final f = safety.assessBp(bp['systolic'] as int, bp['diastolic'] as int, codes, text);
    if (f != null && f.level == 'red') return _startEmergency(s, ctx, patient, say, [f], text);
    if (f != null) _recordFindings(ctx, [f]);
  }
  final mild = codes.where((c) => c == 'MILD_SYMPTOM' || c == 'CONFUSION').toList();
  String ack;
  if (mild.isNotEmpty) {
    observe(patient['id'] as String, sid, 'symptom', {'codes': mild, 'label': 'keluhan ringan'}, text);
    ack = say.call('symptom_ack_mild');
  } else {
    observe(patient['id'] as String, sid, 'symptom', {'codes': <String>[], 'label': 'tidak ada keluhan'}, text);
    ack = say.call('symptom_ack_none');
  }
  final memory = _db.sorted(_db.where('memories', (m) => m['patient_id'] == patient['id']), 'created_at', desc: true).firstOrNull;
  String ask;
  if (memory != null) {
    memory['last_used_at'] = nowIso();
    final fact = memory['fact'] as String;
    ask = say.call('memory_opener', {'fakta': fact[0].toLowerCase() + fact.substring(1)});
  } else {
    ask = say.call('ask_story');
  }
  return _reply(sid, 'STORY', ctx, '$ack $ask');
}

TurnResult _story(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  ctx['story'] = text;
  if (nlu.mentionsMissingFamily(text)) ctx['kangen'] = true;
  final key = ctx['level'] == 'yellow' ? 'closing_yellow' : 'closing';
  final closing = say.call(key, {'edukasi': Content.education((ctx['edu_index'] as int?) ?? 0)});
  return _finish(s, ctx, '${say.call('story_ack')} $closing', outcome: 'completed');
}

// ---------- darurat ----------

TurnResult _startEmergency(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, List<safety.Finding> findings, String text) {
  final sid = s['id'] as String;
  _recordFindings(ctx, findings);
  ctx['level'] = 'red';
  final reasons = [for (final f in findings) f.asReason()];
  // Skrining tidak menunda eskalasi: pre-alert IGD & panggilan ke Sahabat Kring/anak dimulai sekarang.
  ctx['alert_id'] ??= esc.openAlert(patient['id'] as String, sid, 'red', 'call', reasons);
  final hints = ['escalation_started'];
  if (findings.any((f) => f.action == 'stroke_screen')) {
    ctx['step'] = 'speech';
    ctx['retries'] = 0;
    return _reply(sid, 'STROKE_SCREEN', ctx, '${say.call('stroke_calm')} ${say.call('stroke_speech')}', hints: hints);
  }
  observe(patient['id'] as String, sid, 'escalation', {'codes': [for (final f in findings) f.code]}, text, source: 'rule');
  return _finish(s, ctx, say.call('urgent_transfer'), outcome: 'escalated', hints: [...hints, 'conference']);
}

TurnResult _strokeScreen(Row s, Map<String, dynamic> ctx, Row patient, Speaker say, String text) {
  final sid = s['id'] as String;
  final step = (ctx['step'] as String?) ?? 'speech';
  final alertId = ctx['alert_id'] as String?;
  final screen = (ctx['screen'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  ctx['screen'] = screen;
  if (step == 'speech') {
    final score = nlu.sentenceSimilarity(text, screenSentence);
    final slurred = safety.scanText(text).red.isNotEmpty || score < 0.6;
    final result = {'speech_repeat': {'said': text, 'match': (score * 100).round() / 100, 'abnormal': slurred}};
    screen.addAll(result);
    observe(patient['id'] as String, sid, 'stroke_screen', result, text);
    if (alertId != null) esc.updateAlert(alertId, screening: result);
    ctx['step'] = 'arms';
    return _reply(sid, 'STROKE_SCREEN', ctx, say.call('stroke_arms'));
  }
  if (step == 'arms') {
    final t = nlu.normalize(text);
    var weak = _re(r'(turun|lemas|lemes|lemah|tidak bisa|ora iso|mboten saged|berat|abot|jatuh|ngglewer|kiri|kanan|kiwa|tengen)', t);
    if (_re(r'^(tidak|nggak|mboten|ora|ndak)( ada)?\b', t) && !_re(r'(tidak bisa|ora iso|mboten saged)', t)) weak = false;
    final result = {'arm_drift': {'said': text, 'abnormal': weak}};
    screen.addAll(result);
    observe(patient['id'] as String, sid, 'stroke_screen', result, text);
    if (alertId != null) esc.updateAlert(alertId, screening: result);
    ctx['step'] = 'lkw';
    return _reply(sid, 'STROKE_SCREEN', ctx, say.call('stroke_lkw'));
  }
  final parsed = nlu.parseTimeOfDay(text);
  if (parsed == null) {
    final retry = _retry(s, ctx, say, 'stroke_lkw_retry');
    if (retry != null) return retry;
  }
  final note = parsed?.note ?? 'tidak diketahui';
  observe(patient['id'] as String, sid, 'last_known_well', {'time': parsed == null ? null : iso(parsed.when), 'approx': parsed?.approx}, text);
  final meds = (patient['medications'] as List).cast<Map>();
  final anticoag = meds.any((m) => m['is_anticoagulant'] == true) ? 'ya' : 'tidak (menurut profil)';
  if (alertId != null) {
    esc.updateAlert(alertId, lkw: parsed?.when, lkwNote: note, screening: {'anticoagulant': anticoag, 'medications': [for (final m in meds) m['name']]});
  }
  return _finish(s, ctx, say.call('stroke_transfer'), outcome: 'escalated', hints: ['conference']);
}

// ---------- penutupan panggilan ----------

TurnResult _finish(Row s, Map<String, dynamic> ctx, String text, {required String outcome, List<String>? hints}) {
  final sid = s['id'] as String, pid = s['patient_id'] as String;
  final patient = _patient(pid);
  final state = outcome == 'escalated' ? 'ESCALATING' : 'CLOSING';
  if (text.isNotEmpty) _turn(sid, 'tilik', state, text);
  final level = ctx['level'] as String;
  final summary = _summary(ctx, outcome);
  final points = outcome == 'completed' ? _talkingPoints(ctx, patient) : <String>[];
  _save(sid, state, ctx, {
    'status': 'completed', 'outcome': outcome, 'ended_at': nowIso(), 'final_level': level, 'summary': summary, 'family_talking_points': points,
  });
  for (final mid in ((ctx['delivered_messages'] as List?) ?? const [])) {
    final m = _db.byId('family_messages', mid as String);
    if (m != null) {
      m['status'] = 'delivered';
      m['delivered_session_id'] = sid;
    }
  }
  var alertId = ctx['alert_id'] as String?;
  if (outcome == 'completed') {
    if (level == 'yellow') {
      alertId = esc.openAlert(pid, sid, 'yellow', 'call',
          [for (final r in (ctx['findings'] as List).cast<Map<String, dynamic>>()) if (r['level'] == 'yellow') r]);
    }
    _dailyReport(patient, sid, ctx, summary, points);
  }
  return TurnResult(sid, text, state, level, ended: true, outcome: outcome, alertId: alertId, hints: hints);
}

String _summary(Map<String, dynamic> ctx, String outcome) {
  final med = (ctx['med'] as Map?) ?? const {};
  const reasonLabel = {'out_of_stock': 'obat habis', 'forgot': 'lupa', 'feel_healthy': 'merasa sehat', 'side_effect': 'efek samping', 'other': 'alasan lain'};
  var parts = <String>[];
  if (med.isNotEmpty) {
    parts.add('Obat: ${med['status'] == 'sudah' ? 'sudah diminum' : med['status'] == 'belum' ? 'belum (${reasonLabel[med['reason']] ?? 'tanpa alasan'})' : 'tidak tahu'}');
  }
  final bp = ctx['bp'] as Map?;
  if (bp != null) parts.add('Tensi ${bp['systolic']}/${bp['diastolic']} (terkonfirmasi)');
  final flags = [for (final r in (ctx['findings'] as List)) r['label']];
  parts.add(flags.isNotEmpty ? 'Tanda: ${flags.join(', ')}' : 'Tidak ada keluhan berarti');
  if (outcome == 'escalated') {
    parts.add('Dieskalasi ke Sahabat Kring, keluarga, dan IGD');
  } else if (outcome == 'wrong_person') {
    parts = ['Yang mengangkat bukan pasien, tidak ada data medis dibahas'];
  }
  return '${parts.join('. ')}.';
}

List<String> _talkingPoints(Map<String, dynamic> ctx, Row patient) {
  final story = ((ctx['story'] as String?) ?? '').trim();
  if (story.isEmpty || (nlu.noComplaint(story) && story.split(' ').length < 4)) return [];
  var cut = story.length > 140 ? story.substring(0, 140) : story;
  cut = cut.replaceAll(RegExp(r'\.+$'), '');
  final facts = [cut[0].toUpperCase() + cut.substring(1)];
  for (final f in facts) {
    _db.insert('memories', {'id': newId(), 'patient_id': patient['id'], 'fact': f, 'category': 'story', 'source_session_id': null,
      'created_at': nowIso(), 'last_used_at': null});
  }
  return facts;
}

void _dailyReport(Row patient, String sid, Map<String, dynamic> ctx, String summary, List<String> points) {
  final scope = (patient['share_scope'] as Map?) ?? const {};
  final name = patient['display_name'];
  for (final c in esc.contactsFor(patient['id'] as String)) {
    if (c['receives_daily_report'] != 1) continue;
    final lines = <String>[];
    final med = (ctx['med'] as Map?) ?? const {};
    if (scope['medication'] != false && med.isNotEmpty) lines.add('💊 Obat: ${med['status'] == 'sudah' ? 'sudah diminum' : 'belum diminum'}');
    final bp = ctx['bp'] as Map?;
    if (scope['bp'] != false && bp != null) lines.add('🩺 Tensi: ${bp['systolic']}/${bp['diastolic']}');
    if (ctx['level'] == 'yellow') {
      lines.add('🟡 Perlu tindak lanjut Puskesmas: ${[for (final r in (ctx['findings'] as List)) if (r['level'] == 'yellow') r['label']].join(', ')}');
    } else {
      lines.add('🟢 Tidak ada tanda bahaya');
    }
    final shared = scope['stories'] != false ? points : <String>[];
    if (shared.isNotEmpty) lines.add('💬 Bahan obrolan: ${shared.join('; ')}');
    esc.notify(c, patient['id'] as String, 'daily_report', 'whatsapp_sim', 'Rapor pagi $name', lines.join('\n'),
        payload: {'level': ctx['level'], 'talking_points': shared, 'bp': scope['bp'] != false ? bp : null,
          'medication': scope['medication'] != false ? med['status'] : null},
        sessionId: sid);
    if (ctx['kangen'] == true) {
      esc.notify(c, patient['id'] as String, 'nudge', 'whatsapp_sim', '💛 Nudge Kangen', '$name tadi bilang kangen. Telepon 5 menit hari ini?', sessionId: sid);
    }
  }
}
