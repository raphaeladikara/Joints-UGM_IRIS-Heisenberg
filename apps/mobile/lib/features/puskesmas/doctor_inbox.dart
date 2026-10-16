import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Panggilan masuk dari wali untuk dokter jaga (simulasi telekonsultasi). Tampil di atas Daftar Kring.
class DoctorInbox extends StatefulWidget {
  const DoctorInbox({super.key});
  @override
  State<DoctorInbox> createState() => _DoctorInboxState();
}

class _DoctorInboxState extends State<DoctorInbox> with Poller<DoctorInbox> {
  List<Json> _items = const [];

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 2));
  }

  @override
  Future<void> poll() async {
    final l = (await Api.instance.activeConsults()).cast<Json>();
    if (mounted) setState(() => _items = l);
  }

  Future<void> _set(Json c, String status) async {
    var note = '';
    if (status == 'ended') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Catatan untuk keluarga'),
          content: TextField(controller: ctrl, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'Mis. cek tensi ulang sore ini')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text;
    }
    try {
      await Api.instance.setConsultStatus(c['id'] as String, status, note: note);
      refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Panggilan untuk dokter jaga'),
        for (final c in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(22), boxShadow: TShadow.soft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(c['mode'] == 'video' ? Icons.videocam_rounded : Icons.call_rounded, color: TColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${c['requested_by']} · untuk ${c['patient_name']} (${c['patient_age']} th)', style: TText.h3),
                    ),
                    LevelChip(c['level'] as String?),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${c['reason']}', style: TText.small.copyWith(color: TColors.ink)),
                const SizedBox(height: 12),
                if (c['status'] == 'ringing')
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _set(c, 'declined'), child: const Text('Sibuk'))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: TColors.green),
                          onPressed: () => _set(c, 'in_call'),
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Terima'),
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _set(c, 'ended'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Selesai + catatan'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
