import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/mascot.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

String _fmtInt(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _sdt(num v) {
  final whole = v.floor();
  final half = v - whole >= 0.5;
  if (whole == 0) return half ? '½' : '0';
  return half ? '$whole½' : '$whole';
}

// ---------- streak (ala ikon permata & api di referensi) ----------

class StreakBar extends StatelessWidget {
  const StreakBar(this.care, {super.key, this.onTap});
  final Json care;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = care['streaks'] as Json;
    return Row(
      children: [
        Flexible(child: _pill('🔥', '${s['medication_days']}', 'hari obat rutin', const Color(0xFFFFE8D9))),
        const SizedBox(width: 8),
        Flexible(child: _pill('💙', '${s['family_calls_week']}', 'telepon/minggu', TColors.brandTint)),
        const SizedBox(width: 8),
        if (onTap != null)
          IconButton(
            onPressed: onTap,
            tooltip: 'Rapor 30 hari',
            style: IconButton.styleFrom(backgroundColor: TColors.panel),
            icon: const Icon(Icons.insights_rounded, color: TColors.brandDeep),
          ),
      ],
    );
  }

  Widget _pill(String emoji, String value, String label, Color bg) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(value, style: TText.h3.copyWith(fontSize: 17)),
        const SizedBox(width: 4),
        Text(label, style: TText.label.copyWith(color: TColors.ink.withValues(alpha: 0.7))),
      ],
    )),
  );
}

// ---------- ringkasan hari ini (kartu gelap + cincin, ala "Summary") ----------

class SummaryCard extends StatelessWidget {
  const SummaryCard(this.feed, {super.key});
  final Json feed;

