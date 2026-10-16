import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/mascot.dart';
import '../../core/theme.dart';
import '../../core/voice_note.dart';
import '../../core/widgets.dart';

/// Fitur lanjutan aplikasi keluarga & Sahabat Kring:
/// pesan suara asli (F-03), protokol tidak diangkat (F-19), jadwal Prolanis/posyandu + ambil obat, suasana hati.

String _day(String ymd) => dayLabel('${ymd}T12:00:00+07:00');

BoxDecoration _card([Color c = TColors.panel]) =>
    BoxDecoration(color: c, borderRadius: BorderRadius.circular(26), boxShadow: c == TColors.panel ? TShadow.soft : null);

// ---------- F-03 rekam pesan suara ----------

class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({super.key, required this.patientId, required this.contactId, required this.onSent});
  final String patientId, contactId;
  final VoidCallback onSent;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final _vn = VoiceNote.instance;
  bool _recording = false, _sending = false, _playing = false;
  (Uint8List, int)? _clip;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    if (_recording) _vn.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    if (!await _vn.start()) {
      if (mounted) showError(context, 'Mikrofon tidak bisa dipakai. Izinkan akses mikrofon untuk aplikasi ini.');
      return;
    }
    setState(() {
      _recording = true;
      _clip = null;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_vn.elapsed >= VoiceNote.maxSeconds) {
        _stop();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _stop() async {
    _tick?.cancel();
    final clip = await _vn.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _clip = clip;
    });
    if (clip == null) showError(context, 'Rekaman terlalu pendek. Tekan rekam, bicara, lalu tekan selesai.');
  }

  Future<void> _preview() async {
    final c = _clip;
    if (c == null) return;
    setState(() => _playing = true);
    await _vn.play(c.$1, mimeType: _vn.mime, seconds: c.$2);
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _send() async {
    final c = _clip;
    if (c == null || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.instance.sendVoiceMessage(widget.patientId, widget.contactId, c.$1, _vn.mime, c.$2);
      if (!mounted) return;
      setState(() => _clip = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pesan suara dititipkan. KRING memutarnya di telepon pagi berikutnya.')));
      widget.onSent();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      final s = _vn.elapsed;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: TColors.redTint, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record_rounded, color: TColors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Merekam… 0:${s.toString().padLeft(2, '0')} / 1:00', style: TText.h3.copyWith(color: TColors.red))),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: TColors.red),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Selesai'),
            ),
          ],
        ),
      );
    }
    final c = _clip;
    if (c != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: _playing ? null : _preview,
              icon: Icon(_playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded),
              tooltip: 'Dengar dulu',
            ),
            const SizedBox(width: 6),
            Expanded(child: Text('Pesan suara ${c.$2} detik', style: TText.h3)),
            IconButton(onPressed: () => setState(() => _clip = null), icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Hapus'),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Titipkan'),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Colors.white),
      onPressed: _start,
      icon: const Icon(Icons.mic_rounded),
      label: const Text('Rekam pesan suara'),
    );
  }
}

// ---------- F-19 protokol tidak diangkat ----------

class NoAnswerCard extends StatefulWidget {
  const NoAnswerCard({super.key, required this.feed, required this.contactId, required this.onChanged});
  final Json feed;
  final String contactId;
  final VoidCallback onChanged;

  @override
  State<NoAnswerCard> createState() => _NoAnswerCardState();
}

