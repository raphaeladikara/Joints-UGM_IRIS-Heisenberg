/// Data demo FIKTIF untuk mode offline (port `seed.py`, diperluas ke riwayat 30 hari untuk rapor bulanan,
/// stok obat, asupan air & garam, dan riwayat telepon keluarga). Nomor +62800… tidak dipakai operator.
library;

import 'dart:math';

import 'clock.dart';
import 'escalation.dart' show puskesmasName;
import 'nlu.dart' as nlu;
import 'protocol.dart' show retryMinutes;
import 'store.dart';

const _hospitals = [
  ('h-wonosari', 'RSUD Wonosari (simulasi)', 'Gunungkidul', 1, 1, -7.9653, 110.6005),
  ('h-pantirahayu', 'RS Panti Rahayu (simulasi)', 'Gunungkidul', 0, 1, -7.9578, 110.6012),
  ('h-saptosari', 'RSUD Saptosari (simulasi)', 'Gunungkidul', 0, 1, -8.0806, 110.5050),
  ('h-rsaugm', 'RS Akademik UGM (simulasi)', 'Sleman', 1, 1, -7.7451, 110.3463),
  ('h-sardjito', 'RSUP Dr. Sardjito (simulasi)', 'Sleman', 1, 1, -7.7683, 110.3737),
];

const _travel = {
  'Kepek, Wonosari': {'h-wonosari': 8, 'h-pantirahayu': 10, 'h-saptosari': 38, 'h-rsaugm': 75, 'h-sardjito': 80},
  'Logandeng, Playen': {'h-wonosari': 15, 'h-pantirahayu': 17, 'h-saptosari': 40, 'h-rsaugm': 65, 'h-sardjito': 70},
  'Pacarejo, Semanu': {'h-wonosari': 20, 'h-pantirahayu': 22, 'h-saptosari': 45, 'h-rsaugm': 85, 'h-sardjito': 90},
  'Karangrejek, Wonosari': {'h-wonosari': 10, 'h-pantirahayu': 12, 'h-saptosari': 36, 'h-rsaugm': 72, 'h-sardjito': 77},
  'Bunder, Patuk': {'h-wonosari': 30, 'h-pantirahayu': 32, 'h-saptosari': 60, 'h-rsaugm': 50, 'h-sardjito': 55},
  'Kemadang, Tanjungsari': {'h-wonosari': 35, 'h-pantirahayu': 37, 'h-saptosari': 25, 'h-rsaugm': 100, 'h-sardjito': 105},
};

const _amlo = {'name': 'amlodipin', 'schedule': '1× pagi', 'is_anticoagulant': false};
const _capto = {'name': 'kaptopril', 'schedule': '2× sehari', 'is_anticoagulant': false};
const _warf = {'name': 'warfarin', 'schedule': '1× malam', 'is_anticoagulant': true};

/// Jam minum per obat (untuk jadwal & stok).
const medTimes = {'amlodipin': ['07:00'], 'kaptopril': ['07:00', '19:00'], 'warfarin': ['19:00']};

class _P {
  const _P(this.id, this.display, this.full, this.birth, this.sex, this.village, this.phone, this.lang, this.time, this.codeword, this.meds,
      this.bpMonitor, this.baseBp, this.contacts, this.today, this.stock, this.salt, this.water, this.childCallsPerWeek, this.missRate);
  final String id, display, full, sex, village, phone, lang, time, codeword;
  final int birth, bpMonitor;
  final List<Map<String, Object>> meds;
  final (int, int)? baseBp;
  final List<(String, String, String, String, String, int, int)> contacts;
  final String? today;
  final Map<String, int> stock; // sisa butir per obat
  final double salt; // rata-rata sdt garam per hari
  final int water; // rata-rata gelas per hari
  final int childCallsPerWeek;
  final double missRate;
}

