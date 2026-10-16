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
}