  @override
  Widget build(BuildContext context) {
    final care = feed['care'] as Json;
    final doses = (care['doses_today'] as List).cast<Json>();
    final taken = doses.where((d) => d['status'] == 'taken').length;
    final intake = care['intake'] as Json;
    final today = intake['today'] as Json;
    final goals = intake['goals'] as Json;
    final water = (today['water'] as num).toInt();
    final waterGoal = (goals['water'] as num).toInt();
    final salt = (today['salt'] as num).toDouble();
    final saltMax = (goals['salt_max'] as num).toDouble();
    final v = feed['vitals'] as Json?;
    final steps = ((v?['latest'] as Json?)?['steps_today'] as num?) ?? 0;
    final stepGoal = ((v?['goals'] as Json?)?['steps'] as num?) ?? 4000;
    final bpList = (feed['bp_history'] as List?) ?? const [];
    final bp = bpList.isEmpty ? null : bpList.last as Json;

    final parts = [
      doses.isEmpty ? 1.0 : taken / doses.length,
      (water / waterGoal).clamp(0.0, 1.0),
      salt <= saltMax ? 1.0 : (saltMax / salt).clamp(0.0, 1.0),
      (steps / stepGoal).clamp(0.0, 1.0),
    ];
    final score = (parts.reduce((a, b) => a + b) / parts.length * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(color: TColors.night, borderRadius: BorderRadius.circular(30), boxShadow: TShadow.lift),
      child: Column(
        children: [
          Row(
            children: [
              Text('Ringkasan hari ini', style: TText.h3.copyWith(color: Colors.white)),
              const Spacer(),
              Text(dayLabel(DateTime.now().toIso8601String()), style: TText.label.copyWith(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _side(bp == null ? '–' : '${bp['systolic']}/${bp['diastolic']}', 'Tensi pagi')),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutExpo,
                builder: (_, k, _) => CustomPaint(
                  size: const Size.square(150),
                  painter: _GapRingPainter(k, const Color(0xFF2EE6B6)),
                  child: SizedBox.square(
                    dimension: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${(k * 100).round()}', style: TText.metric.copyWith(color: Colors.white, fontSize: 44)),
                        Text('skor sehat', style: TText.small.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: _side(_fmtInt(steps), 'Langkah')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _bar('Obat', '$taken / ${doses.length}', doses.isEmpty ? 0 : taken / doses.length, const Color(0xFF2EE6B6)),
              _bar('Air', '$water / $waterGoal gelas', water / waterGoal, TColors.skyBright),
              _bar('Garam', '${_sdt(salt)} / ${_sdt(saltMax)} sdt', salt / saltMax, salt > saltMax ? const Color(0xFFFF7A59) : const Color(0xFFFFC53D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _side(String v, String label) => Column(
    children: [
      FittedBox(child: Text(v, style: TText.h2.copyWith(color: Colors.white))),
      Text(label, style: TText.small.copyWith(color: Colors.white70)),
    ],
  );

  Widget _bar(String label, String value, double p, Color c) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Text(label, style: TText.small.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: p.clamp(0.0, 1.0), minHeight: 8, backgroundColor: TColors.nightLine, color: c),
          ),
          const SizedBox(height: 8),
          FittedBox(child: Text(value, style: TText.label.copyWith(color: Colors.white, fontSize: 13))),
        ],
      ),
    ),
  );
}

/// Cincin dengan celah di bawah (seperti busur referensi).
class _GapRingPainter extends CustomPainter {
  _GapRingPainter(this.k, this.color);
  final double k;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 8);
    const start = math.pi * 0.72, sweep = math.pi * 1.56;
    final track = Paint()
      ..color = TColors.nightLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, start, sweep, false, track);
    canvas.drawArc(r, start, sweep * k.clamp(0.001, 1.0), false, track..color = color);
  }

  @override
  bool shouldRepaint(covariant _GapRingPainter old) => old.k != k;
}

// ---------- air & garam (ala water tracker) ----------

class IntakeCard extends StatefulWidget {
  const IntakeCard({super.key, required this.feed, required this.onChanged});
  final Json feed;
  final VoidCallback onChanged;

  @override
  State<IntakeCard> createState() => _IntakeCardState();
}

class _IntakeCardState extends State<IntakeCard> {
  bool _busy = false;

  Future<void> _log(String kind, num delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      await Api.instance.logIntake(widget.feed['patient']['id'] as String, kind, delta);
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intake = (widget.feed['care'] as Json)['intake'] as Json;
    final today = intake['today'] as Json;
    final goals = intake['goals'] as Json;
    final water = (today['water'] as num).toInt();
    final goal = (goals['water'] as num).toInt();
    final salt = (today['salt'] as num).toDouble();
    final saltMax = (goals['salt_max'] as num).toDouble();
    final over = salt > saltMax;
    final name = widget.feed['patient']['display_name'] as String;
    final glasses = math.max(goal, water + 1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(28), boxShadow: TShadow.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Minum air', style: TText.h3, textAlign: TextAlign.center),
          Text('Target: $goal gelas (±2 liter)', style: TText.small, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(text: '$water', style: TText.metric, children: [TextSpan(text: ' gelas', style: TText.h3.copyWith(color: TColors.muted))]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              for (var i = 0; i < glasses; i++)
                _Glass(
                  filled: i < water,
                  isNext: i == water,
                  last: i == water - 1,
                  onTap: i == water ? () => _log('water', 1) : (i == water - 1 ? () => _log('water', -1) : null),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Ketuk gelas berikutnya untuk menambah, gelas terakhir untuk mengurangi.', style: TText.label, textAlign: TextAlign.center),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(color: TColors.line)),
          Row(
            children: [
              const Text('🧂', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Garam hari ini', style: TText.h3),
                    Text('Batas untuk tensi tinggi: ${_sdt(saltMax)} sdt (±5 g) sehari', style: TText.small),
                  ],
                ),
              ),
              Text('${_sdt(salt)} sdt', style: TText.h2.copyWith(color: over ? TColors.red : TColors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          _SaltMeter(salt: salt, max: saltMax),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: salt <= 0 ? null : () => _log('salt', -0.5), icon: const Icon(Icons.remove_rounded), label: const Text('½ sdt')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: TColors.night),
                  onPressed: () => _log('salt', 0.5),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('½ sdt'),
                ),
              ),
            ],
          ),
          if (over) ...[
            const SizedBox(height: 12),
            TiliSays('Garam $name sudah lewat batas. Coba usulkan sayur bening atau pepes untuk makan malam, ya.', mood: TiliMood.worried, size: 64),
          ],
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.filled, required this.isNext, required this.last, this.onTap});
  final bool filled, isNext, last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: filled ? 'Gelas terisi' : (isNext ? 'Tambah satu gelas' : 'Gelas kosong'),
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(12)),
                gradient: filled
                    ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBFE0FF), Color(0xFF4FA3F7)], stops: [0.18, 0.2])
                    : null,
                color: filled ? null : const Color(0xFFE9F3FF),
                border: Border.all(color: filled ? const Color(0xFF3D8EE6) : const Color(0xFFC7DDF5), width: 2),
              ),
            ),
            if (isNext) const Icon(Icons.add_rounded, color: TColors.brandDeep, size: 22),
            if (last)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF2EE6B6), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 16, color: TColors.night),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SaltMeter extends StatelessWidget {
  const _SaltMeter({required this.salt, required this.max});
  final double salt, max;

  @override
  Widget build(BuildContext context) {
    final total = math.max(max * 2.5, salt);
    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(colors: const [Color(0xFFB9EBCF), Color(0xFFFFE19A), Color(0xFFFFB4A6)], stops: [0, max / total, 1]),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                left: (salt / total).clamp(0.0, 1.0) * (w - 26),
                top: 0,
                child: Container(
                  width: 26,
                  height: 34,
                  decoration: BoxDecoration(color: TColors.night, borderRadius: BorderRadius.circular(10), boxShadow: TShadow.soft),
                  alignment: Alignment.center,
                  child: const Text('🧂', style: TextStyle(fontSize: 14)),
                ),
              ),
              Positioned(
                left: (max / total) * w - 1,
                top: 6,
                child: Container(width: 2, height: 22, color: TColors.ink.withValues(alpha: 0.5)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- tab Obat (ala fasting tracker) ----------

class MedsView extends StatefulWidget {
  const MedsView({super.key, required this.feed, required this.onChanged});
  final Json feed;
  final VoidCallback onChanged;

  @override
  State<MedsView> createState() => _MedsViewState();
}

class _MedsViewState extends State<MedsView> {
  Timer? _tick;
  Json? _report;

  String get _pid => widget.feed['patient']['id'] as String;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final r = await Api.instance.report(_pid);
      if (mounted) setState(() => _report = r);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _take(Json dose) async {
    HapticFeedback.mediumImpact();
    try {
      await Api.instance.logDose(_pid, dose['name'] as String, dose['time'] as String);
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${dose['name']} ${dose['time']} dicatat sudah diminum.')));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _refill(String name) async {
    try {
      await Api.instance.refillMeds(_pid, name: name);
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok $name ditambah 30 butir.')));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  DateTime _at(String hhmm) {
    final now = toWib(DateTime.now());
    final p = hhmm.split(':').map(int.parse).toList();
    return DateTime.utc(now.year, now.month, now.day, p[0], p[1]);
  }

  @override
  Widget build(BuildContext context) {
    final care = widget.feed['care'] as Json;
    final doses = (care['doses_today'] as List).cast<Json>();
    final meds = (care['meds'] as List).cast<Json>();
    final name = widget.feed['patient']['display_name'] as String;
    final now = toWib(DateTime.now());
    final pending = doses.where((d) => d['status'] != 'taken' && d['status'] != 'missed').toList();
    final next = pending.isEmpty ? null : pending.first;
    final allDone = doses.isNotEmpty && doses.every((d) => d['status'] == 'taken');
    final streak = (care['streaks'] as Json)['medication_days'];

    Duration? left;
    double ring = 1;
    if (next != null) {
      final t = _at(next['time'] as String);
      left = t.difference(now);
      final prev = doses.where((d) => (d['time'] as String).compareTo(next['time'] as String) < 0).map((d) => _at(d['time'] as String)).lastOrNull ??
          DateTime.utc(now.year, now.month, now.day);
      final span = t.difference(prev).inSeconds;
      ring = span <= 0 ? 1 : (now.difference(prev).inSeconds / span).clamp(0.0, 1.0);
    }
    String two(int n) => n.abs().toString().padLeft(2, '0');
    final countdown = left == null ? '' : '${two(left.inHours)} : ${two(left.inMinutes % 60)} : ${two(left.inSeconds % 60)}';
    final due = next != null && (next['status'] == 'due' || next['status'] == 'late');

    return RefreshIndicator(
      onRefresh: () async => widget.onChanged(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Text('Jadwal obat $name', style: TText.h1),
          const SizedBox(height: 4),
          Text('Obat pagi dicatat otomatis dari telepon pagi; obat sore/malam bisa ditandai keluarga.', style: TText.small),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26354C), TColors.night]),
              boxShadow: TShadow.lift,
            ),
            child: Column(
              children: [
                Text(
                  allDone ? 'Semua obat hari ini sudah diminum!' : (next == null ? 'Tidak ada jadwal lagi hari ini' : (due ? 'Waktunya minum obat' : 'Obat berikutnya')),
                  style: TText.h3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                SizedBox.square(
                  dimension: 190,
                  child: CustomPaint(
                    painter: _DoseRingPainter(ring, [
                      for (final d in doses) (_dayFrac(d['time'] as String), d['status'] as String),
                    ], _dayFrac('${two(now.hour)}:${two(now.minute)}')),
                    child: Center(child: Tili(size: 104, mood: allDone ? TiliMood.happy : (due ? TiliMood.worried : TiliMood.calm), waving: allDone)),
                  ),
                ),
                const SizedBox(height: 10),
                if (next != null) ...[
                  Text(left!.isNegative ? 'terlambat ${two(-left.inHours)}:${two(-left.inMinutes % 60)}' : countdown,
                      style: TText.metric.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 38)),
                  const SizedBox(height: 4),
                  Text('${next['name']} · pukul ${(next['time'] as String).replaceAll(':', '.')}', style: TText.small.copyWith(color: Colors.white70)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: due ? const Color(0xFF2EE6B6) : Colors.white.withValues(alpha: 0.14),
                      foregroundColor: due ? TColors.night : Colors.white,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(240, 56),
                    ),
                    onPressed: next['status'] == 'out' ? null : () => _take(next),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(next['status'] == 'out' ? 'Obat habis' : 'Tandai sudah diminum'),
                  ),
                ] else
                  Text('🔥 $streak hari berturut-turut minum obat', style: TText.h3.copyWith(color: const Color(0xFF2EE6B6))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Hari ini', style: TText.h2),
          const SizedBox(height: 8),
          for (final (i, d) in doses.indexed) _DoseRow(dose: d, last: i == doses.length - 1),
          const SizedBox(height: 18),
          const Text('Stok obat', style: TText.h2),
          const SizedBox(height: 8),
          for (final m in meds) _StockCard(med: m, onRefill: () => _refill(m['name'] as String)),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Text('30 hari terakhir', style: TText.h2)),
              if (_report?['adherence_pct'] != null) Text('${_report!['adherence_pct']}% diminum', style: TText.h3.copyWith(color: TColors.green)),
            ],
          ),
          const SizedBox(height: 10),
          if (_report == null)
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(26), boxShadow: TShadow.soft),
              child: AdherenceCalendar((_report!['adherence'] as List).cast<Json>()),
            ),
        ],
      ),
    );
  }

  static double _dayFrac(String hhmm) {
    final p = hhmm.split(':').map(int.parse).toList();
    return (p[0] * 60 + p[1]) / 1440;
  }
}