const _patients = [
  _P('p-sri', 'Bu Sri', 'Sri Rahayu (fiktif)', 1954, 'F', 'Kepek, Wonosari', '+62800000101', 'id', '07:00', 'melati putih', [_amlo], 1, (150, 90),
      [('c-tini', 'sahabat_tilik', 'Bu Tini', 'Tetangga sebelah, 5 menit jalan kaki', '+62800000102', 1, 0),
       ('c-dika', 'child', 'Mas Dika', 'Anak, bekerja di Jakarta', '+62800000103', 2, 1)],
      null, {'amlodipin': 4}, 1.4, 6, 3, 0.1),
  _P('p-harjo', 'Pak Harjo', 'Harjo Sumarto (fiktif)', 1948, 'M', 'Logandeng, Playen', '+62800000201', 'jv', '06:30', 'pari kuning', [_capto], 1, (158, 94),
      [('c-slamet', 'sahabat_tilik', 'Pak Slamet', 'Kader dusun', '+62800000202', 1, 0),
       ('c-wulan', 'child', 'Mbak Wulan', 'Anak, Yogyakarta', '+62800000203', 2, 1)],
      'med_out', {'kaptopril': 0}, 2.1, 5, 2, 0.35),
  _P('p-painem', 'Mbah Painem', 'Painem (fiktif)', 1945, 'F', 'Pacarejo, Semanu', '+62800000301', 'jv', '06:30', 'kendi biru', [_amlo], 0, null,
      [('c-sumi', 'sahabat_tilik', 'Bu Sumi', 'Tetangga', '+62800000302', 1, 0),
       ('c-joko', 'child', 'Mas Joko', 'Anak, Batam', '+62800000303', 2, 1)],
      'no_answer', {'amlodipin': 12}, 1.2, 4, 1, 0.15),
  _P('p-wiryo', 'Pak Wiryo', 'Wiryo Atmojo (fiktif)', 1957, 'M', 'Karangrejek, Wonosari', '+62800000401', 'id', '06:45', 'sepeda onthel', [_amlo], 1, (138, 86),
      [('c-parmi', 'sahabat_tilik', 'Bu Parmi', 'Tetangga depan', '+62800000402', 1, 0),
       ('c-anton', 'child', 'Mas Anton', 'Anak, Semarang', '+62800000403', 2, 1)],
      'green', {'amlodipin': 21}, 0.9, 8, 4, 0.05),
  _P('p-lastri', 'Bu Lastri', 'Sulastri (fiktif)', 1951, 'F', 'Bunder, Patuk', '+62800000501', 'id', '06:45', 'kupu kuning', [_amlo, _capto], 1, (165, 98),
      [('c-yanto', 'sahabat_tilik', 'Pak Yanto', 'Kader posyandu lansia', '+62800000502', 1, 0),
       ('c-ratna', 'child', 'Mbak Ratna', 'Anak, Bandung', '+62800000503', 2, 1)],
      'bp_crisis', {'amlodipin': 9, 'kaptopril': 14}, 2.4, 5, 2, 0.12),
  _P('p-darmo', 'Pak Darmo', 'Sudarmo (fiktif)', 1946, 'M', 'Kemadang, Tanjungsari', '+62800000601', 'id', '09:00', 'gunung kidul', [_amlo, _warf], 1, (142, 84),
      [('c-narti', 'sahabat_tilik', 'Bu Narti', 'Tetangga', '+62800000602', 1, 0),
       ('c-bayu', 'child', 'Mas Bayu', 'Anak, Jakarta', '+62800000603', 2, 1)],
      null, {'amlodipin': 25, 'warfarin': 25}, 1.0, 7, 3, 0.1),
];

/// Suasana hati harian (dari cerita pagi): peluang kesepian & murung per pasien. Painem paling sering kesepian (anak di Batam).
const _moodProfile = {'p-sri': (0.05, 0.05), 'p-harjo': (0.15, 0.15), 'p-painem': (0.45, 0.15), 'p-wiryo': (0.05, 0.05),
  'p-lastri': (0.15, 0.2), 'p-darmo': (0.25, 0.1)};
