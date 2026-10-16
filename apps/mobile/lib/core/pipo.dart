import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Gradien "Pipo" (21st.dev, gaya Bloom Field): satu gumpalan radial per warna di titiknya sendiri, ditumpuk di atas
/// latar kertas. Gumpalan bergeser pelan; setiap modulasi bernilai 0 saat t = 0 supaya tidak meloncat saat mulai.
/// Diam bila pengguna mematikan animasi.
class PipoBackground extends StatefulWidget {
  const PipoBackground({super.key, this.child, this.borderRadius});
  final Widget? child;
  final BorderRadius? borderRadius;

  @override
  State<PipoBackground> createState() => _PipoBackgroundState();
}

class _PipoBackgroundState extends State<PipoBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _t.value = d.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: CustomPaint(painter: _PipoPainter(_t), child: widget.child),
    );
  }
}

class _Blob {
  const _Blob(this.color, this.x, this.y, this.reach, this.p, this.p2);
  final Color color;
  final double x, y; // persen
  final double reach; // persen dari jarak ke sudut terjauh
  final double p, p2; // fase statis per gumpalan
}

class _PipoPainter extends CustomPainter {
  _PipoPainter(this.t) : super(repaint: t);
  final ValueNotifier<double> t;

  // Urutan lukis: bawah ke atas (kertas, biru langit, aprikot), sama dengan urutan lapisan CSS yang dibalik.
  static final _blobs = [
    _Blob(TColors.paper, 53.11, 12.71, 66.65, _phase(3), _phase(4)),
    _Blob(TColors.skyBlue, 25.17, 75.99, 44.6, _phase(1), _phase(2)),
    _Blob(TColors.apricot, 68.1, 46.03, 41.1, _phase(5), _phase(6)),
  ];

  /// Hash seed → fase tetap. Hanya dihitung sekali; seed tidak pernah dianimasikan.
  static double _phase(int i) {
    final v = math.sin(i * 12.9898 + 1 * 78.233) * 43758.5453;
    return (v - v.floorToDouble()) * 2 * math.pi;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFAF8EE));
    final ph = t.value * 0.86;
    const amt = 0.72;
    for (final b in _blobs) {
      final x = b.x + (math.sin(ph * 0.55 + b.p) - math.sin(b.p)) * 14 * amt;
      final y = b.y + (math.sin(ph * 0.43 + b.p2) - math.sin(b.p2)) * 14 * amt;
      final c = Offset(size.width * x / 100, size.height * y / 100);
      final far = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]
          .map((k) => (k - c).distance)
          .reduce(math.max);
      final r = far * b.reach / 100;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [for (final a in const [1.0, 0.844, 0.5, 0.156, 0.0]) b.color.withValues(alpha: a)],
            stops: const [0, 0.25, 0.5, 0.75, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PipoPainter old) => false;
}