class _NoAnswerCardState extends State<NoAnswerCard> {
  final _note = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.feed['no_answer'] as Json?;
    if (st == null || st['stage'] == 'answered') return const SizedBox.shrink();
    final name = widget.feed['patient']['display_name'] as String;
    final stage = st['stage'] as String?;
    final hc = st['home_check'] as Json?;
    final retry = st['retry'] as Json?;
    final missed = ((st['missed_at'] as List?) ?? const []).cast<String>();
    final mine = hc != null && hc['contact_id'] == widget.contactId && hc['status'] == 'requested';
    final checker = hc?['contact_name'] ?? 'Sahabat Kring';
    final (bg, icon, title, desc) = switch (stage) {
      'retry_scheduled' || 'retrying' => (
        TColors.yellowTint,
        Icons.phone_missed_rounded,
        '$name belum mengangkat',
        'Telepon pukul ${missed.map(hm).join(', ')} belum diangkat. KRING menelepon ulang pukul ${hm(retry?['due_at'] as String?)}.',
      ),
      'home_check' => (
        TColors.yellowTint,
        Icons.house_rounded,
        mine ? 'Mohon tengok $name sekarang' : '$checker diminta menengok $name',
        'Sudah 2× tidak diangkat (pukul ${missed.map(hm).join(' & ')}). ${mine ? 'Kabari hasilnya lewat tombol di bawah.' : 'Hasilnya akan muncul di sini.'}',
      ),
      'checked_ok' => (TColors.greenTint, Icons.verified_rounded, '$name baik-baik saja', '$checker sudah menengok${_noteOf(hc)}.'),
      'not_home' => (TColors.yellowTint, Icons.no_meeting_room_rounded, '$name tidak ada di rumah', '$checker sudah ke rumah${_noteOf(hc)}. Coba hubungi kerabat lain.'),
      'help' => (TColors.redTint, Icons.emergency_rounded, '$name butuh bantuan', '$checker menemukan $name butuh bantuan${_noteOf(hc)}. Darurat sudah dieskalasi.'),
      _ => (TColors.yellowTint, Icons.phone_missed_rounded, 'Telepon pagi tidak diangkat', 'KRING mencatat panggilan tidak diangkat.'),
    };
    final steps = [
      ('Telepon pagi', missed.isNotEmpty),
      ('Ulang 15 menit', missed.length >= 2 || stage == 'retrying'),
      ('Cek ke rumah', hc != null),
      ('Kabar', hc != null && hc['status'] != 'requested'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 30, color: TColors.ink),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TText.h3)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: TText.body),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, (label, done)) in steps.indexed) ...[
                if (i > 0) Expanded(child: Container(height: 2, color: done ? TColors.ink : TColors.line)),
                Column(
                  children: [
                    Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 22, color: done ? TColors.ink : TColors.muted),
                    Text(label, style: TText.label.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
          if (stage == 'retry_scheduled' && retry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() => Api.instance.retryNow(retry['id'] as String)),
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Demo: telepon ulang sekarang'),
            ),
          ],
          if (mine) ...[
            const SizedBox(height: 12),
            TextField(controller: _note, maxLength: 120, decoration: const InputDecoration(hintText: 'Catatan singkat (mis. "sedang di sawah")', isDense: true)),
            const SizedBox(height: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: TColors.green, minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : () => _run(() => Api.instance.homeCheck(hc['id'] as String, 'ok', note: _note.text.trim())),
              icon: const Icon(Icons.thumb_up_rounded),
              label: Text('$name baik-baik saja'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => Api.instance.homeCheck(hc['id'] as String, 'not_home', note: _note.text.trim())),
                    child: const Text('Tidak ada di rumah'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: TColors.red),
                    onPressed: _busy ? null : () => _run(() => Api.instance.homeCheck(hc['id'] as String, 'help', note: _note.text.trim())),
                    child: const Text('Butuh bantuan'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _noteOf(Json? hc) {
    final n = (hc?['note'] as String?) ?? '';
    return n.isEmpty ? '' : ' ("$n")';
  }
}

// ---------- jadwal Prolanis & posyandu + ambil obat ----------

class ScheduleCard extends StatefulWidget {
  const ScheduleCard({super.key, required this.feed, required this.onChanged, this.canEdit = true});
  final Json feed;
  final VoidCallback onChanged;
  final bool canEdit;

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  bool _busy = false;

  String get _pid => widget.feed['patient']['id'] as String;

  Future<void> _run(Future<Object?> Function() f, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    var kind = 'posyandu';
    final now = toWib(DateTime.now());
    var date = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    var time = const TimeOfDay(hour: 9, minute: 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Tambah jadwal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'posyandu', label: Text('Posyandu')), ButtonSegment(value: 'prolanis', label: Text('Prolanis'))],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded),
                label: Text('${date.day}/${date.month}/${date.year}'),
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(now.year, now.month, now.day), lastDate: date.add(const Duration(days: 365)));
                  if (d != null) set(() => date = d);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text('${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}'),
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: time);
                  if (t != null) set(() => time = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    String two(int n) => n.toString().padLeft(2, '0');
    await _run(() => Api.instance.addAppointment(_pid, kind, '${date.year}-${two(date.month)}-${two(date.day)}', '${two(time.hour)}:${two(time.minute)}'),
        'Jadwal ditambahkan. KRING mengingatkan sehari sebelumnya.');
  }

  @override
  Widget build(BuildContext context) {
    final sched = (widget.feed['care'] as Json?)?['schedule'] as Json?;
    if (sched == null) return const SizedBox.shrink();
    final upcoming = (sched['upcoming'] as List).cast<Json>();
    final pickup = sched['pickup'] as Json?;
    final (pc, pIcon) = switch (pickup?['status']) {
      'now' => (TColors.redTint, Icons.local_pharmacy_rounded),
      'before_visit' => (TColors.yellowTint, Icons.local_pharmacy_rounded),
      _ => (TColors.greenTint, Icons.inventory_2_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pickup != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: pc, borderRadius: BorderRadius.circular(18)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(pIcon, color: TColors.ink, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (pickup['status']) {
                            'now' => 'Ambil obat hari ini',
                            'before_visit' => 'Ambil obat paling lambat ${_day(pickup['pickup_by'] as String)}',
                            'at_visit' => 'Ambil obat saat kontrol',
                            _ => 'Stok obat aman',
                          },
                          style: TText.h3,
                        ),
                        Text(pickup['message'] as String, style: TText.small.copyWith(color: TColors.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty) Text('Belum ada jadwal kontrol.', style: TText.body),
          for (final a in upcoming) _row(a, pickup),
          if (widget.canEdit)
            TextButton.icon(onPressed: _busy ? null : _add, icon: const Icon(Icons.add_rounded), label: const Text('Tambah jadwal')),
        ],
      ),
    );
  }

  Widget _row(Json a, Json? pickup) {
    final d = a['days_until'] as int;
    final prolanis = a['kind'] == 'prolanis';
    final when = d == 0 ? 'Hari ini' : (d == 1 ? 'Besok' : '$d hari lagi');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: prolanis ? TColors.sky : TColors.sage, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text((a['date'] as String).substring(8), style: TText.h2.copyWith(color: prolanis ? TColors.skyInk : TColors.sageInk)),
                Text(_day(a['date'] as String).split(' ').last, style: TText.label.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(when.toUpperCase(), style: TText.label.copyWith(fontSize: 11.5, color: d <= 1 ? TColors.brandDeep : TColors.muted)),
                Text('${a['title']}', style: TText.h3.copyWith(fontSize: 16.5)),
                Text('${(a['time'] as String).replaceAll(':', '.')} · ${a['place']}', style: TText.small),
                if ((a['note'] as String?)?.isNotEmpty ?? false) Text(a['note'] as String, style: TText.label.copyWith(color: TColors.muted)),
              ],
            ),
          ),
          if (widget.canEdit && d <= 1)
            IconButton.filledTonal(
              tooltip: 'Sudah datang',
              onPressed: _busy
                  ? null
                  : () => _run(() => Api.instance.setAppointmentStatus(a['id'] as String, 'done', pickedUpMeds: prolanis || pickup?['status'] != 'ok'),
                      prolanis ? 'Kontrol selesai. Stok obat +30, jadwal berikutnya 4 minggu lagi.' : 'Posyandu selesai dicatat.'),
              icon: const Icon(Icons.task_alt_rounded),
            ),
        ],
      ),
    );
  }
}

