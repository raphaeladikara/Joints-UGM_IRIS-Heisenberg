import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../core/widgets.dart';

/// Panggilan darurat dari TILIK ke Sahabat Tilik / anak: briefing ≤ 15 detik lalu masuk konferensi.
/// Prototype: konferensi disimulasikan; di pipeline telepon ini Twilio `<Conference>`.
class EmergencyCall extends StatefulWidget {
  const EmergencyCall({super.key, required this.notification, required this.contact, required this.patient});
  final Json notification;
  final Json contact;
  final Json patient;
  @override
  State<EmergencyCall> createState() => _EmergencyCallState();
}

class _EmergencyCallState extends State<EmergencyCall> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  bool _joined = false;

  @override
  void dispose() {
    _pulse.dispose();
    Voice.instance.stop();
    super.dispose();
  }

  Future<void> _answer() async {
    await Api.instance.notificationAction(widget.notification['id'] as String, 'answer').catchError((_) => <String, dynamic>{});
    setState(() => _joined = true);
    await Voice.instance.speak(widget.notification['body'] as String);
  }

  Future<void> _decline() async {
    await Api.instance.notificationAction(widget.notification['id'] as String, 'decline').catchError((_) => <String, dynamic>{});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final patientName = widget.patient['display_name'] as String;
    final payload = (widget.notification['payload'] as Json?) ?? const {};
    final hospital = payload['hospital'] as Json?;
    return Scaffold(
      backgroundColor: const Color(0xFF2A0E10),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(padding: const EdgeInsets.all(24), child: _joined ? _conference(patientName, hospital) : _ringing(patientName)),
          ),
        ),
      ),
    );
  }

  Widget _ringing(String patientName) => Column(
    children: [
      const Spacer(),
      Text('Panggilan darurat', style: TText.body.copyWith(color: Colors.white70)),
      const SizedBox(height: 18),
      ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.1).animate(_pulse),
        child: Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(color: TColors.red, shape: BoxShape.circle),
          child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 60),
        ),
      ),
      const SizedBox(height: 22),
      Text('TILIK', style: TText.display.copyWith(color: Colors.white)),
      Text('Tanda bahaya: $patientName', style: TText.h3.copyWith(color: Colors.white)),
      const Spacer(),
      Row(
        children: [
          Expanded(child: _btn(Icons.call_end_rounded, TColors.grey, 'Tolak', _decline)),
          Expanded(child: _btn(Icons.call_rounded, TColors.green, 'Angkat', _answer)),
        ],
      ),
    ],
  );

  Widget _btn(IconData icon, Color color, String label, VoidCallback onTap) => Column(
    children: [
      Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 76, height: 76, child: Icon(icon, color: Colors.white, size: 34)),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: TText.body.copyWith(color: Colors.white)),
    ],
  );

  Widget _conference(String patientName, Json? hospital) {
    final me = widget.contact['name'] as String;
    final people = [
      (patientName, 'Pasien', Icons.elderly_rounded),
      if (widget.contact['role'] == 'sahabat_tilik')
        (me, 'Anda · Sahabat Tilik', Icons.volunteer_activism_rounded)
      else
        ('Sahabat Tilik', 'Tetangga', Icons.volunteer_activism_rounded),
      if (widget.contact['role'] == 'child')
        (me, 'Anda · Keluarga', Icons.family_restroom_rounded)
      else
        ('Keluarga', 'Anak', Icons.family_restroom_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Konferensi darurat (simulasi)', style: TText.small.copyWith(color: Colors.white70)),
        const SizedBox(height: 6),
        Text('Tersambung dengan $patientName', style: TText.h1.copyWith(color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Briefing TILIK', style: TText.label.copyWith(color: Colors.white60)),
              const SizedBox(height: 6),
              Text(widget.notification['body'] as String, style: TText.body.copyWith(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final p in people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(p.$3, color: Colors.white),
            ),
            title: Text(p.$1, style: TText.h3.copyWith(color: Colors.white)),
            subtitle: Text(p.$2, style: TText.small.copyWith(color: Colors.white60)),
            trailing: const Icon(Icons.graphic_eq_rounded, color: Colors.greenAccent),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Colors.white12,
            child: Icon(Icons.support_agent_rounded, color: Colors.white38),
          ),
          title: Text('TILIK', style: TText.h3.copyWith(color: Colors.white38)),
          subtitle: Text('Keluar setelah menyambungkan', style: TText.small.copyWith(color: Colors.white38)),
        ),
        if (hospital != null) ...[
          const SizedBox(height: 8),
          Text('RS ber-CT terdekat: ${hospital['name']}', style: TText.body.copyWith(color: Colors.white)),
        ],
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: TColors.red, minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.call_end_rounded),
          label: const Text('Tutup konferensi'),
        ),
      ],
    );
  }
}

