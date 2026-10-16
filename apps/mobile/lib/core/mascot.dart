import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Suasana hati maskot, mengikuti status hari ini.
enum TiliMood { happy, calm, worried, alert, sleepy }

TiliMood moodForLevel(String? level) => switch (level) {
  'red' => TiliMood.alert,
  'yellow' || 'no_answer' => TiliMood.worried,
  'green' => TiliMood.happy,
  _ => TiliMood.calm,
};

/// "Kiki", burung kutilang biru maskot KRING. Digambar dengan CustomPainter (tanpa aset), bergoyang pelan,
/// berkedip, dan ekspresinya mengikuti [mood]. Diam bila pengguna mematikan animasi.
class Tili extends StatefulWidget {
  const Tili({super.key, this.mood = TiliMood.happy, this.size = 120, this.waving = false});
  final TiliMood mood;
  final double size;
  final bool waving;

  @override
  State<Tili> createState() => _TiliState();
}

class _TiliState extends State<Tili> with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) => Semantics(
    label: 'Kiki, maskot KRING',
    image: true,
    child: RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: _TiliPainter(_t, widget.mood, widget.waving)),
    ),
  );
}

class _TiliPainter extends CustomPainter {
  _TiliPainter(this.t, this.mood, this.waving) : super(repaint: t);
  final ValueNotifier<double> t;
  final TiliMood mood;
  final bool waving;

  static const _blue = Color(0xFF2F86F6);
  static const _blueDeep = Color(0xFF1858C8);
  static const _belly = Color(0xFFFFF4DA);
  static const _beak = Color(0xFFFF9F43);
  static const _cheek = Color(0xFFFF8FA3);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final time = t.value;
    final alert = mood == TiliMood.alert;
    final bob = math.sin(time * (alert ? 6 : 2.2)) * (alert ? 1.2 : 2.0);
    canvas.save();
    canvas.scale(s);
    canvas.translate(0, bob);

