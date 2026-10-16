import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/pipo.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Kartu "Hubungi dokter" di beranda wali. Menonjol (berwarna) bila TILIK menemukan hal janggal; selalu tersedia.
/// Mode demo: dokter jaga menerima panggilan di aplikasi Puskesmas, tidak ada nomor sungguhan yang ditelepon.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.feed, required this.contactId, required this.onChanged});
  final Json feed;
  final String contactId;
  final VoidCallback onChanged;

  Future<void> _start(BuildContext context, String mode) async {
    final p = feed['patient'] as Json;
    try {
      final c = await Api.instance.requestDoctor(p['id'] as String, contactId, mode: mode);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => DoctorCallScreen(consult: c)));
      onChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = feed['doctor'] as Json;
    final suggest = doc['suggest'] as Json;
    final reasons = ((suggest['reasons'] as List?) ?? const []).cast<String>();
    final active = feed['doctor_consult'] as Json?;
    final s = LevelStyle.of(suggest['level'] as String?);
    final flagged = suggest['recommended'] == true;
    final name = feed['patient']['display_name'] as String;
    return Container(
      decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(26), boxShadow: TShadow.soft),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flagged)
            Container(
              color: s.bg,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(s.icon, color: s.fg, size: 22),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Ada yang perlu dicek dokter', style: TText.h3.copyWith(color: s.fg))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final r in reasons.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('•  $r', style: TText.small.copyWith(color: TColors.ink)),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _DoctorAvatar(size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${doc['name']}', style: TText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${doc['role']} · ${doc['facility']}', style: TText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const _OnlineDot(),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  flagged
                      ? 'Dokter langsung menerima ringkasan kondisi $name hari ini (tensi, detak, oksigen, obat).'
                      : 'Ragu dengan kondisi $name? Dokter jaga siap ${doc['hours']}, ringkasan kondisi ikut terkirim.',
                  style: TText.small,
                ),
                const SizedBox(height: 14),
                if (active != null)
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(fullscreenDialog: true, builder: (_) => DoctorCallScreen(consult: active)),
                      );
                      onChanged();
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded),
                    label: Text(active['status'] == 'in_call' ? 'Kembali ke panggilan' : 'Sedang menghubungi…'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: flagged ? FilledButton.styleFrom(backgroundColor: s.fg == TColors.grey ? TColors.brand : s.fg) : null,
                          onPressed: () => _start(context, 'video'),
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('Video call'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _start(context, 'voice'),
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Telepon'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [TColors.skyBlue, TColors.brand]),
    ),
    child: Icon(Icons.medical_services_rounded, color: Colors.white, size: size * 0.48),
  );
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: TColors.greenTint, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: TColors.green, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('Siaga', style: TText.label.copyWith(color: TColors.green)),
      ],
    ),
  );
}

/// Layar panggilan ke dokter: berdering sampai dokter menerima di aplikasi Puskesmas, lalu durasi berjalan.
/// Ringkasan yang dikirim ke dokter selalu terlihat, supaya wali tahu data apa yang dibagikan.
class DoctorCallScreen extends StatefulWidget {
  const DoctorCallScreen({super.key, required this.consult});
  final Json consult;
  @override
  State<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends State<DoctorCallScreen> with Poller<DoctorCallScreen> {
  late Json _c = widget.consult;
  bool _muted = false;
  bool _speaker = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 2));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Future<void> poll() async {
    final c = await Api.instance.consult(_c['id'] as String);
    if (mounted) setState(() => _c = c);
  }

  Future<void> _end() async {
    try {
      if (_c['status'] == 'ringing' || _c['status'] == 'in_call') {
        await Api.instance.setConsultStatus(_c['id'] as String, 'ended');
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  String _elapsed() {
    final at = DateTime.tryParse('${_c['answered_at']}');
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final doc = _c['doctor'] as Json;
    final status = _c['status'] as String;
    final video = _c['mode'] == 'video';
    final ended = status == 'ended' || status == 'declined';
    final headline = switch (status) {
      'ringing' => video ? 'Memanggil video…' : 'Memanggil…',
      'in_call' => 'Tersambung · ${_elapsed()}',
      'declined' => 'Dokter sedang sibuk',
      _ => 'Panggilan selesai',
    };
    final ctx = (_c['context'] as Json?) ?? const {};
    return Scaffold(
      body: PipoBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Align(alignment: Alignment.centerLeft, child: const DemoBadge()),
                  const SizedBox(height: 28),
                  Center(child: _Ripple(active: status == 'ringing', child: const _DoctorAvatar(size: 112))),
                  const SizedBox(height: 18),
                  Text('${doc['name']}', style: TText.h1, textAlign: TextAlign.center),
                  Text('${doc['role']} · ${doc['facility']}', style: TText.small.copyWith(color: TColors.ink.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(headline, style: TText.h3.copyWith(color: TColors.brandDeep), textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  _summary(ctx),
                  if (_c['doctor_note'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: TColors.sky, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catatan dokter', style: TText.label.copyWith(color: TColors.skyInk)),
                          const SizedBox(height: 4),
                          Text('${_c['doctor_note']}', style: TText.body),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  if (!ended)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundAction(
                          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _muted ? 'Bisu' : 'Mikrofon',
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _RoundAction(icon: Icons.call_end_rounded, label: 'Tutup', danger: true, onTap: _end),
                        _RoundAction(
                          icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                          label: _speaker ? 'Speaker' : 'Telinga',
                          onTap: () => setState(() => _speaker = !_speaker),
                        ),
                      ],
                    )
                  else
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kembali')),
                  const SizedBox(height: 16),
                  Text(
                    'Demo: dokter menerima panggilan di aplikasi Puskesmas. Untuk keadaan darurat tetap hubungi 119.',
                    style: TText.small.copyWith(color: TColors.ink.withValues(alpha: 0.65)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(Json ctx) {
    final bp = ctx['blood_pressure'] as Json?;
    final hr = ctx['heart_rate'] as Json?;
    final spo2 = ctx['spo2'] as Json?;
    final adh = ctx['adherence_7d'] as Json?;
    final concerns = ((ctx['concerns'] as List?) ?? const []).cast<String>();
    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TText.label),
          const SizedBox(height: 2),
          Text(value, style: TText.h3.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(24), boxShadow: TShadow.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dikirim ke dokter · ${_c['patient_name']}, ${_c['patient_age']} th', style: TText.label),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Tensi', bp == null ? '–' : '${bp['systolic']}/${bp['diastolic']}'),
              stat('Detak', hr == null ? '–' : '${(hr['value'] as num).round()}'),
              stat('Oksigen', spo2 == null ? '–' : '${(spo2['value'] as num).round()}%'),
              stat('Obat', adh == null || adh['total'] == 0 ? '–' : '${adh['taken']}/${adh['total']}'),
            ],
          ),
          if (concerns.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in concerns) Text('•  $r', style: TText.small.copyWith(color: TColors.ink)),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: danger ? TColors.red : Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 72, height: 72, child: Icon(icon, size: 30, color: danger ? Colors.white : TColors.ink)),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: TText.label.copyWith(color: TColors.ink)),
    ],
  );
}

/// Gelombang lembut di sekitar avatar selama berdering.
class _Ripple extends StatefulWidget {
  const _Ripple({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      width: 190,
      height: 190,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active && !still)
              for (final k in [0.0, 0.5])
                Builder(builder: (_) {
                  final v = (_a.value + k) % 1;
                  return Container(
                    width: 112 + 78 * v,
                    height: 112 + 78 * v,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: TColors.brand.withValues(alpha: 0.18 * (1 - v))),
                  );
                }),
            child!,
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