const _happyLines = ['Tadi ikut pengajian di masjid, senang ketemu teman.', 'Cucu datang menginap, rumah jadi ramai.', 'Panen cabai lumayan banyak.',
  'Ikut senam lansia di balai desa.'];
const _plainLines = ['Biasa saja, di rumah.', 'Menyapu halaman lalu istirahat.', 'Nonton TV sambil melipat baju.'];
const _lonelyLines = ['Sepi, anak-anak jauh semua.', 'Kangen sama anak, sudah lama tidak pulang.', 'Sendirian di rumah, tidak ada teman ngobrol.'];
const _sadLines = ['Semalam susah tidur, kepikiran.', 'Capek, badan pegal semua.'];

/// Jadwal (hari dari sekarang): kontrol Prolanis di Puskesmas & posyandu lansia di dusun. Darmo sengaja: stok habis sebelum kontrol.
const _visits = {'p-sri': (3, 1), 'p-harjo': (9, 5), 'p-painem': (12, 2), 'p-wiryo': (16, 8), 'p-lastri': (6, 0), 'p-darmo': (27, 11)};

const _sriStories = [
  'Tomat di kebun belakang sudah merah, sebentar lagi panen.',
  'Tadi ikut senam lansia di balai desa.',
  'Bikin tempe bacem buat arisan RT.',
  'Ayam Ibu bertelur tiga butir.',
  'Ditelepon Rani, cucu, katanya skripsinya selesai.',
  'Kemarin hujan deras, genteng dapur bocor sedikit.',
];

const _watch = {
  'p-sri': ('watch_sim', 'Jam tangan Bu Sri (simulasi)', 3100, 70, 96, 360),
  'p-harjo': ('apple_health', 'Apple Watch SE (dummy)', 2300, 78, 95, 330),
  'p-painem': ('health_connect', 'Mi Band 8 (dummy)', 1400, 74, 95, 300),
  'p-wiryo': ('health_connect', 'Galaxy Watch5 (dummy)', 5600, 66, 97, 390),
  'p-lastri': ('apple_health', 'Apple Watch Series 8 (dummy)', 2600, 88, 96, 320),
  'p-darmo': ('health_connect', 'Fitbit Inspire 3 (dummy)', 1900, 72, 94, 345),
};

/// Riwayat telepon harian yang di-seed (hari).
const historyDays = 29;