/// Jam 24 jam: busur progres menuju obat berikutnya + titik jadwal obat di lingkaran.
class _DoseRingPainter extends CustomPainter {
  _DoseRingPainter(this.progress, this.marks, this.nowFrac);
  final double progress, nowFrac;
  final List<(double, String)> marks;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(c, r, track);
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: const [Color(0xFF5BB4FF), Color(0xFF2EE6B6)],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi * 2 * progress.clamp(0.002, 1.0), false, arc);
    for (final (f, status) in marks) {
      final a = -math.pi / 2 + f * math.pi * 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final color = switch (status) {
        'taken' => const Color(0xFF2EE6B6),
        'missed' || 'out' => const Color(0xFFFF7A59),
        'late' => const Color(0xFFFFC53D),
        _ => Colors.white,
      };
      canvas.drawCircle(p, 11, Paint()..color = TColors.night);
      canvas.drawCircle(p, 8, Paint()..color = color);
    }
    final na = -math.pi / 2 + nowFrac * math.pi * 2;
    canvas.drawCircle(c + Offset(math.cos(na), math.sin(na)) * (r - 20), 4, Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant _DoseRingPainter old) => true;
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.last});
  final Json dose;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (dose['status']) {
      'taken' => (Icons.check_circle_rounded, TColors.green, 'Sudah diminum${dose['by'] != null ? ' · ${dose['by']}' : ''}'),
      'missed' => (Icons.cancel_rounded, TColors.red, 'Belum diminum${dose['by'] != null ? ' · ${dose['by']}' : ''}'),
      'out' => (Icons.inventory_2_rounded, TColors.red, 'Obat habis'),
      'late' => (Icons.schedule_rounded, TColors.yellow, 'Terlambat'),
      'due' => (Icons.notifications_active_rounded, TColors.brand, 'Waktunya sekarang'),
      _ => (Icons.radio_button_unchecked_rounded, TColors.muted, 'Nanti'),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text((dose['time'] as String).replaceAll(':', '.'), style: TText.h3),
                if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: TColors.line)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(20), boxShadow: TShadow.soft),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Center(child: Text('💊', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${dose['name']}'[0].toUpperCase() + '${dose['name']}'.substring(1), style: TText.h3),
                        Text(label, style: TText.small.copyWith(color: color, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(icon, color: color, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.med, required this.onRefill});
  final Json med;
  final VoidCallback onRefill;

  @override
  Widget build(BuildContext context) {
    final left = med['pills_left'] as int;
    final days = med['days_left'] as int?;
    final size = med['refill_size'] as int;
    final low = days != null && days <= 5;
    final c = left == 0 ? TColors.red : (low ? TColors.yellow : TColors.green);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: left == 0 ? TColors.redTint : (low ? TColors.yellowTint : TColors.panel),
        borderRadius: BorderRadius.circular(24),
        boxShadow: left == 0 || low ? null : TShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${med['name']}'[0].toUpperCase() + '${med['name']}'.substring(1), style: TText.h3),
                    Text('${med['schedule']} · sisa $left butir', style: TText.small),
                  ],
                ),
              ),
              Text(left == 0 ? 'HABIS' : '$days hari', style: TText.h2.copyWith(color: c)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: (left / size).clamp(0.0, 1.0), minHeight: 10, backgroundColor: Colors.white, color: c),
          ),
          if (low || left == 0) ...[
            const SizedBox(height: 10),
            Text(left == 0 ? 'Ambil obat di Puskesmas hari ini. Petugas sudah diberi tahu.' : 'Hampir habis. Ingatkan ambil obat di Puskesmas / Prolanis.',
                style: TText.small.copyWith(color: TColors.ink)),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: TColors.night, minimumSize: const Size.fromHeight(50)),
              onPressed: onRefill,
              icon: const Icon(Icons.local_pharmacy_rounded),
              label: const Text('Sudah ambil obat (+30)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kalender 30 hari: hijau = diminum, oranye = terlewat, abu = tidak ada data.
class AdherenceCalendar extends StatelessWidget {
  const AdherenceCalendar(this.days, {super.key});
  final List<Json> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (_, box) {
            const cols = 10;
            final cell = (box.maxWidth - (cols - 1) * 6) / cols;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, d) in days.indexed)
                  Tooltip(
                    message: '${dayLabel('${d['date']}T12:00:00+07:00')}: ${d['status'] == 'sudah' ? 'diminum' : d['status'] == 'belum' ? 'terlewat' : 'tidak ada data'}',
                    child: Container(
                      width: cell,
                      height: cell,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: switch (d['status']) { 'sudah' => const Color(0xFF34C77B), 'belum' => const Color(0xFFFF9466), _ => TColors.sunk },
                        borderRadius: BorderRadius.circular(9),
                        border: i == days.length - 1 ? Border.all(color: TColors.ink, width: 2) : null,
                      ),
                      child: Text('${int.parse((d['date'] as String).substring(8))}',
                          style: TText.label.copyWith(fontSize: 11, color: d['status'] == null ? TColors.muted : Colors.white)),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _key(const Color(0xFF34C77B), 'Diminum'),
            const SizedBox(width: 14),
            _key(const Color(0xFFFF9466), 'Terlewat'),
            const SizedBox(width: 14),
            _key(TColors.sunk, 'Tidak ada data'),
          ],
        ),
      ],
    );
  }

  Widget _key(Color c, String t) => Row(
    children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 6),
      Text(t, style: TText.label),
    ],
  );
}

