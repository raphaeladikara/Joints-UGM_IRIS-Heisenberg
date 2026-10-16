import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/human3d.dart';
import '../../core/format.dart';
import '../../core/health_sync.dart';
import '../../core/health_widgets.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Potongan layar kesehatan untuk keluarga: ubin jam tangan, cincin target, gauge tensi, tubuh 3D, kartu sinkron.
/// Semua membaca `feed` dari /v1/contacts/{id}/feed (bagian `vitals`, `bp_history`, `adherence_7d`).

String _fmtInt(num? n) {
  if (n == null) return '–';
  final s = n.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

String _sleepText(num? min) => min == null ? '–' : '${min ~/ 60} j ${(min % 60).round().toString().padLeft(2, '0')}';

Json? _latestBp(Json f) {
  final hist = (f['bp_history'] as List?) ?? const [];
  return hist.isEmpty ? null : hist.last as Json;
}

/// Gauge tensi terbaru (dari telepon pagi atau tensimeter/jam tangan).
class BpCard extends StatelessWidget {
  const BpCard(this.feed, {super.key});
  final Json feed;

  @override
  Widget build(BuildContext context) {
    final bp = _latestBp(feed);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Tensi terakhir', style: TText.h3)),
              if (bp != null) Text('${dayLabel(bp['at'] as String?)} · ${hm(bp['at'] as String?)}', style: TText.small),
            ],
          ),
          const SizedBox(height: 14),
          BpGauge(
            systolic: (bp?['systolic'] as num?)?.toInt(),
            diastolic: (bp?['diastolic'] as num?)?.toInt(),
            sub: bp == null ? null : (bp['source'] == 'patient_report' ? 'dibacakan Mbah di telepon pagi' : 'dari jam tangan / tensimeter'),
          ),
          const SizedBox(height: 14),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              _Legend(TColors.brand, 'Normal < 140'),
              _Legend(Color(0xFFE0A100), 'Tinggi 140–179'),
              _Legend(TColors.red, 'Sangat tinggi ≥ 180'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: TText.small.copyWith(color: TColors.ink)),
    ],
  );
}

/// Empat ubin jam tangan: langkah, tidur, detak jantung, oksigen.
class WatchTiles extends StatelessWidget {
  const WatchTiles(this.vitals, {super.key});
  final Json vitals;