void runSeed() {
  final db = Store.instance..wipe();
  final rng = Random(7);
  final moodRng = Random(11); // terpisah supaya data lain tetap sama
  final now = wibNow();
  final today = startOfDay(now);
  db.seededOn = dateIso(now);

  for (final h in _hospitals) {
    db.insert('hospitals', {'id': h.$1, 'name': h.$2, 'regency': h.$3, 'has_ct_24h': h.$4, 'code_stroke_network': h.$5, 'phone_display': '(0274) xxx-xxxx',
      'lat': h.$6, 'lng': h.$7});
  }
  _travel.forEach((village, rows) {
    rows.forEach((hid, mins) {
      db.insert('travel_times', {'village': village, 'hospital_id': hid, 'minutes': mins, 'source_note': 'estimasi manual dari peta (simulasi)'});
    });
  });

  for (final p in _patients) {
    db.insert('patients', {
      'id': p.id, 'display_name': p.display, 'full_name': p.full, 'birth_year': p.birth, 'sex': p.sex, 'village': p.village, 'phone_e164': p.phone,
      'preferred_language': p.lang, 'call_time_local': p.time, 'family_codeword': p.codeword, 'conditions': ['hypertension'],
      'medications': [for (final m in p.meds) Map<String, dynamic>.from(m)], 'has_bp_monitor': p.bpMonitor,
      'share_scope': {'medication': true, 'bp': true, 'stories': true}, 'active': 1, 'created_at': iso(today.subtract(const Duration(days: 60))),
    });
    for (final c in p.contacts) {
      db.insert('contacts', {'id': c.$1, 'patient_id': p.id, 'role': c.$2, 'name': c.$3, 'relation': c.$4, 'phone_e164': c.$5, 'escalation_order': c.$6,
        'receives_daily_report': c.$7});
    }
    for (final m in p.meds) {
      final name = m['name'] as String;
      db.insert('med_stock', {'id': newId(), 'patient_id': p.id, 'name': name, 'schedule': m['schedule'], 'times': medTimes[name], 'per_dose': 1,
        'pills_left': p.stock[name] ?? 20, 'refill_size': 30, 'last_refill': iso(today.subtract(const Duration(days: 24)))});
    }

    // Riwayat: hijau, sesekali lupa obat. Rapor WA hanya untuk 6 hari terakhir (supaya kotak pesan tidak penuh).
    for (var d = historyDays; d >= 1; d--) {
      final day = today.subtract(Duration(days: d));
      if (p.id == 'p-painem' && (d == 1 || d == 13)) {
        _call(p, atHm(day, p.time), 'no_answer', null, null, null, '', report: false);
        continue;
      }
      final missed = rng.nextDouble() < p.missRate;
      final bp = _bp(rng, p.baseBp, trend: d);
      final story = p.id == 'p-sri' && d <= 6 ? _sriStories[d - 1] : '';
      final sid = _call(p, atHm(day, p.time), 'completed', 'green', missed ? 'belum' : 'sudah', bp, story, reason: missed ? 'forgot' : null, report: d <= 6);
      _mood(p.id, sid, atHm(day, p.time), story.isNotEmpty ? story : _moodLine(moodRng, p.id));
    }

    final t = atHm(today, p.time);
    switch (p.today) {
      case 'green':
        final sid = _call(p, t, 'completed', 'green', 'sudah', _bp(rng, p.baseBp), 'Cucu menginap akhir pekan ini.');
        _mood(p.id, sid, t, 'Cucu menginap akhir pekan ini.');
      case 'med_out':
        final sid = _call(p, t, 'completed', 'yellow', 'belum', _bp(rng, p.baseBp), '', reason: 'out_of_stock');
        _alert(p.id, sid, t, [{'path': 'rule', 'code': 'MED_OUT', 'label': 'Obat habis', 'quote': 'Obatipun sampun telas, Mbak.'}]);
      case 'no_answer':
        // F-19: tidak diangkat → telepon ulang 15 menit → tetap tidak diangkat → Sahabat Kring diminta menengok.
        final first = _call(p, t, 'no_answer', null, null, null, '');
        final t2 = t.add(const Duration(minutes: retryMinutes));
        final second = _call(p, t2, 'no_answer', null, null, null, '', trigger: 'retry');
        db.insert('call_retries', {'id': newId(), 'patient_id': p.id, 'origin_session_id': first, 'due_at': iso(t2), 'status': 'missed', 'session_id': second,
          'created_at': iso(t.add(const Duration(minutes: 1)))});
        final aid = _alert(p.id, second, t2, [
          {'path': 'rule', 'code': 'NO_ANSWER_RETRY', 'label': 'Tidak diangkat, telepon ulang 15 menit juga tidak diangkat',
           'quote': 'tidak diangkat pukul ${fmtHm(iso(t))} dan ${fmtHm(iso(t2))}'},
        ], source: 'scheduler');
        _homeCheck(p, aid, [t, t2]);
      case 'bp_crisis':
        final sid = _call(p, t, 'completed', 'yellow', 'sudah', (184, 104), '');
        _alert(p.id, sid, t, [
          {'path': 'rule', 'code': 'BP_CRISIS_ASYMPTOMATIC', 'label': 'Tensi krisis tanpa gejala (hubungi hari ini)', 'quote': 'seratus delapan puluh empat per seratus empat'},
        ]);
    }

    // Asupan air & garam 30 hari (diisi keluarga/kader; hari ini baru separuh jalan).
    for (var d = historyDays; d >= 0; d--) {
      final day = today.subtract(Duration(days: d));
      final frac = d == 0 ? (now.hour / 20).clamp(0.2, 1.0) : 1.0;
      final water = ((p.water + rng.nextInt(4) - 1) * frac).round().clamp(0, 12);
      var salt = ((p.salt + (rng.nextDouble() - 0.4) * 0.8) * frac * 2).round() / 2;
      if (salt < 0) salt = 0;
      db.insert('intake', {'id': newId(), 'patient_id': p.id, 'date': dateIso(day), 'water': water, 'salt': salt});
    }

    // Telepon anak ke orang tua (untuk streak & Nudge Kangen).
    final child = p.contacts.firstWhere((c) => c.$2 == 'child');
    for (var d = historyDays; d >= 1; d--) {
      if (rng.nextDouble() < p.childCallsPerWeek / 7) {
        final day = today.subtract(Duration(days: d));
        db.insert('family_calls', {'id': newId(), 'patient_id': p.id, 'contact_id': child.$1, 'at': iso(atHm(day, '19:${10 + rng.nextInt(40)}')),
          'minutes': 3 + rng.nextInt(15)});
      }
    }
  }
  // Mas Dika rutin menelepon 4 malam terakhir (streak yang terlihat di demo).
  for (var d = 4; d >= 1; d--) {
    final day = today.subtract(Duration(days: d));
    db.delete('family_calls', (c) => c['contact_id'] == 'c-dika' && (c['at'] as String).startsWith(dateIso(day)));
    db.insert('family_calls', {'id': newId(), 'patient_id': 'p-sri', 'contact_id': 'c-dika', 'at': iso(atHm(day, '19:30')), 'minutes': 6 + d});
  }

  _watch.forEach((pid, w) => _watchData(rng, pid, today, now, w.$1, w.$2, w.$3, w.$4, w.$5, w.$6));

  // Jadwal kontrol Prolanis & posyandu lansia (+ satu kontrol bulan lalu yang sudah selesai).
  for (final p in _patients) {
    final (prolanis, posyandu) = _visits[p.id]!;
    final dusun = p.village.split(',').first;
    for (final (kind, title, place, offset, hm, status) in [
      ('prolanis', 'Kontrol Prolanis', puskesmasName, -25, '08:00', 'done'),
      ('prolanis', 'Kontrol Prolanis', puskesmasName, prolanis, '08:00', 'scheduled'),
      ('posyandu', 'Posyandu Lansia', 'Balai dusun $dusun', posyandu, '09:00', 'scheduled'),
    ]) {
      db.insert('appointments', {'id': newId(), 'patient_id': p.id, 'kind': kind, 'title': title, 'place': place,
        'date': dateIso(today.add(Duration(days: offset))), 'time': hm,
        'note': kind == 'prolanis' ? 'Bawa kartu BPJS & buku kontrol' : 'Timbang, tensi, senam', 'status': status,
        'created_at': iso(today.subtract(const Duration(days: 30)))});
    }
  }

  db.insert('memories', {'id': newId(), 'patient_id': 'p-sri', 'fact': 'Tomat di kebun belakang sudah merah, sebentar lagi panen', 'category': 'hobby',
    'source_session_id': null, 'created_at': iso(today.subtract(const Duration(days: 1))), 'last_used_at': null});
  db.insert('family_messages', {'id': newId(), 'patient_id': 'p-sri', 'from_contact_id': 'c-dika', 'kind': 'text',
    'text': 'Bu, Rani minggu depan wisuda. Sabtu Dika jemput Ibu, ya. Jaga kesehatan.', 'status': 'pending', 'delivered_session_id': null,
    'created_at': iso(now.subtract(const Duration(hours: 10)))});
}

