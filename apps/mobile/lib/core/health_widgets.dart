import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

/// Ubin metrik pastel: ikon dalam gelembung putih, label, angka besar + satuan, grafik kecil opsional.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.color,
    required this.ink,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.note,
    this.chart,
    this.onTap,
  });
  final Color color;
  final Color ink;
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? note;
  final Widget? chart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: TText.h3.copyWith(fontSize: 17))),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(icon, size: 21, color: ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: value,
                    style: TText.metric,
                    children: [
                      if (unit != null) TextSpan(text: ' $unit', style: TText.h3.copyWith(fontSize: 17, color: TColors.ink.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(note!, style: TText.small.copyWith(color: ink, fontWeight: FontWeight.w700)),
              ],
              if (chart != null) ...[const SizedBox(height: 12), chart!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Batang harian (mis. langkah 7 hari). Hari ini tinta pekat, hari lain tinta lembut, garis putus = target.
class MiniBars extends StatelessWidget {
  const MiniBars(this.daily, {super.key, required this.ink, this.goal, this.height = 64});
  final List<dynamic> daily;
  final Color ink;
  final num? goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final vals = [for (final d in daily) (d['value'] as num?)?.toDouble()];
    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(size: Size.infinite, painter: _BarsPainter(vals, ink, goal?.toDouble())),
        ),
        const SizedBox(height: 6),
        // Nama hari 3 huruf hanya bila muat; di ubin sempit cukup penanda ujung (Sen/Sel tidak boleh jadi "Se/Se").
        LayoutBuilder(
          builder: (context, box) => box.maxWidth / math.max(1, daily.length) >= 30
              ? Row(
                  children: [
                    for (final (i, d) in daily.indexed)
                      Expanded(
                        child: Text(
                          i == daily.length - 1 ? 'Ini' : shortDay('${d['date']}T12:00:00+07:00'),
                          textAlign: TextAlign.center,
                          style: TText.label.copyWith(fontSize: 12, color: i == daily.length - 1 ? TColors.ink : TColors.muted),
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: Text('${daily.length} hari lalu', style: TText.label.copyWith(fontSize: 12))),
                    Text('Hari ini', style: TText.label.copyWith(fontSize: 12, color: TColors.ink)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.vals, this.ink, this.goal);
  final List<double?> vals;
  final Color ink;
  final double? goal;

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.isEmpty) return;
    final top = [...vals.whereType<double>(), goal ?? 0].fold<double>(1, math.max) * 1.08;
    final slot = size.width / vals.length;
    final bw = math.min(22.0, slot * 0.56);
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      final x = slot * i + (slot - bw) / 2;
      final track = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, bw, size.height), Radius.circular(bw / 2));
      canvas.drawRRect(track, Paint()..color = Colors.white.withValues(alpha: 0.55));
      if (v == null || v <= 0) continue;
      final h = math.max(bw, v / top * size.height);
      final bar = RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, bw, h), Radius.circular(bw / 2));
      canvas.drawRRect(bar, Paint()..color = i == vals.length - 1 ? ink : ink.withValues(alpha: 0.42));
    }
    if (goal != null) {
      final y = size.height - goal! / top * size.height;
      final p = Paint()
        ..color = TColors.ink.withValues(alpha: 0.55)
        ..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3.5, size.width), y), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.vals != vals || old.goal != goal;
}

