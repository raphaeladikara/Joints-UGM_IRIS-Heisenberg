import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../contact/health_views.dart';
import '../phone/mbah_phone.dart';
import 'call_transcript.dart';
import 'doctor_inbox.dart';

/// F-13 Daftar Tilik Hari Ini untuk perawat Prolanis: 🔴/🟡 di paling atas, alasan tindak lanjut, tensi, kepatuhan.
class DaftarTilik extends StatefulWidget {
  const DaftarTilik({super.key});
  @override
  State<DaftarTilik> createState() => _DaftarTilikState();
}

class _DaftarTilikState extends State<DaftarTilik> with Poller<DaftarTilik> {
  Json? _data;

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 3));
  }

  @override
  Future<void> poll() async {
    final d = await Api.instance.today();
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daftar Tilik Hari Ini'),
            Text(d == null ? '' : '${d['puskesmas']} · ${dayLabel('${d['date']}T08:00:00+07:00')}', style: TText.small),
          ],
        ),
      ),
      body: d == null
          ? (pollError != null ? ErrorBanner(pollError!, onRetry: refreshNow) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: refreshNow,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (pollError != null) ErrorBanner(pollError!),
                      const DoctorInbox(),
                      _counts(d['counts'] as Json),
                      const SectionTitle('Prioritas tindak lanjut'),
                      for (final r in (d['rows'] as List).cast<Json>()) _row(r),
                      const SizedBox(height: 12),
                      const Center(child: DemoBadge()),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _counts(Json c) {
    Widget box(String key, String label) {
      final s = LevelStyle.of(key);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Icon(s.icon, color: s.fg, size: 20),
              Text('${c[key] ?? 0}', style: TText.h1.copyWith(color: s.fg)),
              Text(
                label,
                style: TText.small.copyWith(color: s.fg, fontSize: 11.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          box('red', 'Darurat'),
          box('yellow', 'Tindak lanjut'),
          box('no_answer', 'Tak diangkat'),
          box('green', 'Aman'),
          box('scheduled', 'Belum'),
        ],
      ),
    );
  }

  Widget _row(Json r) {
    final p = r['patient'] as Json;
    final bp = r['last_bp'] as Json?;
    final adh = r['adherence_7d'] as Json;
    final follow = (r['follow_up'] as List).cast<String>();
    final s = LevelStyle.of(r['status'] as String);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetail(patientId: p['id'] as String))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: s.fg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${p['display_name']} · ${p['age']} th', style: TText.h3)),
                            LevelChip(r['status'] as String),
                          ],
                        ),
                        Text('${p['village']} · telepon ${p['call_time_local']}', style: TText.small),
                        if (follow.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final f in follow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    f,
                                    style: TText.small.copyWith(color: s.fg, fontWeight: FontWeight.w800),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border_rounded, size: 16, color: TColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              bp == null ? 'Tensi –' : 'Tensi ${bp['systolic']}/${bp['diastolic']} (${shortDay(bp['at'] as String?)})',
                              style: TText.small,
                            ),
                            const SizedBox(width: 14),
                            const Icon(Icons.medication_outlined, size: 16, color: TColors.muted),
                            const SizedBox(width: 4),
                            Text('Obat ${adh['taken']}/${adh['total']} hari', style: TText.small),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detail pasien untuk nakes: tren tensi, kepatuhan, memori, riwayat panggilan, "Tilik sekarang", simulasi sinyal.
class PatientDetail extends StatefulWidget {
  const PatientDetail({super.key, required this.patientId});
  final String patientId;
  @override
  State<PatientDetail> createState() => _PatientDetailState();
}

