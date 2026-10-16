import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Transkrip + jejak keputusan satu panggilan (setiap warna punya jalur pemicu, kutipan, waktu). Kata sandi disamarkan.
class CallTranscript extends StatefulWidget {
  const CallTranscript({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<CallTranscript> createState() => _CallTranscriptState();
}

class _CallTranscriptState extends State<CallTranscript> with Poller<CallTranscript> {
  Json? _c;

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 2));
  }

  @override
  Future<void> poll() async {
    final c = await Api.instance.call(widget.sessionId);
    if (mounted) setState(() => _c = c);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: const Text('Panggilan')),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${c['patient']['display_name']} · ${hm(c['started_at'] as String?)}', style: TText.h2)),
                        LevelChip(c['level'] as String?),
                      ],
                    ),
                    Text('Status: ${c['status']} · state: ${c['state_label']}', style: TText.small),
                    if (c['summary'] != null) ...[
                      const SectionTitle('Ringkasan untuk nakes'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(c['summary'] as String, style: TText.body),
                        ),
                      ),
                    ],
                    if ((c['findings'] as List).isNotEmpty) ...[
                      const SectionTitle('Jejak keputusan'),
                      Card(
                        child: Column(
                          children: [
                            for (final f in (c['findings'] as List))
                              ListTile(
                                leading: LevelChip(f['level'] as String?, text: f['path'] == 'llm' ? 'LLM' : 'Aturan'),
                                title: Text('${f['label']} (${f['code']})', style: TText.h3.copyWith(fontSize: 15)),
                                subtitle: Text('“${f['quote']}”', style: TText.small),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SectionTitle('Transkrip'),
                    if ((c['turns'] as List).isEmpty) Text('Tidak ada transkrip (data riwayat seed).', style: TText.small),
                    for (final t in (c['turns'] as List))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                t['speaker'] == 'tilik' ? 'KRING' : 'Pasien',
                                style: TText.label.copyWith(color: t['speaker'] == 'tilik' ? TColors.brand : TColors.clay),
                              ),
                            ),
                            Expanded(child: Text(t['text'] as String, style: TText.body.copyWith(fontSize: 14.5))),
                            Text(hm(t['ts'] as String?), style: TText.small.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