void _obs(String pid, String? sid, String kind, Map<String, dynamic> value, String verbatim, String source, DateTime at) =>
    Store.instance.insert('observations', {'id': newId(), 'patient_id': pid, 'session_id': sid, 'kind': kind, 'value': value, 'verbatim': verbatim,
      'source': source, 'observed_at': iso(at)});

void _watchData(Random rng, String pid, DateTime today, DateTime now, String source, String device, int steps, int rhr, int spo2, int sleep) {
  for (var d = historyDays; d >= 0; d--) {
    final day = today.subtract(Duration(days: d));
    final frac = d > 0 ? 1.0 : ((now.hour * 60 + now.minute - 300) / 900).clamp(0.15, 1.0);
    final n = ((steps + rng.nextInt(steps ~/ 3 + steps ~/ 2) - steps ~/ 3) * frac).toInt();
    _obs(pid, null, 'steps', {'value': n, 'date': dateIso(day)}, device, source, d > 0 ? day.add(const Duration(hours: 12)) : now);
    _obs(pid, null, 'sleep', {'value': sleep + rng.nextInt(111) - 50, 'date': dateIso(day)}, device, source, day.add(const Duration(hours: 5, minutes: 30)));
    _obs(pid, null, 'resting_hr', {'value': (rhr + rng.nextInt(10) - 4).toDouble()}, device, source, day.add(const Duration(hours: 6)));
    _obs(pid, null, 'spo2', {'value': min(99, spo2 + rng.nextInt(4) - 1).toDouble()}, device, source, day.add(const Duration(hours: 4)));
    if (d > 7) continue; // detak per jam hanya 7 hari terakhir
    final lastHour = d > 0 ? 21 : max(6, now.hour);
    for (var h = 6; h <= lastHour; h += 2) {
      _obs(pid, null, 'heart_rate', {'value': (rhr + 2 + rng.nextInt(21) - 6 + (h >= 8 && h <= 10 ? 8 : 0)).toDouble()}, device, source,
          day.add(Duration(hours: h, minutes: 10)));
    }
  }
  Store.instance.insert('device_syncs', {'id': newId(), 'patient_id': pid, 'source': source, 'device': device, 'sample_count': 60,
    'synced_at': iso(now.subtract(const Duration(minutes: 12)))});
}