class _PatientDetailState extends State<PatientDetail> with Poller<PatientDetail> {
  Json? _p;

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 3));
  }

  @override
  Future<void> poll() async {
    final p = await Api.instance.patient(widget.patientId);
    if (mounted) setState(() => _p = p);
  }

  Future<void> _tilikNow({required bool here}) async {
    try {
      await Api.instance.startCall(widget.patientId);
      if (!mounted) return;
      if (here) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MbahPhone(patientId: widget.patientId)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('HP pasien berdering. Buka peran "HP Mbah" di perangkat lain.')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _simulate(String type, {Json payload = const {}, String source = 'wearable'}) async {
    try {
      final r = await Api.instance.event(widget.patientId, type, source: source, payload: payload);
      if (!mounted) return;
      final msg = switch (r['action']) {
        'calling_patient' => 'Jam tangan: jatuh terdeteksi. TILIK langsung menelepon pasien (cek HP Mbah).',
        'escalated' => 'Sinyal darurat → eskalasi 🔴 ke Sahabat Tilik, keluarga, dan IGD.',
        'follow_up' => 'Sinyal dicatat → masuk Daftar Tilik (🟡).',
        _ => 'Sinyal dicatat.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: Text(p?['display_name'] as String? ?? 'Pasien')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['full_name']} · ${p['age']} th · ${p['sex'] == 'F' ? 'P' : 'L'}', style: TText.h3),
                            Text(
                              '${p['village']} · bahasa ${p['preferred_language']} · telepon ${p['call_time_local']}',
                              style: TText.small,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Obat: ${(p['medications'] as List).map((m) => '${m['name']} (${m['schedule']})${m['is_anticoagulant'] == true ? ' ⚠ antikoagulan' : ''}').join(', ')}',
                              style: TText.body,
                            ),
                            Text(
                              'Kontak: ${(p['contacts'] as List).map((c) => '${c['name']} (${c['role'] == 'child' ? 'anak' : 'Sahabat Tilik'})').join(' · ')}',
                              style: TText.small,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _tilikNow(here: false),
                                    icon: const Icon(Icons.phone_forwarded_rounded),
                                    label: const Text('Tilik sekarang'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(onPressed: () => _tilikNow(here: true), child: const Text('Jawab di HP ini')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionTitle('Simulasi sinyal perangkat (F-18)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.watch_rounded, size: 18),
                          label: const Text('Jam tangan: jatuh'),
                          onPressed: () => _simulate('fall_detected'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.sos_rounded, size: 18),
                          label: const Text('Tombol SOS'),
                          onPressed: () => _simulate('sos_pressed', source: 'sos_button'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.monitor_heart_rounded, size: 18),
                          label: const Text('Ritme tidak teratur'),
                          onPressed: () => _simulate('irregular_rhythm'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.bloodtype_rounded, size: 18),
                          label: const Text('Tensimeter BT: 186/112'),
                          onPressed: () => _simulate('bp_reading', source: 'sensor', payload: {'systolic': 186, 'diastolic': 112}),
                        ),
                      ],
                    ),
                    SectionTitle(
                      'Jam tangan',
                      trailing: Text(
                        (p['vitals']?['last_sync'] as Json?) == null
                            ? 'belum tersambung'
                            : '${p['vitals']['last_sync']['source_label']} · ${ago(p['vitals']['last_sync']['synced_at'] as String?)}',
                        style: TText.small,
                      ),
                    ),
                    if (p['vitals']?['connected'] == true)
                      WatchTiles(p['vitals'] as Json)
                    else
                      Text('Pasien belum menyambungkan jam tangan. Keluarga bisa menyambungkannya dari aplikasi keluarga.', style: TText.small),
                    const SectionTitle('Tensi 14 hari'),
                    Card(
                      child: Padding(padding: const EdgeInsets.all(16), child: BpChart(p['bp_history'] as List)),
                    ),
                    SectionTitle(
                      'Kepatuhan obat 7 hari',
                      trailing: Text('${p['adherence_7d']['taken']}/${p['adherence_7d']['total']}', style: TText.h3),
                    ),
                    Card(
                      child: Padding(padding: const EdgeInsets.all(16), child: AdherenceRow(p['adherence_7d']['days'] as List)),
                    ),
                    if ((p['memories'] as List).isNotEmpty) ...[
                      const SectionTitle('Memori TILIK'),
                      Card(
                        child: Column(
                          children: [
                            for (final m in (p['memories'] as List))
                              ListTile(
                                leading: const Icon(Icons.bookmark_border_rounded),
                                title: Text(m['fact'] as String, style: TText.body),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SectionTitle('Riwayat panggilan'),
                    for (final s in (p['sessions'] as List).cast<Json>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallTranscript(sessionId: s['id'] as String))),
                            leading: LevelChip(
                              s['status'] == 'completed'
                                  ? (s['final_level'] as String? ?? 'green')
                                  : s['status'] == 'no_answer'
                                  ? 'no_answer'
                                  : 'in_progress',
                              text: '',
                            ),
                            title: Text(
                              '${dayLabel(s['started_at'] as String?)} · ${hm(s['started_at'] as String?)}${s['trigger'] == 'fall' ? ' · cek jatuh' : ''}',
                              style: TText.h3.copyWith(fontSize: 15),
                            ),
                            subtitle: Text(s['summary'] as String? ?? _statusText(s), style: TText.small),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _statusText(Json s) => switch (s['status']) {
    'no_answer' => 'Tidak diangkat',
    'ringing' => 'Berdering…',
    'in_progress' => 'Sedang berlangsung…',
    _ => s['outcome']?.toString() ?? '',
  };
}
