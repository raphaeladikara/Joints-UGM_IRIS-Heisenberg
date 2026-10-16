import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';

/// Polling berkala sederhana (pengganti realtime Supabase di prototype). Berhenti otomatis saat widget dibuang.
mixin Poller<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  bool _busy = false;
  String? pollError;

  Future<void> poll();

  void startPolling([Duration every = const Duration(seconds: 2)]) {
    _tick();
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await poll();
      if (mounted && pollError != null) setState(() => pollError = null);
    } catch (e) {
      if (mounted) setState(() => pollError = e.toString());
    } finally {
      _busy = false;
    }
  }

  Future<void> refreshNow() => _tick();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key, this.big = false, this.text});
  final String? level;
  final bool big;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final s = LevelStyle.of(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 5),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: big ? 20 : 16, color: s.fg),
          const SizedBox(width: 6),
          Text(
            text ?? s.label,
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: big ? 15 : 12.5, color: s.fg),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TColors.yellowTint, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: TColors.yellow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TText.small.copyWith(color: TColors.ink)),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: TText.label)),
        ?trailing,
      ],
    ),
  );
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: dark ? Colors.white38 : TColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text('DATA FIKTIF · SIMULASI', style: TText.label.copyWith(fontSize: 10, color: dark ? Colors.white60 : TColors.muted)),
  );
}

/// Grafik tensi 7–14 hari (sistolik & diastolik) dengan garis ambang 140/90 dan 180.
class BpChart extends StatelessWidget {
  const BpChart(this.points, {super.key, this.height = 150});
  final List<dynamic> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(child: Text('Belum ada data tensi.', style: TText.small)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(painter: _BpPainter(points)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final p in points)
              Expanded(
                child: Text(shortDay(p['at'] as String?), textAlign: TextAlign.center, style: TText.small.copyWith(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(TColors.clay, 'Sistolik'),
            const SizedBox(width: 16),
            _legend(TColors.leaf, 'Diastolik'),
            const SizedBox(width: 16),
            _legend(TColors.line, 'Batas 140/90', dashed: true),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String t, {bool dashed = false}) => Row(
    children: [
      Container(width: 14, height: 3, color: c),
      const SizedBox(width: 6),
      Text(t, style: TText.small.copyWith(fontSize: 11.5)),
    ],
  );
}

class _BpPainter extends CustomPainter {
  _BpPainter(this.points);
  final List<dynamic> points;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 60.0, hi = 200.0;
    double y(num v) => size.height - (v.toDouble() - lo) / (hi - lo) * size.height;
    final step = size.width / points.length;
    double x(int i) => step * i + step / 2;

    final grid = Paint()
      ..color = TColors.line
      ..strokeWidth = 1;
    for (final v in [90, 140]) {
      final yy = y(v);
      for (double xx = 0; xx < size.width; xx += 8) {
        canvas.drawLine(Offset(xx, yy), Offset(math.min(xx + 4, size.width), yy), grid);
      }
    }
    final crisis = Paint()
      ..color = TColors.redTint
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, y(180)), Offset(size.width, y(180)), crisis);

    void series(String key, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final v = (points[i][key] as num?) ?? 0;
        final o = Offset(x(i), y(v));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
      for (var i = 0; i < points.length; i++) {
        final v = (points[i][key] as num?) ?? 0;
        canvas.drawCircle(Offset(x(i), y(v)), 4, Paint()..color = color);
        canvas.drawCircle(Offset(x(i), y(v)), 2, Paint()..color = Colors.white);
      }
      final last = points.last[key] as num?;
      if (last != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$last',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(math.min(x(points.length - 1) + 6, size.width - tp.width), y(last) - 16));
      }
    }

    series('systolic', TColors.clay);
    series('diastolic', TColors.leaf);
  }

  @override
  bool shouldRepaint(covariant _BpPainter old) => old.points != points;
}

/// Kepatuhan obat 7 hari sebagai deret titik bertanda (✓ sudah, ✕ belum).
class AdherenceRow extends StatelessWidget {
  const AdherenceRow(this.days, {super.key});
  final List<dynamic> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return Text('Belum ada data.', style: TText.small);
    return Row(
      children: [
        for (final d in days.take(7))
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: d['status'] == 'sudah' ? TColors.greenTint : TColors.yellowTint, shape: BoxShape.circle),
                  child: Icon(
                    d['status'] == 'sudah' ? Icons.check_rounded : Icons.close_rounded,
                    size: 18,
                    color: d['status'] == 'sudah' ? TColors.green : TColors.yellow,
                  ),
                ),
                const SizedBox(height: 4),
                Text(shortDay(d['at'] as String?), style: TText.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hitung mundur golden period, diperbarui tiap detik.
class CountdownText extends StatefulWidget {
  const CountdownText(this.deadlineIso, {super.key, this.style});
  final String? deadlineIso;
  final TextStyle? style;
  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(remaining(widget.deadlineIso), style: widget.style);
}

Future<void> showError(BuildContext context, Object e) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : e.toString())));
}
