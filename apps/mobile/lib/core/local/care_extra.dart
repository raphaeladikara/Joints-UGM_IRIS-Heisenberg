/// Jadwal kontrol Prolanis & posyandu lansia + pengingat ambil obat tersambung stok, dan ringkasan suasana hati
/// dari obrolan harian (port bagian yang sama di `care.py`; bentuk JSON harus sama).
library;

import 'backend.dart';
import 'clock.dart';
import 'escalation.dart' show puskesmasName;
import 'store.dart';

final _db = Store.instance;

const prolanisEveryDays = 28;
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const apptTitles = {'prolanis': 'Kontrol Prolanis', 'posyandu': 'Posyandu Lansia'};

DateTime _date(String ymd) => DateTime.utc(int.parse(ymd.substring(0, 4)), int.parse(ymd.substring(5, 7)), int.parse(ymd.substring(8, 10)));

String dayLabelId(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

Map<String, dynamic> _apptView(Row a, DateTime today) => {
  for (final k in ['id', 'kind', 'title', 'place', 'date', 'time', 'note', 'status']) k: a[k],
  'days_until': _date(a['date'] as String).difference(today).inDays,
};

int _cmpAppt(Row a, Row b) {
  final x = '${a['date']}'.compareTo('${b['date']}');
  return x != 0 ? x : '${a['time']}'.compareTo('${b['time']}');
}

Map<String, dynamic> schedule(String pid, List<Map<String, dynamic>> meds) {
  final today = startOfDay(wibNow());
  final t = dateIso(today);
  final upcoming = (_db.where('appointments', (a) => a['patient_id'] == pid && a['status'] == 'scheduled' && (a['date'] as String).compareTo(t) >= 0)
          .toList()
        ..sort(_cmpAppt))
      .map((a) => _apptView(a, today))
      .toList();
  final past = (_db.where('appointments', (a) => a['patient_id'] == pid && (a['status'] != 'scheduled' || (a['date'] as String).compareTo(t) < 0))
          .toList()
        ..sort((a, b) => _cmpAppt(b, a)))
      .take(3)
      .map((a) => _apptView(a, today))
      .toList();
  return {'upcoming': upcoming.take(4).toList(), 'past': past, 'pickup': _pickup(meds, upcoming, today)};
}

/// Kapan obat harus diambil: disambungkan ke sisa stok dan jadwal kontrol Prolanis berikutnya.
Map<String, dynamic>? _pickup(List<Map<String, dynamic>> meds, List<Map<String, dynamic>> upcoming, DateTime today) {
  final active = meds.where((m) => (m['per_day'] as int) > 0).toList();
  if (active.isEmpty) return null;
  final low = active.reduce((a, b) => (b['days_left'] as int) < (a['days_left'] as int) ? b : a);
  final left = low['days_left'] as int;
  final runsOut = today.add(Duration(days: left));
  final visit = upcoming.where((a) => a['kind'] == 'prolanis').firstOrNull;
  final name = low['name'];
  String status, msg;
  DateTime by;
  if (left == 0) {
    (status, by) = ('now', today);
    msg = 'Obat $name habis. Ambil hari ini di Puskesmas, tidak perlu menunggu jadwal kontrol.';
  } else if (visit != null && (visit['days_until'] as int) <= left) {
    (status, by) = ('at_visit', _date(visit['date'] as String));
    msg = 'Stok $name cukup sampai kontrol Prolanis ${dayLabelId(by)}. Ambil obat sekalian saat kontrol.';
  } else if (visit != null || left <= 7) {
    (status, by) = ('before_visit', today.add(Duration(days: left - 1 < 0 ? 0 : left - 1)));
    final sebelum = visit != null ? ', sebelum kontrol Prolanis ${dayLabelId(_date(visit['date'] as String))}' : '';
    msg = 'Stok $name habis ${dayLabelId(runsOut)}$sebelum. Ambil obat paling lambat ${dayLabelId(by)}.';
  } else {
    (status, by) = ('ok', runsOut);
    msg = 'Stok $name aman untuk $left hari.';
  }
  return {'status': status, 'med': name, 'days_left': left, 'runs_out_on': dateIso(runsOut), 'pickup_by': dateIso(by), 'visit_id': visit?['id'],
    'message': msg};
}

void addAppointment(String pid, String kind, String date, String time, String place, String note) {
  _db.insert('appointments', {'id': newId(), 'patient_id': pid, 'kind': kind, 'title': apptTitles[kind], 'place': place.isEmpty ? puskesmasName : place,
    'date': date, 'time': time, 'note': note, 'status': 'scheduled', 'created_at': nowIso()});
}

/// Obat sudah diambil: stok bertambah satu kemasan, tindak lanjut yang hanya "obat habis" ditutup.
void refill(String pid, String? name) {
  for (final st in _db.where('med_stock', (m) => m['patient_id'] == pid && (name == null || m['name'] == name))) {
    st['pills_left'] = (st['pills_left'] as int) + (st['refill_size'] as int);
    st['last_refill'] = nowIso();
  }
  for (final a in _db.where('alerts', (a) => a['patient_id'] == pid && a['status'] != 'closed')) {
    if ((a['reasons'] as List).every((r) => r['code'] == 'MED_OUT')) a.addAll({'status': 'closed', 'updated_at': nowIso()});
  }
}

/// Tandai kontrol selesai/terlewat. Selesai + ambil obat → stok bertambah. Prolanis selesai → jadwal berikutnya 28 hari lagi.
String? markAppointment(String aid, String status, bool pickedUpMeds) {
  final a = _db.byId('appointments', aid);
  if (a == null) return null;
  final pid = a['patient_id'] as String;
  a['status'] = status;
  if (status == 'done' && pickedUpMeds) refill(pid, null);
  if (status == 'done' && a['kind'] == 'prolanis') {
    final hasNext = _db.one('appointments',
        (x) => x['patient_id'] == pid && x['kind'] == 'prolanis' && x['status'] == 'scheduled' && (x['date'] as String).compareTo(a['date'] as String) > 0);
    if (hasNext == null) {
      var next = _date(a['date'] as String).add(const Duration(days: prolanisEveryDays));
      final tomorrow = startOfDay(wibNow()).add(const Duration(days: 1));
      if (next.isBefore(tomorrow)) next = tomorrow;
      addAppointment(pid, 'prolanis', dateIso(next), a['time'] as String, a['place'] as String, '');
    }
  }
  return pid;
}

/// Kalimat pengingat untuk penutup telepon pagi: jadwal hari ini/besok, ambil obat sebelum habis.
List<(String, Map<String, Object?>)> reminders(String pid) {
  final sched = LocalBackend.instance.care(pid)['schedule'] as Map<String, dynamic>;
  final out = <(String, Map<String, Object?>)>[];
  final soon = (sched['upcoming'] as List).cast<Map<String, dynamic>>().where((a) => (a['days_until'] as int) <= 1).firstOrNull;
  final pickup = sched['pickup'] as Map<String, dynamic>?;
  if (soon != null) {
    out.add(('appointment_reminder', {
      'hari': soon['days_until'] == 0 ? 'hari ini' : 'besok', 'jenis': (soon['title'] as String).toLowerCase(),
      'jam': (soon['time'] as String).replaceAll(':', '.'), 'tempat': soon['place'],
    }));
    if (soon['kind'] == 'prolanis' || (pickup != null && pickup['status'] != 'ok')) out.add(('appointment_bring_meds', {}));
  } else if (pickup != null && pickup['status'] == 'before_visit' && (pickup['days_left'] as int) <= 3) {
    out.add(('pickup_reminder', {'obat': pickup['med'], 'sisa': pickup['days_left']}));
  }
  return out;
}

// ---------- suasana hati & kesepian ----------

const _moodScore = {'senang': 1.0, 'biasa': 0.0, 'sedih': -1.0};
const _moodWord = {'senang': 'ceria', 'biasa': 'tenang', 'sedih': 'murung'};

Map<String, dynamic> mood(String pid, [int days = 14]) {
  final today = startOfDay(wibNow());
  final dates = [for (var d = days - 1; d >= 0; d--) dateIso(today.subtract(Duration(days: d)))];
  final byDay = <String, Map<String, dynamic>>{};
  for (final r in _db.sorted(
      _db.where('observations', (o) => o['patient_id'] == pid && o['kind'] == 'mood' && (o['observed_at'] as String).compareTo(dates.first) >= 0),
      'observed_at')) {
    byDay[(r['observed_at'] as String).substring(0, 10)] = {...(r['value'] as Map).cast<String, dynamic>(), 'quote': r['verbatim']};
  }
  final daily = [
    for (final d in dates) {'date': d, 'mood': byDay[d]?['mood'], 'lonely': byDay[d]?['lonely'] == true},
  ];
  final recorded = daily.where((d) => d['mood'] != null).toList();
  final counts = {for (final k in ['senang', 'biasa', 'sedih']) k: recorded.where((d) => d['mood'] == k).length};
  final week = daily.sublist(daily.length - 7);
  final lonely7 = week.where((d) => d['lonely'] == true).length;
  final sad7 = week.where((d) => d['mood'] == 'sedih').length;
  double? score(List<Map<String, dynamic>> ds) {
    final xs = [for (final d in ds) if (d['mood'] != null) _moodScore[d['mood']]! - (d['lonely'] == true ? 0.5 : 0)];
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  final prev = score(daily.sublist(0, daily.length - 7)), last = score(week);
  final trend = prev == null || last == null ? null : (last - prev >= 0.3 ? 'membaik' : (last - prev <= -0.3 ? 'menurun' : 'stabil'));
  final call = _db.sorted(_db.where('family_calls', (c) => c['patient_id'] == pid), 'at', desc: true).firstOrNull;
  final sinceCall = call == null ? null : today.difference(_date(call['at'] as String)).inDays;
  final lonelyDay = (byDay.keys.toList()..sort((a, b) => b.compareTo(a))).where((d) => byDay[d]!['lonely'] == true && '${byDay[d]!['quote'] ?? ''}'.isNotEmpty).firstOrNull;
  final level = lonely7 >= 2 || (lonely7 >= 1 && sinceCall != null && sinceCall >= 4) ? 'nudge' : (lonely7 == 1 || sad7 >= 2 ? 'watch' : 'ok');
  final name = _db.byId('patients', pid)?['display_name'] ?? 'Mbah';
  String? dominant;
  if (recorded.isNotEmpty) {
    for (final k in ['senang', 'biasa', 'sedih']) {
      if (dominant == null || counts[k]! > counts[dominant]!) dominant = k;
    }
  }
  final parts = [lonely7 > 0 ? 'Seminggu ini $name $lonely7× menyebut kangen atau sepi.' : 'Seminggu ini $name tidak menyebut kangen atau sepi.'];
  if (dominant != null) {
    parts.add('Dari obrolan pagi, suasana hatinya umumnya ${_moodWord[dominant]}${trend != null && trend != 'stabil' ? ' dan $trend.' : '.'}');
  }
  if (sinceCall != null) parts.add(sinceCall == 0 ? 'Keluarga sudah menelepon hari ini.' : 'Telepon keluarga terakhir $sinceCall hari lalu.');
  return {
    'days': days, 'daily': daily, 'counts': counts, 'lonely_days_7': lonely7, 'lonely_days': daily.where((d) => d['lonely'] == true).length,
    'sad_days_7': sad7, 'trend': trend, 'days_since_family_call': sinceCall,
    'last_lonely': lonelyDay == null ? null : {'date': lonelyDay, 'quote': byDay[lonelyDay]!['quote']}, 'level': level, 'summary': parts.join(' '),
  };
}
