/// Waktu WIB untuk backend offline. Nilai `DateTime` di sini adalah "jam dinding WIB" yang disimpan sebagai UTC
/// (jamnya sudah digeser +7), supaya hari/jam selalu WIB apa pun zona waktu HP. String keluar ISO-8601 +07:00,
/// sama persis dengan server Python, sehingga perbandingan string tetap urut waktu.
library;

const wibOffset = Duration(hours: 7);
const goldenPeriod = Duration(hours: 4, minutes: 30);

/// Untuk tes: geser jam backend.
Duration clockSkew = Duration.zero;

DateTime wibNow() => DateTime.now().toUtc().add(wibOffset).add(clockSkew);

DateTime startOfDay(DateTime w) => DateTime.utc(w.year, w.month, w.day);

DateTime atHm(DateTime day, String hhmm) {
  final p = hhmm.split(':').map(int.parse).toList();
  return DateTime.utc(day.year, day.month, day.day, p[0], p[1]);
}

String _two(int n) => n.toString().padLeft(2, '0');

String iso(DateTime w) =>
    '${w.year.toString().padLeft(4, '0')}-${_two(w.month)}-${_two(w.day)}T${_two(w.hour)}:${_two(w.minute)}:${_two(w.second)}'
    '.${w.millisecond.toString().padLeft(3, '0')}+07:00';

String nowIso() => iso(wibNow());

String dateIso(DateTime w) => iso(w).substring(0, 10);

/// ISO apa pun (offset apa pun / Z / tanpa offset = WIB) → jam dinding WIB.
DateTime fromIso(String s) {
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
  if (!hasZone) {
    final t = DateTime.parse(s);
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond);
  }
  return DateTime.parse(s).toUtc().add(wibOffset);
}

String fmtHm(String? isoStr) {
  if (isoStr == null) return 'belum diketahui';
  final w = fromIso(isoStr);
  return '${_two(w.hour)}.${_two(w.minute)}';
}