// ---------- rapor 30 hari ----------

class MonthlyReportPage extends StatefulWidget {
  const MonthlyReportPage({super.key, required this.patientId, required this.patientName});
  final String patientId, patientName;

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  Json? _r;
  String? _err;

  @override
  void initState() {
    super.initState();
    Api.instance.report(widget.patientId).then((r) {
      if (mounted) setState(() => _r = r);
    }).catchError((Object e) {
      if (mounted) setState(() => _err = e.toString());
    });
  }

  String _summaryText(Json r) {
    final bp = r['bp_avg'] as Json?;
    final v = r['vitals'] as Json;
    final i = r['intake'] as Json;
    final calls = r['calls'] as Json;
    final alerts = (r['alerts'] as List).cast<Json>();
    return [
      'Ringkasan 30 hari ${widget.patientName} (${dayLabel('${r['from']}T12:00:00+07:00')} – ${dayLabel('${r['to']}T12:00:00+07:00')})',
      if (bp != null) '• Tensi rata-rata ${bp['systolic']}/${bp['diastolic']} mmHg; ${r['bp_high_days']} hari ≥160.',
      if (r['adherence_pct'] != null) '• Minum obat ${r['adherence_pct']}% hari tercatat.',
      '• Telepon pagi terjawab ${calls['completed']}/${calls['total']}, tidak diangkat ${calls['no_answer']}.',
      if (v['steps_avg'] != null) '• Langkah rata-rata ${_fmtInt(v['steps_avg'] as num)}/hari; tidur ${((v['sleep_avg_min'] ?? 0) as num) ~/ 60} jam.',
      if (i['salt_avg'] != null) '• Garam rata-rata ${(i['salt_avg'] as num).toStringAsFixed(1)} sdt/hari; ${i['salt_over_days']} hari melewati batas.',
      '• Tanda yang perlu tindak lanjut: ${alerts.isEmpty ? 'tidak ada' : alerts.map((a) => (a['labels'] as List).join(', ')).toSet().join('; ')}.',
      '(Dibuat oleh aplikasi, data demo. Bukan diagnosis.)',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text('Rapor 30 hari ${widget.patientName}')),
      body: r == null
          ? Center(child: _err != null ? ErrorBanner(_err!) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                TiliSays(
                  (r['bp_trend']['second_half'] ?? 0) < (r['bp_trend']['first_half'] ?? 0)
                      ? 'Kabar baik! Tensi ${widget.patientName} 2 minggu terakhir lebih rendah dari 2 minggu sebelumnya.'
                      : 'Tensi ${widget.patientName} belum turun. Yuk bantu jaga obat dan garamnya.',
                  mood: (r['bp_trend']['second_half'] ?? 0) < (r['bp_trend']['first_half'] ?? 0) ? TiliMood.happy : TiliMood.worried,
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _kpi('Tensi rata-rata', r['bp_avg'] == null ? '–' : '${r['bp_avg']['systolic']}/${r['bp_avg']['diastolic']}', 'mmHg', TColors.sky, TColors.skyInk),
                    _kpi('Minum obat', '${r['adherence_pct'] ?? '–'}', '%', TColors.sage, TColors.sageInk),
                    _kpi('Telepon terjawab', '${r['calls']['completed']}', '/ ${r['calls']['total']}', TColors.lavender, TColors.lavenderInk),
                    _kpi('Langkah rata-rata', r['vitals']['steps_avg'] == null ? '–' : _fmtInt(r['vitals']['steps_avg'] as num), '/hari', TColors.peach, TColors.peachInk),
                  ],
                ),
                const SizedBox(height: 16),
                _panel(
                  'Tensi 30 hari',
                  Column(
                    children: [
                      BpTrendChart((r['bp_daily'] as List).cast<Json>()),
                      const SizedBox(height: 8),
                      Text('Pita hijau = target < 140/90. Titik tebal = sistolik, titik tipis = diastolik.', style: TText.label),
                    ],
                  ),
                ),
                _panel('Minum obat', AdherenceCalendar((r['adherence'] as List).cast<Json>())),
                _panel(
                  'Langkah harian',
                  _StepsBars(((r['vitals'] as Json)['steps_daily'] as List).cast<Json>()),
                ),
                _panel(
                  'Garam & air',
                  Row(
                    children: [
                      _mini('🧂', r['intake']['salt_avg'] == null ? '–' : (r['intake']['salt_avg'] as num).toStringAsFixed(1), 'sdt/hari rata-rata'),
                      _mini('⚠️', '${r['intake']['salt_over_days']}', 'hari lewat batas'),
                      _mini('💧', r['intake']['water_avg'] == null ? '–' : (r['intake']['water_avg'] as num).toStringAsFixed(1), 'gelas/hari'),
                    ],
                  ),
                ),
                _panel(
                  'Keluarga',
                  Row(
                    children: [
                      _mini('📞', '${r['family_calls']['count']}', 'telepon anak'),
                      _mini('⏱️', '${r['family_calls']['minutes']}', 'menit mengobrol'),
                      _mini('🔥', '${r['streaks']['medication_days']}', 'hari obat rutin'),
                    ],
                  ),
                ),
                _panel(
                  'Catatan tindak lanjut',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if ((r['alerts'] as List).isEmpty) Text('Tidak ada tanda bahaya dalam 30 hari.', style: TText.body),
                      for (final a in (r['alerts'] as List).cast<Json>())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              LevelChip(a['level'] as String),
                              const SizedBox(width: 10),
                              Expanded(child: Text((a['labels'] as List).join(', '), style: TText.body)),
                              Text(dayLabel(a['created_at'] as String?).split(', ').last, style: TText.small),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), shape: const StadiumBorder()),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _summaryText(r)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ringkasan disalin. Tempel di WhatsApp dokter atau bawa saat kontrol Prolanis.')));
                    }
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Salin ringkasan untuk dokter'),
                ),
              ],
            ),
    );
  }

  Widget _kpi(String label, String value, String unit, Color bg, Color ink) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TText.small.copyWith(color: ink, fontWeight: FontWeight.w800)),
        FittedBox(
          child: Text.rich(TextSpan(text: value, style: TText.metric.copyWith(fontSize: 34), children: [TextSpan(text: ' $unit', style: TText.small)])),
        ),
      ],
    ),
  );

  Widget _mini(String emoji, String v, String label) => Expanded(
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(v, style: TText.h2),
        Text(label, textAlign: TextAlign.center, style: TText.label),
      ],
    ),
  );

  Widget _panel(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(26), boxShadow: TShadow.soft),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: TText.h3), const SizedBox(height: 12), child]),
  );
}