  @override
  Widget build(BuildContext context) {
    final latest = vitals['latest'] as Json;
    final daily = vitals['daily'] as Json;
    final goals = vitals['goals'] as Json;
    final hr = (latest['heart_rate'] as Json?)?['value'] as num?;
    final rhr = (latest['resting_hr'] as Json?)?['value'] as num?;
    final spo2 = (latest['spo2'] as Json?)?['value'] as num?;
    final spoLow = spo2 != null && spo2 < ((vitals['thresholds'] as Json)['spo2_low'] as num);
    final hrToday = (vitals['heart_rate_today'] as List?) ?? const [];

    final tiles = [
      MetricTile(
        color: TColors.peach,
        ink: TColors.peachInk,
        icon: Icons.directions_walk_rounded,
        label: 'Langkah',
        value: _fmtInt(latest['steps_today'] as num?),
        note: 'Target ${_fmtInt(goals['steps'] as num?)}',
        chart: MiniBars(daily['steps'] as List, ink: TColors.peachInk, goal: goals['steps'] as num?),
      ),
      MetricTile(
        color: TColors.lavender,
        ink: TColors.lavenderInk,
        icon: Icons.bedtime_rounded,
        label: 'Tidur',
        value: _sleepText(latest['sleep_last_min'] as num?),
        unit: 'm',
        note: 'Semalam',
        chart: MiniBars(daily['sleep'] as List, ink: TColors.lavenderInk, goal: goals['sleep_min'] as num?),
      ),
      MetricTile(
        color: TColors.sky,
        ink: TColors.skyInk,
        icon: Icons.favorite_rounded,
        label: 'Detak jantung',
        value: hr == null ? '–' : '${hr.round()}',
        unit: '/menit',
        note: rhr == null ? null : 'Saat istirahat ${rhr.round()}',
        chart: hrToday.length >= 2 ? HeartLine(hrToday, ink: TColors.skyInk) : null,
      ),
      MetricTile(
        color: spoLow ? TColors.yellowTint : TColors.sage,
        ink: spoLow ? TColors.yellow : TColors.sageInk,
        icon: Icons.air_rounded,
        label: 'Oksigen darah',
        value: spo2 == null ? '–' : '${spo2.round()}',
        unit: '%',
        note: spo2 == null ? 'Belum ada data' : (spoLow ? 'Di bawah 90%: Puskesmas diberi tahu' : 'Normal (95–100%)'),
        chart: MiniBars(daily['spo2'] as List, ink: spoLow ? TColors.yellow : TColors.sageInk, height: 40),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 320 ? 2 : 1;
        final gap = 12.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

/// Cincin target harian: langkah, tidur, minum obat 7 hari (adaptasi kartu aktivitas ala Apple Fitness).
class DailyRings extends StatelessWidget {
  const DailyRings(this.feed, {super.key});
  final Json feed;

  @override
  Widget build(BuildContext context) {
    final v = feed['vitals'] as Json;
    final latest = v['latest'] as Json;
    final goals = v['goals'] as Json;
    final adh = feed['adherence_7d'] as Json;
    final steps = (latest['steps_today'] as num?) ?? 0;
    final sleep = (latest['sleep_last_min'] as num?) ?? 0;
    final taken = (adh['taken'] as num?) ?? 0, total = (adh['total'] as num?) ?? 0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Target hari ini', style: TText.h3),
          const SizedBox(height: 14),
          ActivityRings(
            [
              Ring(
                label: 'Langkah',
                value: _fmtInt(steps),
                goalText: '/ ${_fmtInt(goals['steps'] as num)}',
                progress: steps / (goals['steps'] as num),
                color: const Color(0xFFD9622B),
                icon: Icons.directions_walk_rounded,
              ),
              Ring(
                label: 'Tidur semalam',
                value: _sleepText(sleep),
                goalText: '/ 7 j',
                progress: sleep / (goals['sleep_min'] as num),
                color: const Color(0xFF6A58C7),
                icon: Icons.bedtime_rounded,
              ),
              Ring(
                label: 'Minum obat 7 hari',
                value: '$taken',
                goalText: '/ $total hari',
                progress: total == 0 ? 0 : taken / total,
                color: TColors.green,
                icon: Icons.medication_rounded,
              ),
            ],
            size: MediaQuery.sizeOf(context).width < 380 ? 124 : 148,
          ),
        ],
      ),
    );
  }
}

/// Status koneksi jam tangan + tombol sinkron (Health Connect / Apple Health / simulasi).
class SyncCard extends StatefulWidget {
  const SyncCard({super.key, required this.patientId, required this.vitals, required this.onSynced});
  final String patientId;
  final Json? vitals;
  final VoidCallback onSynced;

  @override
  State<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<SyncCard> {
  bool _busy = false;

  Future<void> _run(Future<Json> Function() job, String ok) async {
    setState(() => _busy = true);
    try {
      final r = await job();
      if (!mounted) return;
      final yellow = r['level'] == 'yellow';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(yellow ? 'Tersinkron. Ada angka di luar batas: Puskesmas sudah diberi tahu (🟡).' : ok)),
      );
      widget.onSynced();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _native() async {
    final hs = HealthSync.instance;
    final problem = await hs.availability();
    if (!mounted) return;
    if (problem != null) {
      final install = HealthSync.isAndroid && problem.contains('Health Connect');
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Sambungkan ${HealthSync.nativeSupported ? HealthSync.sourceLabel : 'jam tangan'}'),
          content: Text(problem, style: TText.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
            if (install) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pasang Health Connect')),
          ],
        ),
      );
      if (go == true) await hs.installHealthConnect();
      return;
    }
    final granted = await hs.connect();
    if (!mounted) return;
    if (!granted) {
      showError(context, 'Izin ${HealthSync.sourceLabel} belum diberikan. Buka lagi dan centang semua data yang diminta.');
      return;
    }
    await _run(() => hs.syncNow(widget.patientId), 'Data ${HealthSync.sourceLabel} 7 hari terakhir sudah tersinkron.');
  }

