import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'emergency.dart';

/// Aplikasi keluarga (anak) dan Sahabat Tilik. Di produksi kanal utamanya WhatsApp; di prototype,
/// pesan "WA" dan panggilan konferensi disimulasikan di sini (kanal *_sim dari server).
class ContactHome extends StatefulWidget {
  const ContactHome({super.key, required this.contactId});
  final String contactId;
  @override
  State<ContactHome> createState() => _ContactHomeState();
}

class _ContactHomeState extends State<ContactHome> with Poller<ContactHome> {
  Json? _feed;
  int _tab = 0;
  final Set<String> _shownCalls = {};
  final _msg = TextEditingController();

  bool get _isChild => _feed?['contact']?['role'] == 'child';

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  Future<void> poll() async {
    final f = await Api.instance.contactFeed(widget.contactId);
    if (!mounted) return;
    setState(() => _feed = f);
    final call = f['incoming_call'] as Json?;
    if (call != null && _shownCalls.add(call['id'] as String)) {
      // Panggilan darurat masuk → layar penuh, seperti telepon sungguhan.
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => EmergencyCall(notification: call, contact: f['contact'] as Json, patient: f['patient'] as Json),
        ),
      );
      refreshNow();
    }
  }

  Future<void> _callPatient() async {
    final phone = _feed?['patient']?['phone'] as String?;
    if (phone == null) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone)).catchError((_) => false);
    if (!ok && mounted) showError(context, 'Tidak bisa membuka aplikasi telepon. (Nomor demo fiktif: $phone)');
  }

  Future<void> _sendMessage() async {
    final text = _msg.text.trim();
    final f = _feed;
    if (text.isEmpty || f == null) return;
    try {
      await Api.instance.sendFamilyMessage(f['patient']['id'] as String, widget.contactId, text);
      _msg.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pesan dititipkan. TILIK akan membacakannya di panggilan berikutnya.')));
      }
      refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _feed;
    final contact = f?['contact'] as Json?;
    final unread = ((f?['notifications'] as List?) ?? const []).where((n) => n['read_at'] == null).length;
    final tabs = [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
      NavigationDestination(
        icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_outlined)),
        selectedIcon: const Icon(Icons.chat_rounded),
        label: 'Pesan TILIK',
      ),
      if (_isChild)
        const NavigationDestination(
          icon: Icon(Icons.edit_note_outlined),
          selectedIcon: Icon(Icons.edit_note_rounded),
          label: 'Titip pesan',
        ),
    ];
    if (_tab >= tabs.length) _tab = 0;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact?['name'] as String? ?? '…', style: TText.h2),
            if (contact != null)
              Text(
                _isChild ? 'Keluarga · ${f!['patient']['display_name']}' : 'Sahabat Tilik · ${f!['patient']['display_name']}',
                style: TText.small,
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: tabs),
      body: f == null
          ? (pollError != null ? ErrorBanner(pollError!, onRetry: refreshNow) : const Center(child: CircularProgressIndicator()))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    if (pollError != null) ErrorBanner(pollError!),
                    if (f['red_alert'] != null) _redBanner(f['red_alert'] as Json),
                    Expanded(
                      child: switch (_tab) {
                        0 => _isChild ? _homeChild(f) : _homeSahabat(f),
                        1 => _inbox(f),
                        _ => _compose(f),
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _redBanner(Json alert) {
    return Material(
      color: TColors.red,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmergencyDetail(alertId: alert['id'] as String, contactId: widget.contactId, isChild: _isChild),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.emergency_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DARURAT · ${alert['patient']['display_name']}', style: TText.h3.copyWith(color: Colors.white)),
                    Text(
                      alert['golden_period_deadline'] != null
                          ? 'Terakhir normal ${hm(alert['last_known_well'] as String?)} · ketuk untuk langkah-langkah'
                          : 'Skrining berjalan · ketuk untuk langkah-langkah',
                      style: TText.small.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (alert['golden_period_deadline'] != null)
                CountdownText(alert['golden_period_deadline'] as String?, style: TText.h3.copyWith(color: Colors.white)),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patientHeader(Json f) {
    final p = f['patient'] as Json;
    final today = f['today'] as Json?;
    final status = today == null
        ? 'scheduled'
        : (today['status'] == 'completed'
              ? (today['final_level'] ?? 'green')
              : today['status'] == 'no_answer'
              ? 'no_answer'
              : 'in_progress');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: TColors.brandTint,
              child: Text((p['display_name'] as String).split(' ').last[0], style: TText.h2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['display_name'] as String, style: TText.h2),
                  Text('${p['age']} th · ${p['village']}', style: TText.small),
                  Text('Ditelepon TILIK setiap pukul ${p['call_time_local']}', style: TText.small),
                ],
              ),
            ),
            LevelChip(status as String),
          ],
        ),
      ),
    );
  }

  Widget _homeChild(Json f) {
    final report = f['latest_report'] as Json?;
    final payload = (report?['payload'] as Json?) ?? const {};
    final points = ((payload['talking_points'] as List?) ?? const []).cast<String>();
    final bp = payload['bp'] as Json?;
    final adh = f['adherence_7d'] as Json;
    final name = (f['patient']['display_name'] as String);
    return RefreshIndicator(
      onRefresh: refreshNow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _patientHeader(f),
          const SectionTitle('Rapor pagi'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: report == null
                  ? Text('Belum ada rapor.', style: TText.small)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(dayLabel(report['created_at'] as String?), style: TText.h3)),
                            Text(hm(report['created_at'] as String?), style: TText.small),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _stat(
                                Icons.medication_rounded,
                                'Obat',
                                payload['medication'] == 'sudah'
                                    ? 'Sudah diminum'
                                    : payload['medication'] == null
                                    ? '–'
                                    : 'Belum diminum',
                              ),
                            ),
                            Expanded(
                              child: _stat(Icons.favorite_rounded, 'Tensi', bp == null ? '–' : '${bp['systolic']}/${bp['diastolic']}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LevelChip(
                          payload['level'] as String? ?? 'green',
                          text: payload['level'] == 'yellow' ? 'Perlu tindak lanjut Puskesmas' : 'Tidak ada tanda bahaya',
                        ),
                      ],
                    ),
            ),
          ),
          const SectionTitle('Bahan obrolan'),
          Card(
            color: TColors.brandTint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forum_rounded, color: TColors.brandDeep),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Tadi $name cerita…', style: TText.h3.copyWith(color: TColors.brandDeep)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (points.isEmpty) Text('Belum ada cerita hari ini.', style: TText.body),
                  for (final p in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('“$p”', style: TText.body.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _callPatient,
                    icon: const Icon(Icons.call_rounded),
                    label: Text('Telepon $name sekarang'),
                  ),
                  const SizedBox(height: 6),
                  Text('TILIK menemani setiap pagi, tapi suara anak tetap yang paling ditunggu.', style: TText.small),
                ],
              ),
            ),
          ),
          const SectionTitle('Tensi 7 hari'),
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: BpChart(f['bp_history'] as List)),
          ),
          SectionTitle('Minum obat 7 hari', trailing: Text('${adh['taken']}/${adh['total']}', style: TText.h3)),
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: AdherenceRow(adh['days'] as List)),
          ),
          const SizedBox(height: 16),
          const Center(child: DemoBadge()),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: TColors.bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: TColors.clay, size: 22),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TText.small),
            Text(value, style: TText.h3),
          ],
        ),
      ),
    ],
  );

  Widget _homeSahabat(Json f) {
    final name = f['patient']['display_name'] as String;
    const steps = [
      (Icons.directions_walk_rounded, 'Datangi rumah segera', 'Anda tetangga terdekat, menit pertama paling berharga.'),
      (Icons.event_seat_rounded, 'Temani dan posisikan aman', 'Duduk atau berbaring miring. Jangan ditinggal sendirian.'),
      (Icons.no_food_rounded, 'Jangan beri makan, minum, atau obat', 'Risiko tersedak bila ada gangguan menelan.'),
      (Icons.schedule_rounded, 'Catat jam terakhir normal', 'Informasi ini menentukan terapi di IGD.'),
      (Icons.local_hospital_rounded, 'Hubungi 119 / ambulans desa', 'Bawa ke RS dengan CT yang disebut TILIK.'),
    ];
    return RefreshIndicator(
      onRefresh: refreshNow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _patientHeader(f),
          const SectionTitle('Peran Anda'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Anda adalah Sahabat Tilik untuk $name: orang pertama yang ditelepon TILIK saat ada tanda bahaya, '
                'karena paling dekat secara fisik. Anda tidak menerima rapor harian, hanya panggilan darurat.',
                style: TText.body,
              ),
            ),
          ),
          const SectionTitle('Kalau TILIK menelepon darurat'),
          Card(
            child: Column(
              children: [
                for (final (i, s) in steps.indexed)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: TColors.brandTint,
                      child: Text('${i + 1}', style: TText.h3),
                    ),
                    title: Text(s.$2, style: TText.h3),
                    subtitle: Text(s.$3, style: TText.small),
                    trailing: Icon(s.$1, color: TColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: DemoBadge()),
        ],
      ),
    );
  }

  Widget _inbox(Json f) {
    final notes = ((f['notifications'] as List?) ?? const []).cast<Json>();
    if (notes.isEmpty) return Center(child: Text('Belum ada pesan dari TILIK.', style: TText.small));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: notes.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Text('Pesan WhatsApp dari TILIK (disimulasikan di aplikasi ini).', style: TText.small, textAlign: TextAlign.center);
        }
        final n = notes[i - 1];
        final red = (n['kind'] as String).startsWith('red');
        final unread = n['read_at'] == null;
        final call = n['channel'] == 'call_sim';
        return Card(
          color: red ? TColors.redTint : TColors.panel,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              if (unread) await Api.instance.notificationAction(n['id'] as String, 'read').catchError((_) => <String, dynamic>{});
              if (red && n['alert_id'] != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmergencyDetail(alertId: n['alert_id'] as String, contactId: widget.contactId, isChild: _isChild),
                  ),
                );
              }
              refreshNow();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(call ? Icons.phone_callback_rounded : Icons.chat_bubble_rounded, color: red ? TColors.red : TColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(n['title'] as String, style: TText.h3.copyWith(fontSize: 15.5))),
                            if (unread)
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(color: TColors.clay, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(n['body'] as String, style: TText.body.copyWith(fontSize: 14.5)),
                        const SizedBox(height: 6),
                        Text(
                          '${dayLabel(n['created_at'] as String?)} · ${hm(n['created_at'] as String?)}${call ? ' · ${n['status']}' : ''}',
                          style: TText.small.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compose(Json f) {
    final name = f['patient']['display_name'] as String;
    final sent = ((f['pending_messages'] as List?) ?? const []).cast<Json>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Titip pesan untuk $name', style: TText.h2),
        const SizedBox(height: 6),
        Text(
          'TILIK membacakannya di telepon pagi berikutnya, diawali "${f['contact']['name']} titip pesan…". '
          'Pesan suara asli (tanpa tiruan suara) menyusul di versi pipeline telepon.',
          style: TText.small,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _msg,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(hintText: 'Mis. "Bu, Sabtu Dika pulang. Jaga kesehatan, ya."'),
        ),
        FilledButton.icon(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded), label: const Text('Titipkan')),
        const SectionTitle('Pesan terakhir'),
        if (sent.isEmpty) Text('Belum ada.', style: TText.small),
        for (final m in sent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(m['text'] as String, style: TText.body),
                subtitle: Text('${dayLabel(m['created_at'] as String?)} · ${hm(m['created_at'] as String?)}', style: TText.small),
                trailing: LevelChip(
                  m['status'] == 'delivered' ? 'green' : 'scheduled',
                  text: m['status'] == 'delivered' ? 'Tersampaikan' : 'Menunggu telepon',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