// ---------- suasana hati & kesepian ----------

class MoodCard extends StatelessWidget {
  const MoodCard({super.key, required this.mood, required this.name, this.onCall, this.compact = false});
  final Json mood;
  final String name;
  final VoidCallback? onCall;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final daily = (mood['daily'] as List).cast<Json>();
    final level = mood['level'] as String;
    final last = mood['last_lonely'] as Json?;
    final (bg, tili) = switch (level) {
      'nudge' => (const Color(0xFFF7E4DA), TiliMood.worried),
      'watch' => (TColors.butter, TiliMood.calm),
      _ => (TColors.lavender, TiliMood.happy),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tili(mood: tili, size: 52),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suasana hati $name', style: TText.h3),
                    Text(
                      switch (level) { 'nudge' => 'Sering kesepian minggu ini', 'watch' => 'Perlu diperhatikan', _ => 'Baik-baik saja' },
                      style: TText.small.copyWith(color: TColors.ink, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('💛 ${mood['lonely_days_7']}', style: TText.h2),
                  Text('kangen/7 hr', style: TText.label.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (_, box) {
              final n = daily.length;
              final cell = ((box.maxWidth - (n - 1) * 4) / n).clamp(8.0, 30.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in daily)
                    Tooltip(
                      message: '${_day(d['date'] as String)}: ${d['mood'] ?? 'tidak ada obrolan'}${d['lonely'] == true ? ' · kangen/sepi' : ''}',
                      child: Column(
                        children: [
                          Container(
                            width: cell,
                            height: cell,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (d['mood']) {
                                'senang' => const Color(0xFF3E9B6A),
                                'biasa' => const Color(0xFF9CC5B0),
                                'sedih' => const Color(0xFFE9A27E),
                                _ => Colors.white.withValues(alpha: 0.7),
                              },
                            ),
                            child: d['lonely'] == true ? Text('💛', style: TextStyle(fontSize: cell * 0.5)) : null,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${daily.length} hari lalu', style: TText.label.copyWith(fontSize: 11)),
              const Spacer(),
              Text('hari ini', style: TText.label.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(mood['summary'] as String, style: TText.body),
          if (!compact && last != null) ...[
            const SizedBox(height: 8),
            Text('Terakhir (${_day(last['date'] as String)}): “${last['quote']}”', style: TText.small.copyWith(fontStyle: FontStyle.italic, color: TColors.ink)),
          ],
          if (onCall != null && level != 'ok') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: TColors.night, minimumSize: const Size.fromHeight(52)),
              onPressed: onCall,
              icon: const Icon(Icons.favorite_rounded),
              label: Text('Telepon $name 5 menit'),
            ),
          ],
          const SizedBox(height: 6),
          Text('Dari cerita di telepon pagi, bukan diagnosis.', style: TText.label.copyWith(color: TColors.muted)),
        ],
      ),
    );
  }
}