  Future<void> _simulate() async {
    final scenario = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Simulasi jam tangan', style: TText.h2),
              const SizedBox(height: 4),
              Text('Untuk demo di laptop. Data fiktif dikirim seperti dari jam tangan sungguhan.', style: TText.small),
              const SizedBox(height: 12),
              for (final (key, icon, title, sub) in const [
                ('normal', Icons.watch_rounded, 'Hari biasa', 'Detak, langkah, oksigen normal'),
                ('spo2_low', Icons.air_rounded, 'Oksigen turun ke 87%', 'Memicu 🟡 tindak lanjut Puskesmas'),
                ('bp_high', Icons.monitor_heart_rounded, 'Tensi 186/104 dari jam', 'Aturan tensi yang sama dengan telepon'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: TColors.panel,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      minVerticalPadding: 14,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      leading: Icon(icon, color: TColors.brand, size: 28),
                      title: Text(title, style: TText.h3),
                      subtitle: Text(sub, style: TText.small),
                      onTap: () => Navigator.pop(ctx, key),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (scenario != null) await _run(() => HealthSync.instance.simulate(widget.patientId, scenario: scenario), 'Data jam tangan (simulasi) masuk.');
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.vitals?['last_sync'] as Json?;
    return _Panel(
      color: TColors.night,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.watch_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      last == null ? 'Jam tangan belum tersambung' : '${last['device']}',
                      style: TText.h3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last == null
                          ? 'Sambungkan Health Connect (Android) atau Apple Health (iPhone).'
                          : '${last['source_label']} · tersinkron ${ago(last['synced_at'] as String?)}',
                      style: TText.small.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TColors.ink),
            onPressed: _busy ? null : _native,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Icon(HealthSync.isIos ? Icons.favorite_rounded : Icons.sync_rounded),
            label: Text(HealthSync.nativeSupported ? 'Sinkronkan dari ${HealthSync.sourceLabel}' : 'Sambungkan jam tangan'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
            onPressed: _busy ? null : _simulate,
            icon: const Icon(Icons.science_rounded),
            label: const Text('Simulasi jam tangan'),
          ),
          const SizedBox(height: 10),
          Text(
            'Samsung Health, Wear OS, Fitbit, Mi Fitness, dan Huawei Health menyalin data ke Health Connect. '
            'KRING hanya membaca, tidak pernah mengubah data kesehatan.',
            style: TText.small.copyWith(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// Tab "Tubuh": model 3D dengan titik otak, jantung, paru, lengan (tensi), perut (obat), kaki (langkah).
class BodyView extends StatefulWidget {
  const BodyView(this.feed, {super.key, required this.onSynced});
  final Json feed;
  final VoidCallback onSynced;

  @override
  State<BodyView> createState() => _BodyViewState();
}

class _BodyViewState extends State<BodyView> {
  String _sel = 'brain';

  List<(BodySpot, String)> _spots() {
    final f = widget.feed;
    final v = f['vitals'] as Json;
    final latest = v['latest'] as Json;
    final th = v['thresholds'] as Json;
    final today = f['today'] as Json?;
    final red = f['red_alert'] as Json?;
    final name = f['patient']['display_name'] as String;

    final brain = red != null
        ? ('red', 'TANDA BAHAYA. ${(red['reasons'] as List).map((r) => r['label']).join(', ')}.')
        : today == null
        ? ('none', 'KRING belum menelepon $name hari ini.')
        : today['status'] == 'completed'
        ? (today['final_level'] == 'red' ? 'red' : 'green', 'Telepon pagi: tidak ada tanda stroke (bicara, wajah, lengan, penglihatan).')
        : ('none', 'Telepon pagi belum selesai.');

    final hr = (latest['heart_rate'] as Json?)?['value'] as num?;
    final rhr = (latest['resting_hr'] as Json?)?['value'] as num?;
    final heartLevel = hr == null ? 'none' : ((rhr ?? 0) >= (th['hr_high_rest'] as num) || hr <= (th['hr_low'] as num) ? 'yellow' : 'green');

    final spo2 = (latest['spo2'] as Json?)?['value'] as num?;
    final bp = _latestBp(f);
    final sys = (bp?['systolic'] as num?)?.toInt();
    final bpLevel = sys == null ? 'none' : (sys >= 160 ? 'yellow' : 'green');

    final adh = f['adherence_7d'] as Json;
    final days = (adh['days'] as List?) ?? const [];
    final lastMed = days.isEmpty ? null : days.last as Json;
    final steps = latest['steps_today'] as num?;

    return [
      (BodySpot(id: 'brain', label: 'Otak', anchor: (0, 1.665, 0.085), level: brain.$1, icon: Icons.psychology_rounded, value: brain.$2), 'Skrining stroke dari telepon'),
      (
        BodySpot(
          id: 'heart',
          label: 'Jantung',
          anchor: (0.06, 1.32, 0.105),
          level: heartLevel,
          icon: Icons.favorite_rounded,
          value: hr == null ? 'Belum ada data jam tangan.' : 'Detak ${hr.round()}/menit${rhr == null ? '' : ', saat istirahat ${rhr.round()}/menit'}.',
        ),
        'Dari jam tangan',
      ),
      (
        BodySpot(
          id: 'lungs',
          label: 'Paru · oksigen',
          anchor: (-0.075, 1.33, 0.1),
          level: spo2 == null ? 'none' : (spo2 < (th['spo2_low'] as num) ? 'yellow' : 'green'),
          icon: Icons.air_rounded,
          value: spo2 == null ? 'Belum ada data jam tangan.' : 'Saturasi oksigen ${spo2.round()}% (normal 95–100%).',
        ),
        'Dari jam tangan',
      ),
      (
        BodySpot(
          id: 'arm',
          label: 'Tensi',
          anchor: (0.228, 1.25, 0.045),
          level: bpLevel,
          icon: Icons.monitor_heart_rounded,
          value: sys == null ? 'Belum ada tensi.' : 'Tensi $sys/${bp!['diastolic']} mmHg · ${BpGauge.zone(sys).$1.toLowerCase()}.',
        ),
        'Telepon pagi / tensimeter',
      ),
      (
        BodySpot(
          id: 'meds',
          label: 'Obat',
          anchor: (0, 1.08, 0.1),
          level: lastMed == null ? 'none' : (lastMed['status'] == 'sudah' ? 'green' : 'yellow'),
          icon: Icons.medication_rounded,
          value: lastMed == null
              ? 'Belum ada catatan obat.'
              : 'Obat terakhir ${lastMed['status'] == 'sudah' ? 'sudah' : 'belum'} diminum · ${adh['taken']}/${adh['total']} hari dalam seminggu.',
        ),
        'Ditanyakan di telepon pagi',
      ),
      (
        BodySpot(
          id: 'legs',
          label: 'Gerak',
          anchor: (-0.1, 0.42, 0.065),
          level: steps == null ? 'none' : 'green',
          icon: Icons.directions_walk_rounded,
          value: steps == null ? 'Belum ada data langkah.' : '${_fmtInt(steps)} langkah hari ini.',
        ),
        'Dari jam tangan',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spots = _spots();
    final sel = spots.firstWhere((s) => s.$1.id == _sel, orElse: () => spots.first);
    final c = spotColor(sel.$1.level);
    final name = widget.feed['patient']['display_name'] as String;
    // Model mengisi ± separuh layar: di HP 9:16 chip & panel detail tetap terlihat tanpa menggulir jauh.
    final modelH = (MediaQuery.sizeOf(context).height * 0.5).clamp(300.0, 460.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        Text('Tubuh $name hari ini', style: context.compact ? TText.h2 : TText.h1),
        Text('Geser untuk memutar, ketuk titik untuk detail.', style: TText.small),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const RadialGradient(center: Alignment(0, -0.2), radius: 0.9, colors: [Color(0xFFFFFFFF), Color(0xFFE6EDF7)]),
            boxShadow: TShadow.soft,
          ),
          child: Human3D(spots: [for (final s in spots) s.$1], sex: (widget.feed['patient']['sex'] as String?) ?? 'F', selected: _sel, onSelect: (id) => setState(() => _sel = id), height: modelH),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (s, _) in spots)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: s.id == _sel,
                    onSelected: (_) => setState(() => _sel = s.id),
                    showCheckmark: false,
                    avatar: Icon(s.icon, size: 20, color: s.id == _sel ? Colors.white : spotColor(s.level)),
                    label: Text(s.label),
                    labelStyle: TText.small.copyWith(color: s.id == _sel ? Colors.white : TColors.ink, fontWeight: FontWeight.w800),
                    selectedColor: TColors.night,
                    backgroundColor: TColors.panel,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: StadiumBorder(side: BorderSide(color: s.id == _sel ? TColors.night : TColors.line)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _Panel(
            key: ValueKey(_sel),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
                  child: Icon(sel.$1.icon, color: c, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(sel.$1.label, style: TText.h2)),
                          LevelChip(
                            sel.$1.level == 'none' ? 'scheduled' : sel.$1.level,
                            text: switch (sel.$1.level) {
                              'red' => 'Darurat',
                              'yellow' => 'Perlu dicek',
                              'green' => 'Baik',
                              _ => 'Belum ada data',
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(sel.$1.value ?? '', style: TText.body),
                      const SizedBox(height: 6),
                      Text(sel.$2, style: TText.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SyncCard(patientId: widget.feed['patient']['id'] as String, vitals: widget.feed['vitals'] as Json?, onSynced: widget.onSynced),
        const SizedBox(height: 12),
        Text(
          'Model tubuh adalah ilustrasi, bukan hasil pemeriksaan. Data jam tangan konsumen bukan alat diagnosis.',
          style: TText.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Panel putih standar layar kesehatan (bayangan lembut, sudut 26).
class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.color = TColors.panel});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(26), boxShadow: TShadow.soft),
    child: child,
  );
}

class HealthPanel extends _Panel {
  const HealthPanel({super.key, required super.child, super.color});
}
