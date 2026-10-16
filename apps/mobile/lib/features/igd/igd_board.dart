import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// F-14 Board Pre-alert IGD: kartu realtime (polling) dengan jam onset, skrining, obat, ETA, kontak keluarga.
class IgdBoard extends StatefulWidget {
  const IgdBoard({super.key});
  @override
  State<IgdBoard> createState() => _IgdBoardState();
}

class _IgdBoardState extends State<IgdBoard> with Poller<IgdBoard> {
  List<Json>? _alerts;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  Future<void> poll() async {
    final all = (await Api.instance.alerts(level: 'red')).cast<Json>().where((a) => a['status'] != 'closed').toList();
    if (mounted) setState(() => _alerts = all);
  }

  Future<void> _ack(Json a) async {
    try {
      await Api.instance.ackAlert(a['id'] as String, 'Triase IGD RSUD Wonosari');
      refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _close(Json a) async {
    await Api.instance.closeAlert(a['id'] as String).catchError((_) => <String, dynamic>{});
    refreshNow();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    return Scaffold(
      backgroundColor: TColors.night,
      appBar: AppBar(
        backgroundColor: TColors.night,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Board Pre-alert IGD', style: TText.h2.copyWith(color: Colors.white)),
            Text('Jejaring Code Stroke (simulasi)', style: TText.small.copyWith(color: Colors.white54)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DemoBadge(dark: true)),
          ),
        ],
      ),
      body: alerts == null
          ? (pollError != null ? ErrorBanner(pollError!, onRetry: refreshNow) : const Center(child: CircularProgressIndicator()))
          : alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monitor_heart_outlined, color: Colors.white24, size: 64),
                  const SizedBox(height: 12),
                  Text('Tidak ada pre-alert aktif.', style: TText.h3.copyWith(color: Colors.white60)),
                  Text('Kartu muncul otomatis saat KRING mendeteksi tanda bahaya.', style: TText.small.copyWith(color: Colors.white38)),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [if (pollError != null) ErrorBanner(pollError!), for (final a in alerts) _card(a)],
                ),
              ),
            ),
    );
  }

  Widget _card(Json a) {
    final p = a['patient'] as Json;
    final screen = (a['screening'] as Json?) ?? const {};
    final deadline = a['golden_period_deadline'] as String?;
    final acked = a['status'] == 'acknowledged';
    final family = (a['contacts'] as List).cast<Json>().where((c) => c['role'] == 'child').firstOrNull;
    final reasons = (a['reasons'] as List).map((r) => r['label']).join(' · ');

    Widget kv(String k, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(k, style: TText.small.copyWith(color: Colors.white54)),
          ),
          Expanded(
            child: Text(v, style: TText.body.copyWith(color: color ?? Colors.white)),
          ),
        ],
      ),
    );

    String flag(Json? s) => s == null ? 'belum dinilai' : (s['abnormal'] == true ? 'ABNORMAL' : 'normal');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TColors.nightPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: acked ? TColors.nightLine : TColors.red, width: acked ? 1 : 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: acked ? TColors.nightLine : TColors.red,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PRE-ALERT · ${p['initials']} (${p['sex'] == 'F' ? 'P' : 'L'}, ${p['age']} th) · ${p['village']}',
                    style: TText.h3.copyWith(color: Colors.white),
                  ),
                ),
                Text(ago(a['created_at'] as String?), style: TText.small.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terakhir normal', style: TText.small.copyWith(color: Colors.white54)),
                          Text(
                            a['last_known_well'] != null ? hm(a['last_known_well'] as String?) : 'menunggu',
                            style: TText.h1.copyWith(fontSize: 24, color: Colors.white),
                          ),
                          if (a['lkw_note'] != null) Text('“${a['lkw_note']}”', style: TText.small.copyWith(color: Colors.white54)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sisa golden period', style: TText.small.copyWith(color: Colors.white54)),
                          deadline == null
                              ? Text('–', style: TText.h1.copyWith(fontSize: 24, color: Colors.white))
                              : CountdownText(deadline, style: TText.h1.copyWith(fontSize: 24, color: const Color(0xFFFF8A80))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ETA', style: TText.small.copyWith(color: Colors.white54)),
                          Text(
                            a['eta_minutes'] != null ? '±${a['eta_minutes']} mnt' : '–',
                            style: TText.h1.copyWith(fontSize: 24, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: TColors.nightLine),
                const SizedBox(height: 8),
                kv('Tanda', reasons, color: const Color(0xFFFFCDD2)),
                kv('Ulang kalimat', flag(screen['speech_repeat'] as Json?)),
                kv('Angkat 2 tangan', flag(screen['arm_drift'] as Json?)),
                kv('Obat', (p['medications'] as List).map((m) => m['name']).join(', ')),
                kv(
                  'Antikoagulan',
                  p['anticoagulant'] == true ? 'YA, perhatikan' : 'tidak (menurut profil)',
                  color: p['anticoagulant'] == true ? const Color(0xFFFFE082) : null,
                ),
                kv('RS tujuan', a['hospital']?['name'] as String? ?? '–'),
                kv('Keluarga', family == null ? '–' : '${family['name']} · ${family['phone']}'),
                kv('Sumber', a['source'] as String),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: acked
                          ? Text(
                              '✓ Diterima ${a['acknowledged_by']} · ${hm(a['acknowledged_at'] as String?)}',
                              style: TText.body.copyWith(color: Colors.greenAccent),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TColors.red),
                              onPressed: () => _ack(a),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Terima & siapkan tim'),
                            ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _close(a),
                      child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('PRE-ALERT · keputusan klinis tetap di tim IGD', style: TText.label.copyWith(color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