(int, int)? _bp(Random rng, (int, int)? base, {int trend = 0}) {
  if (base == null) return null;
  // Tensi sedikit lebih tinggi sebulan lalu (obat mulai rutin) supaya tren di rapor bulanan terlihat.
  final drift = (trend / 3).round();
  return (base.$1 + drift + rng.nextInt(17) - 8, base.$2 + drift ~/ 2 + rng.nextInt(11) - 5);
}

String _moodLine(Random rng, String pid) {
  final (lonely, sad) = _moodProfile[pid]!;
  final x = rng.nextDouble();
  final pool = x < lonely ? _lonelyLines : (x < lonely + sad ? _sadLines : (rng.nextDouble() < 0.5 ? _happyLines : _plainLines));
  return pool[rng.nextInt(pool.length)];
}

void _mood(String pid, String sid, DateTime at, String line) => _obs(pid, sid, 'mood', nlu.mood(line), line, 'nlu', at.add(const Duration(minutes: 3)));

void _homeCheck(_P p, String alertId, List<DateTime> missed) {
  final db = Store.instance;
  final sahabat = p.contacts.firstWhere((c) => c.$2 == 'sahabat_tilik');
  final child = p.contacts.firstWhere((c) => c.$2 == 'child');
  final hid = newId();
  final at = iso(missed.last.add(const Duration(minutes: 1)));
  db.insert('home_checks', {'id': hid, 'patient_id': p.id, 'contact_id': sahabat.$1, 'alert_id': alertId, 'status': 'requested', 'note': '',
    'missed_at': [for (final m in missed) iso(m)], 'created_at': at, 'responded_at': null});
  final j1 = fmtHm(iso(missed.first)), j2 = fmtHm(iso(missed.last));
  for (final (cid, kind, title, body) in [
    (sahabat.$1, 'home_check', '🏠 Mohon tengok ${p.display}',
     '${sahabat.$3}, ini Kring dari $puskesmasName. ${p.display} dua kali tidak mengangkat telepon pagi (pukul $j1 dan $j2). '
         'Mohon tengok ke rumah beliau, lalu kabari lewat tombol di aplikasi.'),
    (child.$1, 'home_check_sent', '🏠 ${sahabat.$3} diminta mengecek ${p.display}',
     'KRING sudah menelepon pukul $j1 dan $j2, belum diangkat. ${sahabat.$3} (${sahabat.$4}) diminta menengok ke rumah dan akan mengabari di sini.'),
  ]) {
    db.insert('notifications', {'id': newId(), 'contact_id': cid, 'patient_id': p.id, 'alert_id': alertId, 'session_id': null, 'kind': kind,
      'channel': 'whatsapp_sim', 'title': title, 'body': body, 'payload': {'home_check_id': hid}, 'status': 'sent', 'created_at': at, 'read_at': null});
  }
}

