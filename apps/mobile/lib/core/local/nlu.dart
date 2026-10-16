/// Pemahaman ucapan berbasis aturan (port `apps/api/app/nlu.py`): angka kata Indonesia + Jawa, tensi, jam,
/// ya/tidak, kepatuhan obat. Deterministik, tanpa jaringan.
library;

import 'clock.dart';

const _units = {
  'nol': 0, 'kosong': 0,
  'satu': 1, 'siji': 1, 'setunggal': 1,
  'dua': 2, 'loro': 2, 'kalih': 2,
  'tiga': 3, 'telu': 3, 'tigang': 3, 'telung': 3,
  'empat': 4, 'papat': 4, 'sekawan': 4, 'patang': 4,
  'lima': 5, 'gangsal': 5, 'limang': 5,
  'enam': 6, 'enem': 6, 'nem': 6, 'nenem': 6,
  'tujuh': 7, 'pitu': 7, 'pitung': 7,
  'delapan': 8, 'wolu': 8, 'wolung': 8,
  'sembilan': 9, 'sanga': 9, 'songo': 9, 'sangang': 9,
};
const _whole = {'sepuluh': 10, 'sedasa': 10, 'sebelas': 11, 'seratus': 100, 'satus': 100, 'seket': 50, 'sèket': 50, 'sewidak': 60, 'selawe': 25};
const _tens = {'puluh', 'dasa', 'doso'};
const _hundreds = {'ratus', 'atus'};
const _teen = {'belas', 'welas'};

final _token = RegExp(r"\d+|[a-zèé']+");

bool _has(String pattern, String t) => RegExp(pattern, unicode: true).hasMatch(t);

