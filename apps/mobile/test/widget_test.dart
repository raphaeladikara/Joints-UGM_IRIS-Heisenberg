import 'package:flutter_test/flutter_test.dart';
import 'package:tilik/core/format.dart';

void main() {
  test('hm menampilkan jam WIB', () {
    expect(hm('2026-10-18T06:40:00+07:00'), '06.40');
    expect(hm('2026-10-17T23:40:00+00:00'), '06.40');
    expect(hm(null), '–');
  });

  test('remaining menghitung sisa waktu', () {
    final soon = DateTime.now().toUtc().add(const Duration(hours: 2, minutes: 5, seconds: 30)).toIso8601String();
    expect(remaining(soon), '2 j 05 m');
  });
}
