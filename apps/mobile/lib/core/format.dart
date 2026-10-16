/// Format waktu WIB (UTC+7) tanpa paket intl. Server mengirim ISO-8601 dengan offset.
library;

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

DateTime? parseIso(String? iso) => iso == null ? null : DateTime.tryParse(iso);

DateTime toWib(DateTime t) => t.toUtc().add(const Duration(hours: 7));

String _two(int n) => n.toString().padLeft(2, '0');

/// "06.40"
String hm(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '–';
  final w = toWib(t);
  return '${_two(w.hour)}.${_two(w.minute)}';
}

/// "Kamis, 16 Okt"
String dayLabel(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '–';
  final w = toWib(t);
  return '${_days[w.weekday - 1]}, ${w.day} ${_months[w.month - 1]}';
}

String shortDay(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '';
  return _days[toWib(t).weekday - 1].substring(0, 3);
}

/// "3 menit lalu"
String ago(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '';
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inSeconds < 60) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

/// Sisa waktu sampai tenggat, "3 j 12 m" (negatif → "lewat").
String remaining(String? deadlineIso) {
  final t = parseIso(deadlineIso);
  if (t == null) return '–';
  final d = t.toUtc().difference(DateTime.now().toUtc());
  if (d.isNegative) return 'lewat ${d.inMinutes.abs()} m';
  return '${d.inHours} j ${_two(d.inMinutes % 60)} m';
}

double remainingFraction(String? deadlineIso, {Duration total = const Duration(hours: 4, minutes: 30)}) {
  final t = parseIso(deadlineIso);
  if (t == null) return 0;
  final d = t.toUtc().difference(DateTime.now().toUtc());
  return (d.inSeconds / total.inSeconds).clamp(0.0, 1.0);
}
