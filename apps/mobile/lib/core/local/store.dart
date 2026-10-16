/// Penyimpanan backend offline: tabel = daftar Map di memori (pengganti SQLite server), disimpan ke
/// SharedPreferences supaya data demo bertahan saat aplikasi ditutup.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

typedef Row = Map<String, dynamic>;

const tableNames = [
  'patients', 'contacts', 'call_sessions', 'call_turns', 'observations', 'hospitals', 'travel_times', 'alerts', 'memories',
  'family_messages', 'notifications', 'events', 'device_syncs', 'doctor_consults',
  // Fitur tambahan aplikasi keluarga.
  'med_stock', 'intake', 'family_calls', 'message_audio', 'call_retries', 'home_checks', 'appointments',
];

class Store {
  Store._();
  static final Store instance = Store._();

  static const _prefKey = 'tilik_offline_db_v2';
  final Map<String, List<Row>> _t = {for (final n in tableNames) n: []};
  int _turnSeq = 0;
  Timer? _saveTimer;
  String seededOn = '';

  List<Row> rows(String table) => _t[table]!;

  Iterable<Row> where(String table, bool Function(Row r) test) => _t[table]!.where(test);

  Row? one(String table, bool Function(Row r) test) {
    for (final r in _t[table]!) {
      if (test(r)) return r;
    }
    return null;
  }

  Row? byId(String table, String? id) => id == null ? null : one(table, (r) => r['id'] == id);

  void insert(String table, Row row) {
    if (table == 'call_turns') row['id'] = ++_turnSeq;
    _t[table]!.add(row);
  }

  void delete(String table, bool Function(Row r) test) => _t[table]!.removeWhere(test);

  void wipe() {
    for (final l in _t.values) {
      l.clear();
    }
    _turnSeq = 0;
  }

  /// Urutkan salinan berdasarkan kolom (string ISO urut secara leksikal).
  List<Row> sorted(Iterable<Row> rs, String key, {bool desc = false}) {
    final l = rs.toList();
    l.sort((a, b) {
      final c = '${a[key] ?? ''}'.compareTo('${b[key] ?? ''}');
      return desc ? -c : c;
    });
    return l;
  }

  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      seededOn = data['seeded_on'] as String? ?? '';
      _turnSeq = data['turn_seq'] as int? ?? 0;
      final tables = data['tables'] as Map<String, dynamic>;
      for (final n in tableNames) {
        _t[n] = ((tables[n] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode({'seeded_on': seededOn, 'turn_seq': _turnSeq, 'tables': _t}));
    } catch (_) {}
  }
}

final _rng = Random.secure();

String newId() {
  String h(int n) => List.generate(n, (_) => _rng.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${(8 + _rng.nextInt(4)).toRadixString(16)}${h(3)}-${h(12)}';
}

/// Salinan dalam (JSON) supaya respons tidak berbagi objek dengan tabel.
T deep<T>(T v) => jsonDecode(jsonEncode(v)) as T;

/// Konten percakapan & aturan (salinan `content/` di akar repo, dibundel sebagai aset).
class Content {
  Content._();
  static Map<String, dynamic> scripts = {};
  static Map<String, dynamic> redFlags = {};
  static final List<(Map<String, dynamic>, List<RegExp>)> rules = [];

  static Future<void> load() async {
    if (scripts.isNotEmpty) return;
    scripts = jsonDecode(await rootBundle.loadString('assets/content/scripts.json')) as Map<String, dynamic>;
    redFlags = jsonDecode(await rootBundle.loadString('assets/content/red_flags.json')) as Map<String, dynamic>;
    rules
      ..clear()
      ..addAll([
        for (final r in (redFlags['rules'] as List).cast<Map<String, dynamic>>())
          (r, [for (final p in (r['patterns'] as List).cast<String>()) RegExp(p, unicode: true)]),
      ]);
  }

  static String line(String key, String lang, Map<String, Object?> values) {
    final langMap = (scripts[lang] as Map?) ?? const {};
    final template = (langMap[key] ?? (scripts['id'] as Map)[key]) as String;
    return format(template, values);
  }

  static String format(String template, Map<String, Object?> values) =>
      template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${values[m[1]] ?? m[0]}');

  static String education(int index) {
    final items = (scripts['education'] as List).cast<String>();
    return items[index % items.length];
  }

  static String briefing(String key, Map<String, Object?> values) => format((scripts['briefing'] as Map)[key] as String, values);

  static String label(String code) {
    for (final (r, _) in rules) {
      if (r['code'] == code) return r['label'] as String;
    }
    return ((redFlags['labels'] as Map)[code] as String?) ?? code;
  }

  static Map<String, dynamic> get bp => redFlags['bp'] as Map<String, dynamic>;
  static Map<String, dynamic> get wearable => redFlags['wearable'] as Map<String, dynamic>;
  static List<String> get negations => (redFlags['negations'] as List).cast<String>();
}
