import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilik/core/local/backend.dart';
import 'package:tilik/core/local/nlu.dart' as nlu;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = LocalBackend.instance;

  Future<dynamic> get(String p) => api.handle('GET', p, null);
  Future<dynamic> post(String p, [Map<String, dynamic>? b]) => api.handle('POST', p, b ?? {});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await api.ensureReady();
    await post('/v1/demo/reset');
  });

  test('konten offline sama dengan sumber tunggal content/', () {
    for (final f in ['scripts.json', 'red_flags.json']) {
      expect(File('assets/content/$f').readAsStringSync(), File('../../content/$f').readAsStringSync(), reason: f);
    }
  });

  test('nlu: angka kata Indonesia + Jawa', () {
    expect(nlu.extractNumbers('seratus lima puluh per sembilan puluh'), [150, 90]);
    expect(nlu.parseBp('satus seket per sangang puluh')!.systolic, 150);
    expect(nlu.terbilang(184), 'seratus delapan puluh empat');
  });

  test('Daftar Tilik: kuning di atas, Bu Sri terjadwal', () async {
    final d = await get('/v1/puskesmas/today');
    final rows = (d['rows'] as List).cast<Map>();
    expect(rows.first['status'], 'yellow');
    expect(rows.firstWhere((r) => r['patient']['id'] == 'p-sri')['status'], 'scheduled');
  });

  test('pagi biasa: pesan titipan, obat, tensi, cerita → rapor hijau', () async {
    final s = await post('/v1/calls', {'patient_id': 'p-sri', 'auto_answer': true});
    final sid = s['session_id'] as String;
    var r = await post('/v1/calls/$sid/turns', {'text': 'Iya, saya sendiri'});
    expect(r['state'], 'MEDICATION');
    expect(r['tilik_text'], contains('Rani minggu depan wisuda'));
    r = await post('/v1/calls/$sid/turns', {'text': 'Sudah tadi habis sarapan'});
    expect(r['state'], 'BLOOD_PRESSURE');
    r = await post('/v1/calls/$sid/turns', {'text': 'seratus empat puluh per sembilan puluh'});
    expect(r['state'], 'BP_CONFIRM');
    r = await post('/v1/calls/$sid/turns', {'text': 'iya betul'});
    expect(r['state'], 'SYMPTOMS');
    r = await post('/v1/calls/$sid/turns', {'text': 'tidak ada keluhan'});
    expect(r['state'], 'STORY');
    expect(r['tilik_text'], contains('tomat'));
    r = await post('/v1/calls/$sid/turns', {'text': 'Tomatnya sudah dipanen, dibagi ke tetangga'});
    expect(r['ended'], true);
    expect(r['level'], 'green');
    final feed = await get('/v1/contacts/c-dika/feed');
    expect(feed['latest_report']['payload']['talking_points'], isNotEmpty);
    expect(feed['care']['streaks']['medication_days'], greaterThan(0));
  });

  test('darurat: bicara pelo → 🔴, skrining, jam onset, golden period', () async {
    final s = await post('/v1/calls', {'patient_id': 'p-sri', 'auto_answer': true});
    final sid = s['session_id'] as String;
    await post('/v1/calls/$sid/turns', {'text': 'iya'});
    var r = await post('/v1/calls/$sid/turns', {'text': 'Ngomongku kok angel, tangan kiwa lemes'});
    expect(r['level'], 'red');
    expect(r['state'], 'STROKE_SCREEN');
    await post('/v1/calls/$sid/turns', {'text': 'langit biru'});
    await post('/v1/calls/$sid/turns', {'text': 'tangan kiri turun'});
    r = await post('/v1/calls/$sid/turns', {'text': 'jam enam lewat empat puluh'});
    expect(r['outcome'], 'escalated');
    final alerts = (await get('/v1/alerts?level=red')) as List;
    expect(alerts.single['golden_period_deadline'], isNotNull);
    expect(alerts.single['hospital']['name'], contains('Wonosari'));
    final tini = await get('/v1/contacts/c-tini/feed');
    expect(tini['incoming_call'], isNotNull);
  });

  test('jam tangan: jatuh, tidak diangkat → 🔴 otomatis', () async {
    final e = await post('/v1/events', {'patient_id': 'p-darmo', 'type': 'fall_detected', 'source': 'wearable'});
    final r = await post('/v1/calls/${e['session_id']}/no-answer');
    expect(r['level'], 'red');
  });

  test('fitur keluarga: obat, air & garam, rapor 30 hari', () async {
    var c = await get('/v1/patients/p-sri/care');
    expect(c['meds'].first['days_left'], 4);
    c = await post('/v1/patients/p-sri/meds/refill');
    expect(c['meds'].first['pills_left'], 34);
    final w0 = c['intake']['today']['water'] as int;
    c = await post('/v1/patients/p-sri/intake', {'kind': 'water', 'delta': 1});
    expect(c['intake']['today']['water'], w0 + 1);
    final rep = await get('/v1/patients/p-sri/report?days=30');
    expect((rep['bp_daily'] as List).length, 30);
    expect(rep['adherence_pct'], greaterThan(50));
    // Pak Harjo: obat habis → ambil obat menutup tindak lanjut kuning.
    await post('/v1/patients/p-harjo/meds/refill');
    final d = await get('/v1/puskesmas/today');
    expect((d['rows'] as List).firstWhere((r) => r['patient']['id'] == 'p-harjo')['open_alerts'], isEmpty);
  });

  Future<dynamic> say(String sid, List<String> lines) async {
    dynamic r;
    for (final l in lines) {
      r = await post('/v1/calls/$sid/turns', {'text': l});
    }
    return r;
  }

  test('F-03: pesan suara anak diputar di telepon', () async {
    final m = await post('/v1/patients/p-sri/family-messages', {'contact_id': 'c-dika', 'audio_b64': 'AAAAGGZ0eXBNNEEg', 'audio_mime': 'audio/mp4', 'duration_s': 7});
    expect(m['kind'], 'audio');
    final a = await get('/v1/family-messages/${m['id']}/audio');
    expect(a['data_b64'], 'AAAAGGZ0eXBNNEEg');
    final s = await post('/v1/calls', {'patient_id': 'p-sri', 'auto_answer': true});
    final r = await say(s['session_id'] as String, ['Iya, saya sendiri']);
    expect(r['hints'], contains('family_voice'));
    final seg = (r['segments'] as List).cast<Map>();
    expect(seg.where((x) => x.containsKey('play')).single['play'], m['id']);
    expect(seg.last['say'], startsWith('Obat tensi'));
    await expectLater(post('/v1/patients/p-sri/family-messages', {'contact_id': 'c-dika'}), throwsA(isA<LocalHttpError>()));
  });

  test('F-19: tidak diangkat → ulang 15 menit → Sahabat Kring cek rumah', () async {
    final s = await post('/v1/calls', {'patient_id': 'p-sri'});
    var r = await post('/v1/calls/${s['session_id']}/no-answer');
    expect(r['hints'], ['retry_scheduled']);
    var st = (await get('/v1/contacts/c-dika/feed'))['no_answer'];
    expect(st['stage'], 'retry_scheduled');
    st = await post('/v1/retries/${st['retry']['id']}/now');
    expect(st['stage'], 'retrying');
    final inc = await get('/v1/patients/p-sri/incoming');
    expect(inc['session']['trigger'], 'retry');
    r = await post('/v1/calls/${inc['session']['id']}/no-answer');
    expect(r['level'], 'yellow');
    final tini = await get('/v1/contacts/c-tini/feed');
    expect(tini['no_answer']['stage'], 'home_check');
    st = await post('/v1/home-checks/${tini['no_answer']['home_check']['id']}', {'result': 'ok', 'note': 'Di sawah'});
    expect(st['stage'], 'checked_ok');
    expect((await get('/v1/alerts/${r['alert_id']}'))['status'], 'closed');
    // Painem (seed): sudah menunggu Bu Sumi.
    final sumi = await get('/v1/contacts/c-sumi/feed');
    expect(sumi['no_answer']['home_check']['contact_id'], 'c-sumi');
    await post('/v1/home-checks/${sumi['no_answer']['home_check']['id']}', {'result': 'help'});
    expect((await get('/v1/contacts/c-joko/feed'))['red_alert'], isNotNull);
  });

  test('jadwal Prolanis/posyandu + ambil obat tersambung stok', () async {
    final sri = (await get('/v1/patients/p-sri/care'))['schedule'];
    expect([for (final a in sri['upcoming']) a['days_until']], [1, 3]);
    expect(sri['pickup']['status'], 'at_visit');
    expect((await get('/v1/patients/p-harjo/care'))['schedule']['pickup']['status'], 'now');
    expect((await get('/v1/patients/p-darmo/care'))['schedule']['pickup']['status'], 'before_visit');
    final c = await post('/v1/appointments/${sri['upcoming'][1]['id']}/status', {'status': 'done', 'picked_up_meds': true});
    expect(c['meds'].first['pills_left'], 34);
    expect((c['schedule']['upcoming'] as List).where((a) => a['kind'] == 'prolanis').first['days_until'], 31);
  });

  test('suasana hati: cerita kangen → tanggapan, pengingat, Nudge Kangen', () async {
    final before = (await get('/v1/patients/p-sri/care'))['mood'];
    expect((before['daily'] as List).length, 14);
    final s = await post('/v1/calls', {'patient_id': 'p-sri', 'auto_answer': true});
    final r = await say(s['session_id'] as String, ['Iya, saya sendiri', 'Sampun', 'Belum ngukur', 'Tidak ada keluhan', 'Sepi, kangen sama Dika']);
    expect(r['tilik_text'], contains('Wajar kalau merasa kangen'));
    expect((r['tilik_text'] as String).toLowerCase(), contains('besok ada posyandu lansia'));
    final after = (await get('/v1/patients/p-sri/care'))['mood'];
    expect(after['lonely_days_7'], (before['lonely_days_7'] as int) + 1);
    final notes = ((await get('/v1/contacts/c-dika/feed'))['notifications'] as List).cast<Map>();
    expect(notes.firstWhere((n) => n['kind'] == 'nudge')['body'], contains('kangen'));
    final rep = await get('/v1/patients/p-painem/report');
    expect((rep['mood']['daily'] as List).length, 30);
  });
}