    // Bayangan
    canvas.drawOval(Rect.fromCenter(center: Offset(50, 95 - bob), width: 52 - bob * 2, height: 7),
        Paint()..color = const Color(0x220E2A5A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // Kaki
    final leg = Paint()
      ..color = _beak
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(42, 82), const Offset(40, 91), leg);
    canvas.drawLine(const Offset(58, 82), const Offset(60, 91), leg);

    // Ekor
    final tail = Path()
      ..moveTo(78, 62)
      ..quadraticBezierTo(97, 58, 96, 44)
      ..quadraticBezierTo(88, 54, 76, 54)
      ..close();
    canvas.drawPath(tail, Paint()..color = _blueDeep);

    // Badan
    final body = Rect.fromCenter(center: const Offset(50, 55), width: 66, height: 64);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-0.35, -0.5), radius: 0.95, colors: [Color(0xFF6FB4FF), _blue, _blueDeep], stops: [0, 0.55, 1])
            .createShader(body),
    );
    // Perut
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 65), width: 40, height: 36), Paint()..color = _belly);

    // Jambul
    final crest = Path()
      ..moveTo(44, 25)
      ..quadraticBezierTo(42, 10, 52, 8)
      ..quadraticBezierTo(48, 16, 55, 24)
      ..close();
    canvas.drawPath(crest, Paint()..color = _blueDeep);

    // Sayap (melambai bila waving)
    final wave = waving ? math.sin(time * 7) * 18 : math.sin(time * 2.2) * 3;
    _wing(canvas, const Offset(20, 56), -1, wave);
    _wing(canvas, const Offset(80, 56), 1, waving ? 0 : -wave);

    // Pipi
    if (mood == TiliMood.happy || mood == TiliMood.calm) {
      final cheek = Paint()..color = _cheek.withValues(alpha: 0.55);
      canvas.drawCircle(const Offset(31, 50), 4.5, cheek);
      canvas.drawCircle(const Offset(69, 50), 4.5, cheek);
    }

    _eyes(canvas, time);

    // Paruh
    final beakOpen = mood == TiliMood.alert ? 3.5 : (mood == TiliMood.happy ? 1.6 : 0.6);
    final beakTop = Path()
      ..moveTo(44, 49)
      ..quadraticBezierTo(50, 45, 56, 49)
      ..lineTo(50, 55)
      ..close();
    canvas.drawPath(beakTop, Paint()..color = _beak);
    final beakBottom = Path()
      ..moveTo(46, 52 + beakOpen * 0.3)
      ..lineTo(54, 52 + beakOpen * 0.3)
      ..lineTo(50, 56 + beakOpen)
      ..close();
    canvas.drawPath(beakBottom, Paint()..color = const Color(0xFFE5822A));

    // Tanda di atas kepala
    if (mood == TiliMood.alert) {
      final p = Paint()..color = TColors.red;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(73, 6, 6, 14), const Radius.circular(3)), p);
      canvas.drawCircle(const Offset(76, 25), 3.2, p);
    } else if (mood == TiliMood.sleepy) {
      final tp = TextPainter(
        text: const TextSpan(text: 'z z', style: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 12, color: _blueDeep)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(68, 8 + math.sin(time * 2) * 2));
    } else if (mood == TiliMood.happy) {
      _sparkle(canvas, Offset(82, 18), 4 + math.sin(time * 3) * 1.2);
    }
    canvas.restore();
  }

  void _wing(Canvas canvas, Offset root, double side, double angleDeg) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.rotate(side * angleDeg * math.pi / 180);
    final w = Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(side * 14, -4, side * 10, 12)
      ..quadraticBezierTo(side * 2, 8, 0, -10)
      ..close();
    canvas.drawPath(w, Paint()..color = _blueDeep);
    canvas.restore();
  }

  void _eyes(Canvas canvas, double time) {
    final white = Paint()..color = Colors.white;
    final ink = Paint()..color = TColors.ink;
    final blink = (time % 4.2) > 4.05 && mood != TiliMood.alert;
    for (final x in [39.0, 61.0]) {
      final c = Offset(x, 40);
      if (mood == TiliMood.happy || blink || mood == TiliMood.sleepy) {
        // Mata senyum ^ ^ (atau berkedip)
        final arc = Paint()
          ..color = TColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;
        final r = Rect.fromCenter(center: c.translate(0, 2), width: 11, height: 9);
        if (mood == TiliMood.sleepy || blink) {
          canvas.drawLine(c.translate(-5, 2), c.translate(5, 2), arc);
        } else {
          canvas.drawArc(r, math.pi, math.pi, false, arc);
        }
        continue;
      }
      final big = mood == TiliMood.alert ? 8.5 : 7.5;
      canvas.drawCircle(c, big, white);
      final look = Offset(math.sin(time * 0.7) * 1.2, mood == TiliMood.worried ? 1.2 : 0);
      canvas.drawCircle(c + look, big * 0.55, ink);
      canvas.drawCircle(c + look + const Offset(1.6, -1.8), 1.5, white);
      if (mood == TiliMood.worried) {
        final brow = Paint()
          ..color = TColors.ink
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        final inner = x < 50 ? 4.0 : -4.0;
        canvas.drawLine(c.translate(-inner - (x < 50 ? 3 : -3), -12), c.translate(inner * 0.4, -10), brow);
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFC53D));
  }

  @override
  bool shouldRepaint(covariant _TiliPainter old) => old.mood != mood || old.waving != waving;
}

/// Maskot + gelembung ucapan, dipakai di layar kosong dan kartu sapaan.
class TiliSays extends StatelessWidget {
  const TiliSays(this.text, {super.key, this.mood = TiliMood.happy, this.size = 84, this.dark = false});
  final String text;
  final TiliMood mood;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Tili(mood: mood, size: size),
      const SizedBox(width: 6),
      Flexible(
        child: Container(
          margin: EdgeInsets.only(bottom: size * 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.12) : TColors.panel,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
            boxShadow: dark ? null : TShadow.soft,
          ),
          child: Text(text, style: TText.body.copyWith(fontSize: 15.5, color: dark ? Colors.white : TColors.ink, fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  );
}