String _call(_P p, DateTime at, String status, String? level, String? adherence, (int, int)? bp, String story,
    {String? reason, bool report = true, String trigger = 'daily'}) {
  final db = Store.instance;
  final sid = newId();
  final points = story.isEmpty ? <String>[] : [story.replaceAll(RegExp(r'\.$'), '')];
  String? summary;
  if (status == 'completed') {
    final bits = ['Obat: ${adherence == 'sudah' ? 'sudah diminum' : 'belum'}', if (bp != null) 'Tensi ${bp.$1}/${bp.$2} (terkonfirmasi)'];
    summary = '${bits.join('. ')}.';
  }
  db.insert('call_sessions', {
    'id': sid, 'patient_id': p.id, 'direction': 'outbound', 'trigger': trigger, 'transport': 'app_sim', 'status': status, 'state': 'ENDED',
    'ctx': <String, dynamic>{}, 'final_level': level, 'outcome': status, 'started_at': iso(at), 'answered_at': status == 'completed' ? iso(at) : null,
    'ended_at': iso(at.add(const Duration(minutes: 4))), 'summary': summary, 'family_talking_points': points,
  });
  if (adherence != null) {
    _obs(p.id, sid, 'adherence', {'status': adherence, 'reason': ?reason}, '', 'patient_report', at.add(const Duration(minutes: 1)));
  }
  if (bp != null) {
    _obs(p.id, sid, 'blood_pressure', {'systolic': bp.$1, 'diastolic': bp.$2, 'confirmed': true}, '', 'patient_report', at.add(const Duration(minutes: 2)));
  }
  if (report && status == 'completed' && level == 'green') {
    final child = p.contacts.firstWhere((c) => c.$2 == 'child');
    var body = '💊 Obat: ${adherence == 'sudah' ? 'sudah diminum' : 'belum diminum'}';
    if (bp != null) body += '\n🩺 Tensi: ${bp.$1}/${bp.$2}';
    body += '\n🟢 Tidak ada tanda bahaya';
    if (points.isNotEmpty) body += '\n💬 Bahan obrolan: ${points.first}';
    db.insert('notifications', {
      'id': newId(), 'contact_id': child.$1, 'patient_id': p.id, 'alert_id': null, 'session_id': sid, 'kind': 'daily_report', 'channel': 'whatsapp_sim',
      'title': 'Rapor pagi ${p.display}', 'body': body,
      'payload': {'level': 'green', 'talking_points': points, 'bp': bp == null ? null : {'systolic': bp.$1, 'diastolic': bp.$2}, 'medication': adherence},
      'status': 'sent', 'created_at': iso(at.add(const Duration(minutes: 5))), 'read_at': iso(at.add(const Duration(minutes: 30))),
    });
  }
  return sid;
}

String _alert(String pid, String sid, DateTime at, List<Map<String, dynamic>> reasons, {String source = 'call'}) {
  final ts = iso(at.add(const Duration(minutes: 4)));
  final aid = newId();
  Store.instance.insert('alerts', {
    'id': aid, 'patient_id': pid, 'session_id': sid, 'level': 'yellow', 'source': source, 'reasons': reasons, 'screening': <String, dynamic>{},
    'last_known_well': null, 'lkw_note': null, 'golden_period_deadline': null, 'target_hospital_id': null, 'eta_minutes': null, 'status': 'open',
    'acknowledged_by': null, 'acknowledged_at': null, 'created_at': ts, 'updated_at': ts,
  });
  return aid;
}
