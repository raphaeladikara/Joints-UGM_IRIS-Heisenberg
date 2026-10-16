import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'local/backend.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Klien API KRING. Bawaan: **mode offline** (backend di dalam aplikasi, data demo, tanpa server).
/// Server sungguhan bisa dipilih dari Pengaturan atau `--dart-define=TILIK_API=http://IP:8080`.
/// Selalu IP eksplisit, bukan "localhost" (Windows mencoba IPv6 dulu).
class Api {
  Api._();
  static final Api instance = Api._();

  static const _buildDefault = String.fromEnvironment('TILIK_API');
  static const _prefKey = 'tilik_api_base';

  static const offline = 'offline';

  String _base = '';
  String get base => _base;
  bool get isOffline => _base == offline;

  static String get platformDefault => _buildDefault.isNotEmpty ? _buildDefault : offline;

  /// Contoh alamat server untuk isian Pengaturan.
  static String get serverHint => kIsWeb ? 'http://127.0.0.1:8080' : 'http://10.0.2.2:8080';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _base = prefs.getString(_prefKey) ?? '';
    } catch (_) {
      _base = '';
    }
    if (_base.isEmpty) _base = platformDefault;
  }

  Future<void> setBase(String value) async {
    final v = value.trim().replaceAll(RegExp(r'/+$'), '');
    _base = v.isEmpty ? platformDefault : v;
    if (v == platformDefault) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (v.isEmpty) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, v);
    }
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    if (isOffline) {
      try {
        return await LocalBackend.instance.handle(method, path, body);
      } on LocalHttpError catch (e) {
        throw ApiException('Gagal (${e.status}): ${e.detail}');
      }
    }
    final uri = Uri.parse('$_base$path');
    final headers = {'Content-Type': 'application/json'};
    late http.Response res;
    try {
      final f = switch (method) {
        'GET' => http.get(uri, headers: headers),
        _ => http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
      };
      res = await f.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw ApiException('Server tidak menjawab ($_base).');
    } catch (_) {
      throw ApiException('Tidak bisa terhubung ke server ($_base).');
    }
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      String detail = text;
      try {
        detail = (jsonDecode(text) as Json)['detail'].toString();
      } catch (_) {}
      throw ApiException('Gagal (${res.statusCode}): $detail');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  Future<Json> get(String path) async => (await _send('GET', path)) as Json;
  Future<List<dynamic>> list(String path) async => (await _send('GET', path)) as List<dynamic>;
  Future<Json> post(String path, [Object? body]) async => (await _send('POST', path, body)) as Json;

  // Endpoint yang dipakai banyak layar.
  Future<Json> health() => get('/v1/health');
  Future<Json> resetDemo() => post('/v1/demo/reset');
  Future<Json> today() => get('/v1/puskesmas/today');
  Future<Json> patient(String id) => get('/v1/patients/$id');
  Future<List<dynamic>> patients() => list('/v1/patients');
  Future<List<dynamic>> contacts() => list('/v1/contacts');
  Future<Json> contactFeed(String id) => get('/v1/contacts/$id/feed');
  Future<Json> startCall(String patientId, {bool autoAnswer = false}) =>
      post('/v1/calls', {'patient_id': patientId, 'auto_answer': autoAnswer});
  Future<Json> incoming(String patientId) => get('/v1/patients/$patientId/incoming');
  Future<Json> answer(String sid) => post('/v1/calls/$sid/answer');
  Future<Json> say(String sid, String text) => post('/v1/calls/$sid/turns', {'text': text});
  Future<Json> noAnswer(String sid) => post('/v1/calls/$sid/no-answer');
  Future<Json> hangup(String sid) => post('/v1/calls/$sid/hangup');
  Future<Json> call(String sid) => get('/v1/calls/$sid');
  Future<List<dynamic>> liveCalls() => list('/v1/calls');
  Future<Json> event(String patientId, String type, {String source = 'wearable', Json payload = const {}}) =>
      post('/v1/events', {'patient_id': patientId, 'type': type, 'source': source, 'payload': payload});
  Future<List<dynamic>> alerts({String? level, String? status}) {
    final q = <String>[if (level != null) 'level=$level', if (status != null) 'status=$status'].join('&');
    return list('/v1/alerts${q.isEmpty ? '' : '?$q'}');
  }

  Future<Json> alert(String id) => get('/v1/alerts/$id');
  Future<Json> ackAlert(String id, String by) => post('/v1/alerts/$id/ack', {'by': by});
  Future<Json> closeAlert(String id) => post('/v1/alerts/$id/close');
  Future<Json> notificationAction(String id, String action) => post('/v1/notifications/$id/action', {'action': action});
  Future<Json> sendFamilyMessage(String patientId, String contactId, String text) =>
      post('/v1/patients/$patientId/family-messages', {'contact_id': contactId, 'text': text});
  Future<Json> vitals(String patientId) => get('/v1/patients/$patientId/vitals');
  Future<Json> requestDoctor(String patientId, String contactId, {String mode = 'video', String reason = ''}) =>
      post('/v1/patients/$patientId/doctor-consults', {'contact_id': contactId, 'mode': mode, 'reason': reason});
  Future<Json> consult(String id) => get('/v1/doctor-consults/$id');
  Future<List<dynamic>> activeConsults() => list('/v1/doctor-consults');
  Future<Json> setConsultStatus(String id, String status, {String note = ''}) =>
      post('/v1/doctor-consults/$id/status', {'status': status, 'note': note});
  // Fitur keluarga: jadwal & stok obat, air & garam, streak, rapor bulanan.
  Future<Json> care(String patientId) => get('/v1/patients/$patientId/care');
  Future<Json> logDose(String patientId, String name, String time, {String status = 'taken'}) =>
      post('/v1/patients/$patientId/meds/dose', {'name': name, 'time': time, 'status': status});
  Future<Json> refillMeds(String patientId, {String? name}) => post('/v1/patients/$patientId/meds/refill', {'name': ?name});
  Future<Json> logIntake(String patientId, String kind, num delta) => post('/v1/patients/$patientId/intake', {'kind': kind, 'delta': delta});
  Future<Json> logFamilyCall(String patientId, String contactId) => post('/v1/patients/$patientId/family-calls', {'contact_id': contactId});
  Future<Json> report(String patientId, {int days = 30}) => get('/v1/patients/$patientId/report?days=$days');

  Future<Json> postVitals(String patientId, String source, String device, List<Json> samples) =>
      post('/v1/patients/$patientId/vitals', {'source': source, 'device': device, 'samples': samples});
}
