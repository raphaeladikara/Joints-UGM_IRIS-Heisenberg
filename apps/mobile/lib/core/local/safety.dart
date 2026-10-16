/// Safety Agent jalur aturan (port `safety.py`). Versi offline tidak punya jalur LLM; jalur aturan tetap lengkap.
library;

import 'nlu.dart' as nlu;
import 'store.dart';

const levelRank = {'green': 0, 'yellow': 1, 'red': 2};

String maxLevel(Iterable<String?> levels) {
  var best = 'green';
  for (final lv in levels) {
    if (lv != null && (levelRank[lv] ?? 0) > levelRank[best]!) best = lv;
  }
  return best;
}

class Finding {
  Finding(this.code, this.level, this.action, this.quote, {this.path = 'rule'});
  final String code, level, action, quote, path;

  Map<String, dynamic> asReason() => {'path': path, 'code': code, 'label': Content.label(code), 'quote': quote};
}

class Assessment {
  final findings = <Finding>[];
  List<Finding> get red => findings.where((f) => f.level == 'red').toList();
}

bool _negated(String text, int start, List<String> negations) {
  final from = start - 18 < 0 ? 0 : start - 18;
  final window = text.substring(from, start).split(' ').where((w) => w.isNotEmpty).toList();
  final tail = window.length > 3 ? window.sublist(window.length - 3) : window;
  return tail.any(negations.contains);
}

Assessment scanText(String text) {
  final t = nlu.normalize(text);
  final out = Assessment();
  for (final (rule, pats) in Content.rules) {
    for (final p in pats) {
      final m = p.firstMatch(t);
      if (m != null && !_negated(t, m.start, Content.negations)) {
        out.findings.add(Finding(rule['code'] as String, rule['level'] as String, rule['action'] as String, text.trim()));
        break;
      }
    }
  }
  return out;
}

Finding? assessBp(int systolic, int diastolic, Set<String> symptomCodes, String quote) {
  final cfg = Content.bp;
  final crisis = systolic >= (cfg['crisis_systolic'] as num) || diastolic >= (cfg['crisis_diastolic'] as num);
  const crisisSymptoms = {'SEVERE_HEADACHE', 'CHEST_PAIN', 'SEVERE_DYSPNEA', 'STROKE_VISION', 'CONFUSION'};
  if (crisis && symptomCodes.any(crisisSymptoms.contains)) return Finding('BP_CRISIS_SYMPTOMATIC', 'red', 'escalate', quote);
  if (crisis) return Finding('BP_CRISIS_ASYMPTOMATIC', 'yellow', 'follow_up', quote);
  if (systolic < (cfg['low_systolic'] as num) && symptomCodes.contains('MILD_SYMPTOM')) {
    return Finding('BP_LOW_SYMPTOMATIC', 'yellow', 'follow_up', quote);
  }
  return null;
}

bool isHigh(int systolic, int diastolic) =>
    systolic >= (Content.bp['high_systolic'] as num) || diastolic >= (Content.bp['high_diastolic'] as num);