/// Garis detak jantung hari ini (halus, dengan titik terakhir).
class HeartLine extends StatelessWidget {
  const HeartLine(this.points, {super.key, required this.ink, this.height = 54});
  final List<dynamic> points;
  final Color ink;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(size: Size.infinite, painter: _LinePainter([for (final p in points) (p['value'] as num).toDouble()], ink)),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.vals, this.ink);
  final List<double> vals;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.length < 2) return;
    final lo = vals.reduce(math.min) - 6, hi = vals.reduce(math.max) + 6;
    Offset at(int i) => Offset(size.width * i / (vals.length - 1), size.height - (vals[i] - lo) / (hi - lo) * size.height);
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < vals.length; i++) {
      final a = at(i - 1), b = at(i);
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ink.withValues(alpha: 0.28), ink.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    final last = at(vals.length - 1);
    canvas.drawCircle(last, 6, Paint()..color = Colors.white);
    canvas.drawCircle(last, 4, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.vals != vals;
}

/// Satu cincin dalam [ActivityRings].
class Ring {
  const Ring({required this.label, required this.value, required this.goalText, required this.progress, required this.color, required this.icon});
  final String label;
  final String value;
  final String goalText;
  final double progress; // 0..1 (boleh >1, digambar penuh)
  final Color color;
  final IconData icon;
}

/// Cincin target harian ala Apple Fitness, disesuaikan untuk lansia: tiga cincin tebal + legenda berteks
/// (persentase tidak pernah hanya diwakili warna).
class ActivityRings extends StatelessWidget {
  const ActivityRings(this.rings, {super.key, this.size = 150});
  final List<Ring> rings;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutExpo,
          builder: (_, k, _) => CustomPaint(size: Size.square(size), painter: _RingsPainter(rings, k)),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(r.icon, color: r.color, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.label, style: TText.small.copyWith(color: TColors.ink, fontWeight: FontWeight.w800)),
                            Text.rich(
                              TextSpan(
                                text: r.value,
                                style: TText.h3,
                                children: [TextSpan(text: ' ${r.goalText}', style: TText.small)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings, this.k);
  final List<Ring> rings;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.width * 0.105;
    for (var i = 0; i < rings.length; i++) {
      final r = rings[i];
      final radius = size.width / 2 - stroke / 2 - i * (stroke + 4);
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = r.color.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      final sweep = 2 * math.pi * r.progress.clamp(0.0, 1.0) * k;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = r.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.k != k || old.rings != rings;
}

/// Gauge tensi setengah lingkaran: Normal < 140, Tinggi 140–179, Krisis ≥ 180 (sistolik, draf aturan).
class BpGauge extends StatelessWidget {
  const BpGauge({super.key, required this.systolic, required this.diastolic, this.sub});
  final int? systolic;
  final int? diastolic;
  final String? sub;

  static (String, Color) zone(int? s) {
    if (s == null) return ('Belum ada data', TColors.grey);
    if (s >= 180) return ('Sangat tinggi', TColors.red);
    if (s >= 140) return ('Tinggi', const Color(0xFFC98A00));
    return ('Normal', TColors.brand);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = zone(systolic);
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(box.maxWidth, 360.0);
        return Center(
          child: SizedBox(
            width: w,
            height: w * 0.62,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 90, end: (systolic ?? 90).toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutExpo,
              builder: (_, v, _) => CustomPaint(
                painter: _GaugePainter(systolic == null ? null : v),
                child: Align(
                  alignment: const Alignment(0, 0.55),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: systolic == null ? '–' : '$systolic/$diastolic',
                          style: TText.metric.copyWith(fontSize: 44),
                          children: [TextSpan(text: ' mmHg', style: TText.small.copyWith(color: TColors.ink))],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(99)),
                        child: Text(label, style: TText.small.copyWith(color: color == TColors.grey ? TColors.ink : color, fontWeight: FontWeight.w800)),
                      ),
                      if (sub != null) ...[const SizedBox(height: 4), Text(sub!, style: TText.small)],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value);
  final double? value;

  static const lo = 90.0, hi = 200.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final c = Offset(size.width / 2, size.height - stroke * 0.2 - 6);
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: radius);
    double ang(double v) => math.pi + (v.clamp(lo, hi) - lo) / (hi - lo) * math.pi;
    const gap = 0.045;
    final zones = [(lo, 140.0, TColors.brand), (140.0, 180.0, const Color(0xFFE0A100)), (180.0, hi, TColors.red)];
    for (final (a, b, col) in zones) {
      final start = ang(a) + (a == lo ? 0 : gap / 2);
      final end = ang(b) - (b == hi ? 0 : gap / 2);
      canvas.drawArc(
        rect,
        start,
        end - start,
        false,
        Paint()
          ..color = col.withValues(alpha: value == null ? 0.25 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    if (value == null) return;
    final a = ang(value!);
    final p = c + Offset(math.cos(a), math.sin(a)) * radius;
    canvas.drawCircle(p + const Offset(0, 2), stroke * 0.78, Paint()..color = const Color(0x33141A24));
    canvas.drawCircle(p, stroke * 0.78, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      stroke * 0.42,
      Paint()
        ..color = TColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}

/// Navigasi bawah berbentuk pil gelap (referensi), ikon + label selalu terlihat untuk lansia.
class PillNavItem {
  const PillNavItem(this.icon, this.label, {this.badge = 0});
  final IconData icon;
  final String label;
  final int badge;
}

class PillNav extends StatelessWidget {
  const PillNav({super.key, required this.items, required this.index, required this.onTap});
  final List<PillNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: TColors.night, borderRadius: BorderRadius.circular(40), boxShadow: TShadow.lift),
              child: Row(
                children: [
                  for (final (i, it) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: it.label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            height: 60,
                            decoration: BoxDecoration(color: i == index ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(32)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Badge(
                                  isLabelVisible: it.badge > 0,
                                  label: Text('${it.badge}'),
                                  backgroundColor: TColors.clay,
                                  child: Icon(it.icon, size: 25, color: i == index ? TColors.ink : Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  it.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: i == index ? TColors.ink : Colors.white.withValues(alpha: 0.86),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