class _StepsBars extends StatelessWidget {
  const _StepsBars(this.daily);
  final List<Json> daily;

  @override
  Widget build(BuildContext context) {
    final vals = [for (final d in daily) ((d['value'] as num?) ?? 0).toDouble()];
    final maxV = vals.fold<double>(4000, math.max);
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, v) in vals.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: v / maxV),
                  duration: Duration(milliseconds: 500 + i * 15),
                  curve: Curves.easeOutCubic,
                  builder: (_, k, _) => Container(
                    height: 90 * k,
                    decoration: BoxDecoration(
                      color: v >= 4000 ? TColors.peachInk : TColors.peachInk.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Garis tensi 30 hari dengan pita target.
class BpTrendChart extends StatelessWidget {
  const BpTrendChart(this.daily, {super.key, this.height = 170});
  final List<Json> daily;
  final double height;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeOutCubic,
    builder: (_, k, _) => CustomPaint(size: Size(double.infinity, height), painter: _BpTrendPainter(daily, k)),
  );
}

class _BpTrendPainter extends CustomPainter {
  _BpTrendPainter(this.daily, this.k);
  final List<Json> daily;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 60.0, hi = 200.0;
    const left = 30.0;
    final w = size.width - left, h = size.height - 18;
    double y(num v) => h - (v - lo) / (hi - lo) * h;
    double x(int i) => left + (daily.length <= 1 ? 0 : i / (daily.length - 1) * w);

    final grid = Paint()..color = TColors.line;
    for (final v in [80, 120, 160, 200]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), grid);
      final tp = TextPainter(text: TextSpan(text: '$v', style: TText.label.copyWith(fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y(v) - 6));
    }
    canvas.drawRect(Rect.fromLTRB(left, y(140), size.width, y(90)), Paint()..color = TColors.green.withValues(alpha: 0.08));
    canvas.drawLine(Offset(left, y(140)), Offset(size.width, y(140)), Paint()..color = TColors.green.withValues(alpha: 0.5)..strokeWidth = 1.2);

    void series(String key, Color c, double width, double dot) {
      final path = Path();
      var started = false;
      final n = (daily.length * k).ceil();
      for (var i = 0; i < n; i++) {
        final v = daily[i][key] as num?;
        if (v == null) continue;
        final p = Offset(x(i), y(v));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = width..strokeJoin = StrokeJoin.round);
      for (var i = 0; i < n; i++) {
        final v = daily[i][key] as num?;
        if (v == null) continue;
        canvas.drawCircle(Offset(x(i), y(v)), dot, Paint()..color = (key == 'systolic' && v >= 160) ? TColors.red : c);
      }
    }

    series('diastolic', TColors.skyBright, 1.8, 2.2);
    series('systolic', TColors.clay, 2.6, 3.2);
    for (final (i, label) in [(0, '30 hr lalu'), (daily.length - 1, 'hari ini')]) {
      final tp = TextPainter(text: TextSpan(text: label, style: TText.label.copyWith(fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((x(i) - (i == 0 ? 0 : tp.width)).clamp(0, size.width - tp.width), size.height - 13));
    }
  }

  @override
  bool shouldRepaint(covariant _BpTrendPainter old) => old.k != k || old.daily != daily;
}