/// Detail darurat untuk keluarga / Sahabat Tilik: hitung mundur golden period, RS tujuan, langkah.
class EmergencyDetail extends StatefulWidget {
  const EmergencyDetail({super.key, required this.alertId, required this.contactId, required this.isChild});
  final String alertId;
  final String contactId;
  final bool isChild;
  @override
  State<EmergencyDetail> createState() => _EmergencyDetailState();
}

class _EmergencyDetailState extends State<EmergencyDetail> with Poller<EmergencyDetail> {
  Json? _a;

  @override
  void initState() {
    super.initState();
    startPolling(const Duration(seconds: 3));
  }

  @override
  Future<void> poll() async {
    final a = await Api.instance.alert(widget.alertId);
    if (mounted) setState(() => _a = a);
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColors.red,
        foregroundColor: Colors.white,
        title: const Text('Darurat', style: TextStyle(color: Colors.white)),
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _golden(a),
                    const SectionTitle('Tanda yang terdeteksi'),
                    Card(
                      child: Column(
                        children: [
                          for (final r in (a['reasons'] as List))
                            ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: TColors.red),
                              title: Text(r['label'] as String, style: TText.h3),
                              subtitle: (r['quote'] as String?)?.isNotEmpty == true ? Text('“${r['quote']}”', style: TText.small) : null,
                            ),
                        ],
                      ),
                    ),
                    const SectionTitle('Bawa ke'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_hospital_rounded, color: TColors.leaf),
                        title: Text(a['hospital']?['name'] as String? ?? 'RS ber-CT terdekat', style: TText.h3),
                        subtitle: Text(
                          a['eta_minutes'] != null ? '±${a['eta_minutes']} menit perjalanan · CT 24 jam (simulasi, perlu verifikasi)' : '–',
                          style: TText.small,
                        ),
                      ),
                    ),
                    const SectionTitle('Langkah sekarang'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (i, s)
                                in (widget.isChild
                                        ? [
                                            'Tetap tersambung di konferensi dan tenangkan ${a['patient']['display_name']}.',
                                            'Putuskan bersama Sahabat Tilik: bawa ke ${a['hospital']?['name'] ?? 'RS ber-CT'} sekarang.',
                                            'Hubungi 119 / ambulans desa. Sebutkan jam terakhir normal.',
                                            'Bila memakai obat pengencer darah, sampaikan ke IGD.',
                                          ]
                                        : [
                                            'Datangi rumah ${a['patient']['display_name']} sekarang.',
                                            'Temani, posisikan duduk/berbaring miring. Jangan beri makan/minum.',
                                            'Hubungi 119 / ambulans desa, atau antar ke ${a['hospital']?['name'] ?? 'RS ber-CT'}.',
                                            'Bawa obat yang biasa diminum.',
                                          ])
                                    .indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: TColors.redTint,
                                      child: Text('${i + 1}', style: TText.small.copyWith(color: TColors.red)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(s, style: TText.body)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: TColors.red, minimumSize: const Size.fromHeight(50)),
                              onPressed: () => showError(
                                context,
                                'Mode demo: tombol ini tidak menelepon 119. Di lapangan, tombol membuka panggilan 119.',
                              ),
                              icon: const Icon(Icons.call_rounded),
                              label: const Text('Telepon 119'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      a['status'] == 'acknowledged'
                          ? '✓ IGD sudah menerima pre-alert (${a['acknowledged_by']}).'
                          : 'Pre-alert sudah tampil di Board IGD.',
                      style: TText.small,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Informasi, bukan keputusan terapi. Keputusan klinis tetap di tim IGD.',
                      style: TText.small,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _golden(Json a) {
    final deadline = a['golden_period_deadline'] as String?;
    return Card(
      color: TColors.redTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      value: deadline == null ? null : remainingFraction(deadline),
                      strokeWidth: 9,
                      backgroundColor: Colors.white,
                      color: TColors.red,
                    ),
                  ),
                  const Icon(Icons.timer_rounded, color: TColors.red, size: 30),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['patient']['display_name'] as String, style: TText.h2),
                  const SizedBox(height: 4),
                  Text(
                    deadline == null ? 'Jam terakhir normal: menunggu skrining' : 'Terakhir normal: ${hm(a['last_known_well'] as String?)}',
                    style: TText.body,
                  ),
                  if (deadline != null) ...[
                    Text('Sisa golden period (4,5 jam):', style: TText.small),
                    CountdownText(deadline, style: TText.h1.copyWith(color: TColors.red)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