String normalize(String text) {
  var t = text.toLowerCase();
  t = t.replaceAll(RegExp('[‘’]'), "'");
  t = t.replaceAll(RegExp(r"[^\p{L}\p{N}_\s/.:,'-]", unicode: true), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 'seratus lima puluh per sembilan puluh' → [150, 90].
List<int> extractNumbers(String text) {
  final out = <int>[];
  var total = 0, cur = 0;
  var inNumber = false;
  void flush() {
    if (inNumber) out.add(total + cur);
    total = cur = 0;
    inNumber = false;
  }

  for (final m in _token.allMatches(normalize(text))) {
    final tok = m[0]!;
    final digit = int.tryParse(tok);
    if (digit != null) {
      flush();
      out.add(digit);
      continue;
    }
    if (_whole.containsKey(tok)) {
      final val = _whole[tok]!;
      if (val == 100) {
        total += cur != 0 ? cur * 100 : 100;
        cur = 0;
      } else if (inNumber && cur != 0 && cur % 10 == 0 && val < 10) {
        cur += val;
      } else if (inNumber && cur != 0) {
        flush();
        cur = val;
      } else {
        cur += val;
      }
      inNumber = true;
    } else if (_units.containsKey(tok)) {
      final u = _units[tok]!;
      if (inNumber && cur != 0 && (cur < 10 || cur % 10 != 0)) flush();
      cur += u;
      inNumber = true;
    } else if (_tens.contains(tok) && inNumber) {
      cur = (cur == 0 ? 1 : cur) * 10;
    } else if (_teen.contains(tok) && inNumber) {
      cur = cur + 10;
    } else if (_hundreds.contains(tok) && inNumber) {
      total += (cur == 0 ? 1 : cur) * 100;
      cur = 0;
    } else {
      flush();
    }
  }
  flush();
  return out;
}

class BloodPressure {
  const BloodPressure(this.systolic, this.diastolic);
  final int systolic;
  final int diastolic;
}

BloodPressure? parseBp(String text) {
  final nums = extractNumbers(text);
  for (var i = 0; i < nums.length - 1; i++) {
    final s = nums[i], d = nums[i + 1];
    if (s >= 60 && s <= 260 && d >= 30 && d <= 160 && s > d) return BloodPressure(s, d);
  }
  return null;
}

const _ones = ['', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan'];

String terbilang(int n) {
  if (n == 0) return 'nol';
  final parts = <String>[];
  final h = n ~/ 100, rest = n % 100;
  if (h > 0) parts.add(h == 1 ? 'seratus' : '${_ones[h]} ratus');
  if (rest > 0) {
    if (rest < 10) {
      parts.add(_ones[rest]);
    } else if (rest == 10) {
      parts.add('sepuluh');
    } else if (rest == 11) {
      parts.add('sebelas');
    } else if (rest < 20) {
      parts.add('${_ones[rest - 10]} belas');
    } else {
      final t = rest ~/ 10, o = rest % 10;
      parts.add('${_ones[t]} puluh${o > 0 ? ' ${_ones[o]}' : ''}');
    }
  }
  return parts.join(' ');
}

const _yesWords =
    r'\b(ya|iya|iyo|yo|nggih|inggih|enggih|ggih|leres|betul|benar|bener|sampun|sudah|udah|wis|uwis|wes|sip|oke|ok|boleh|saya sendiri|kula piyambak|aku dhewe|aku dewe|baik|apik|sae)\b';
const _noWords = r'\b(tidak|tak|nggak|ngga|gak|enggak|ndak|mboten|boten|ora|belum|dereng|durung|bukan|salah|keliru|lepat)\b';

bool? yesNo(String text) {
  final t = normalize(text);
  if (_has(_noWords, t)) return false;
  if (_has(_yesWords, t)) return true;
  return null;
}

/// 'sudah' | 'belum' | null.
String? adherence(String text) {
  final t = normalize(text);
  if (_has(r'obat\w*( (saya|kula|ku))? (sudah |sampun |wis |udah )?(habis|telas|entek)', t) || _has(r'\b(telas|entek)\b', t)) return 'belum';
  if (_has(r'\b(belum|dereng|durung|lupa|kelalen|supe|tidak|nggak|mboten|ora|ndak|gak)\b', t)) return 'belum';
  if (_has(r'\b(sudah|sampun|wis|uwis|wes|udah|tadi|barusan|minum)\b', t)) return 'sudah';
  return null;
}

String medReason(String text) {
  final t = normalize(text);
  if (_has(r'\b(habis|telas|entek|kehabisan|ga ada obat|tidak ada obat)\b', t)) return 'out_of_stock';
  if (_has(r'\b(lupa|kelalen|supe|kelupaan)\b', t)) return 'forgot';
  if (_has(r'(efek|mual|gatal|batuk|pusing setelah|pusing habis|bengkak|ga cocok|tidak cocok|mboten cocok|ora cocok)', t)) return 'side_effect';
  if (_has(r'(sehat|sae|baik-baik|ora popo|tidak apa|mboten napa|kuat|tidak terasa|ora krasa|enak)', t)) return 'feel_healthy';
  return 'other';
}

bool noComplaint(String text) => _has(
  r'(tidak ada|nggak ada|ga ada|gak ada|ndak ada|mboten wonten|boten wonten|ora ana|ora ono|sehat|sae|baik|apik|alhamdulillah|aman|biasa saja|tidak|mboten)',
  normalize(text),
);

bool asksIfAi(String text) => _has(
  r'(robot|mesin|manusia|orang beneran|orang asli|tiyang (napa|nopo|menapa)|kamu siapa|sampeyan sinten|panjenengan sinten|ini siapa)',
  normalize(text),
);

bool asksDosage(String text) => _has(
  r'(dosis|berapa (tablet|butir|biji|kali)|boleh (berhenti|stop|ganti|dobel|minum dua)|ganti obat|berhenti minum|sakit apa saya|saya sakit apa|diagnosa)',
  normalize(text),
);

bool mentionsMissingFamily(String text) => _has(r'(kangen|rindu|sepi|kesepian|sendirian terus)', normalize(text));

bool notMeasured(String text) {
  final t = normalize(text);
  return _has(r'(belum|dereng|durung|tidak|nggak|mboten|ora|ndak|lupa)\w* (ukur|ngukur|mengukur|nensi|tensi|punya|gadah|duwe)', t) ||
      _has(r'\b(belum|dereng|durung|tidak punya|ga punya|mboten gadah|ora duwe)\b', t);
}

// ---------- jam terakhir normal ----------

class TimeParse {
  const TimeParse(this.when, this.approx, this.note);
  final DateTime when;
  final bool approx;
  final String note;
}

(int, int)? _hourMinute(String t) {
  var m = RegExp(r'(\d{1,2})[.:](\d{2})').firstMatch(t);
  if (m != null) return (int.parse(m[1]!), int.parse(m[2]!));
  m = RegExp(r'setengah (\w+)', unicode: true).firstMatch(t);
  if (m != null) {
    final nums = extractNumbers(m[1]!);
    if (nums.isNotEmpty && nums[0] >= 1 && nums[0] <= 24) return ((nums[0] - 1) % 24, 30);
  }
  final after = RegExp(r'(?:jam|pukul|tabuh)\s+(.+)').firstMatch(t);
  final segment = after != null ? after[1]! : t;
  final nums = extractNumbers(segment);
  if (nums.isEmpty) return null;
  var hour = nums[0];
  if (hour < 0 || hour > 24) return null;
  var minute = 0;
  if (_has(r'(lewat|liwat) seperempat', segment)) {
    minute = 15;
  } else if (_has('kurang seperempat', segment)) {
    hour -= 1;
    minute = 45;
  } else if (nums.length > 1 && nums[1] >= 0 && nums[1] < 60) {
    if (_has('kurang', segment)) {
      hour -= 1;
      minute = 60 - nums[1];
    } else {
      minute = nums[1];
    }
  }
  return (hour % 24, minute);
}

TimeParse? parseTimeOfDay(String text, [DateTime? ref]) {
  final r = ref ?? wibNow();
  final t = normalize(text);
  final m = RegExp(r'(\w+(?: \w+)?) (menit|jam) (yang )?(lalu|kepungkur|kapungkur|sing wis)', unicode: true).firstMatch(t);
  if (m != null) {
    final nums = extractNumbers(m[1]!);
    if (nums.isNotEmpty) {
      final delta = m[2] == 'menit' ? Duration(minutes: nums.last) : Duration(hours: nums.last);
      return TimeParse(r.subtract(delta), true, m[0]!);
    }
  }
  if (_has(r'\b(barusan|baru saja|nembe mawon|lagi wae|mau wae)\b', t)) return TimeParse(r.subtract(const Duration(minutes: 10)), true, 'barusan');

  final hm = _has(r'(jam|pukul|tabuh|setengah|\d)', t) ? _hourMinute(t) : null;
  if (hm != null) {
    var (hour, minute) = hm;
    if (_has(r'(sore|malam|wengi|dalu|siang|awan)', t) && hour < 12) hour += 12;
    var when = DateTime.utc(r.year, r.month, r.day, hour, minute);
    if (when.isAfter(r.add(const Duration(minutes: 5)))) when = when.subtract(const Duration(days: 1));
    return TimeParse(when, false, text.trim());
  }
  if (_has(r'(tadi malam|semalam|sebelum tidur|wingi bengi|dalu wau|mau bengi)', t)) {
    final y = r.subtract(const Duration(days: 1));
    return TimeParse(DateTime.utc(y.year, y.month, y.day, 21), true, 'sebelum tidur semalam');
  }
  if (_has(r'(subuh|bangun tidur|tangi turu|wungu sare)', t)) {
    var when = DateTime.utc(r.year, r.month, r.day, 5);
    if (when.isAfter(r)) when = when.subtract(const Duration(days: 1));
    return TimeParse(when, true, 'sekitar subuh / bangun tidur');
  }
  return null;
}

double sentenceSimilarity(String said, String target) {
  final saidWords = normalize(said).split(' ').toSet();
  final targetWords = normalize(target).split(' ').where((w) => w.isNotEmpty).toList();
  if (targetWords.isEmpty) return 0;
  return targetWords.where(saidWords.contains).length / targetWords.length;
}
