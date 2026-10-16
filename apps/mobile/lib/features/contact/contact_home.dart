import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/health_widgets.dart';
import '../../core/mascot.dart';
import '../../core/pipo.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'doctor.dart';
import 'emergency.dart';
import 'care_views.dart';
import 'health_views.dart';
import 'kring_plus.dart';
import 'recipes.dart';

/// Aplikasi keluarga (anak) dan Sahabat Kring. Di produksi kanal utamanya WhatsApp; di prototype,
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
    if (_isChild) {
      Api.instance.logFamilyCall(_feed!['patient']['id'] as String, widget.contactId).then((_) => refreshNow()).catchError((_) => <String, dynamic>{});
    }
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
            .showSnackBar(const SnackBar(content: Text('Pesan dititipkan. KRING akan membacakannya di panggilan berikutnya.')));
      }
      refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _feed;
    final unread = ((f?['notifications'] as List?) ?? const []).where((n) => n['read_at'] == null).length;
    final hasCare = f?['care'] != null;
    final tabs = [
      const PillNavItem(Icons.home_rounded, 'Beranda'),
      if (_isChild) const PillNavItem(Icons.accessibility_new_rounded, 'Tubuh'),
      if (_isChild && hasCare) const PillNavItem(Icons.medication_rounded, 'Obat'),
      if (_isChild) const PillNavItem(Icons.restaurant_rounded, 'Menu'),
      PillNavItem(Icons.chat_rounded, 'Pesan', badge: unread),
    ];
    if (_tab >= tabs.length) _tab = 0;
    final page = tabs[_tab].label;
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: f == null ? null : PillNav(items: tabs, index: _tab, onTap: (i) => setState(() => _tab = i)),
      body: SafeArea(
        bottom: false,
        child: f == null
            ? (pollError != null ? ErrorBanner(pollError!, onRetry: refreshNow) : const Center(child: CircularProgressIndicator()))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      _topBar(f),
                      if (pollError != null) ErrorBanner(pollError!),
                      if (f['red_alert'] != null) _redBanner(f['red_alert'] as Json),
                      Expanded(
                        child: switch (page) {
                          'Beranda' => _isChild ? _homeChild(f) : _homeSahabat(f),
                          'Tubuh' => BodyView(f, onSynced: refreshNow),
                          'Obat' => MedsView(feed: f, onChanged: refreshNow),
                          'Menu' => RecipesView(feed: f, contactId: widget.contactId, onSent: refreshNow),
                          _ => _inbox(f),
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Sapaan + tombol kembali, menggantikan AppBar polos.
  Widget _topBar(Json f) {
    final contact = f['contact'] as Json;
    final h = toWib(DateTime.now()).hour;
    final greet = h < 11 ? 'Selamat pagi' : (h < 15 ? 'Selamat siang' : (h < 18 ? 'Selamat sore' : 'Selamat malam'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            style: IconButton.styleFrom(backgroundColor: TColors.panel),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greet, style: TText.small),
                Text('${contact['name']}', style: TText.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(99), border: Border.all(color: TColors.line)),
            child: Text(_isChild ? 'Keluarga' : 'Sahabat Kring', style: TText.small.copyWith(color: TColors.ink, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _redBanner(Json alert) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: TColors.red,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmergencyDetail(alertId: alert['id'] as String, contactId: widget.contactId, isChild: _isChild),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 12),
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
      ),
    );
  }

  String _status(Json f) {
    final today = f['today'] as Json?;
    if (today == null) return 'scheduled';
    if (today['status'] == 'completed') return (today['final_level'] as String?) ?? 'green';
    return today['status'] == 'no_answer' ? 'no_answer' : 'in_progress';
  }

  /// Kartu utama: siapa yang dijaga, status hari ini, dan tombol telepon (aksi yang paling diharapkan dari anak).
  Widget _patientHero(Json f, {bool callButton = true}) {
    final p = f['patient'] as Json;
    final name = p['display_name'] as String;
    final status = _status(f);
    final s = LevelStyle.of(status);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: TShadow.soft),
      child: PipoBackground(
        borderRadius: BorderRadius.circular(30),
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tili(mood: moodForLevel(status), size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TText.h1),
                    Text('${p['age']} tahun · ${p['village']}', style: TText.small.copyWith(color: TColors.ink.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Icon(s.icon, color: s.fg, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hari ini: ${s.label}', style: TText.h3.copyWith(color: s.fg == TColors.grey ? TColors.ink : s.fg)),
                      Text('KRING menelepon setiap pukul ${p['call_time_local']}', style: TText.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (callButton) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: TColors.night, minimumSize: const Size.fromHeight(58)),
              onPressed: _callPatient,
              icon: const Icon(Icons.call_rounded),
              label: Text('Telepon $name sekarang'),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _homeChild(Json f) {
    final report = f['latest_report'] as Json?;
    final payload = (report?['payload'] as Json?) ?? const {};
    final points = ((payload['talking_points'] as List?) ?? const []).cast<String>();
    final adh = f['adherence_7d'] as Json;
    final name = (f['patient']['display_name'] as String);
    final vitals = f['vitals'] as Json?;
    final connected = vitals?['connected'] == true;
    return RefreshIndicator(
      onRefresh: refreshNow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          if (f['care'] != null) ...[
            StreakBar(f['care'] as Json, onTap: _openReport),
            const SizedBox(height: 12),
          ],
          _patientHero(f),
          const SizedBox(height: 14),
          if (f['no_answer'] != null && f['no_answer']['stage'] != 'answered') ...[
            NoAnswerCard(feed: f, contactId: widget.contactId, onChanged: refreshNow),
            const SizedBox(height: 14),
          ],
          if (f['care'] != null) ...[
            SummaryCard(f),
            const SizedBox(height: 14),
          ],
          DoctorCard(feed: f, contactId: widget.contactId, onChanged: refreshNow),
          const SizedBox(height: 14),
          // Bahan obrolan: alasan anak menelepon, letaknya di atas angka-angka.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: TColors.butter, borderRadius: BorderRadius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: TColors.butterInk, size: 26),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Tadi $name cerita…', style: TText.h3)),
                    if (report != null) Text(hm(report['created_at'] as String?), style: TText.small.copyWith(color: TColors.butterInk)),
                  ],
                ),
                const SizedBox(height: 10),
                if (points.isEmpty) Text('Belum ada cerita hari ini.', style: TText.body),
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('“$p”', style: TText.body.copyWith(fontSize: 18, fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 6),
                Text('Tanyakan ini saat menelepon. Suara anak tetap yang paling ditunggu.', style: TText.small.copyWith(color: TColors.butterInk)),
              ],
            ),
          ),
          if (f['care']?['mood'] != null) ...[
            const SizedBox(height: 14),
            MoodCard(mood: f['care']['mood'] as Json, name: name, onCall: _callPatient),
          ],
          if (f['care']?['schedule'] != null) ...[
            const SizedBox(height: 22),
            _heading('Jadwal kontrol & ambil obat'),
            ScheduleCard(feed: f, onChanged: refreshNow),
          ],
          if (f['care'] != null) ...[
            const SizedBox(height: 22),
            _heading('Air & garam'),
            IntakeCard(feed: f, onChanged: refreshNow),
          ],
          const SizedBox(height: 22),
          _heading('Tensi & obat', trailing: f['care'] != null ? 'Rapor 30 hari' : null, onTrailing: _openReport),
          BpCard(f),
          const SizedBox(height: 12),
          HealthPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Tensi 7 hari', style: TText.h3)),
                    Text(
                      payload['medication'] == null ? '' : (payload['medication'] == 'sudah' ? 'Obat pagi: sudah' : 'Obat pagi: belum'),
                      style: TText.small.copyWith(color: payload['medication'] == 'sudah' ? TColors.green : TColors.yellow, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BpChart(f['bp_history'] as List),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Text('Minum obat 7 hari', style: TText.h3)),
                    Text('${adh['taken']}/${adh['total']}', style: TText.h3),
                  ],
                ),
                const SizedBox(height: 10),
                AdherenceRow(adh['days'] as List),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _heading('Dari jam tangan', trailing: connected ? 'Lihat tubuh' : null, onTrailing: () => setState(() => _tab = 1)),
          if (connected) ...[
            WatchTiles(vitals!),
            const SizedBox(height: 12),
            DailyRings(f),
            const SizedBox(height: 12),
          ],
          SyncCard(patientId: f['patient']['id'] as String, vitals: vitals, onSynced: refreshNow),
          const SizedBox(height: 18),
          const Center(child: DemoBadge()),
        ],
      ),
    );
  }

  void _openReport() {
    final p = _feed?['patient'] as Json?;
    if (p == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MonthlyReportPage(patientId: p['id'] as String, patientName: p['display_name'] as String)));
  }

  Widget _heading(String text, {String? trailing, VoidCallback? onTrailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: TText.h2)),
        if (trailing != null)
          TextButton.icon(onPressed: onTrailing, icon: const Icon(Icons.arrow_forward_rounded, size: 20), iconAlignment: IconAlignment.end, label: Text(trailing)),
      ],
    ),
  );

  Widget _homeSahabat(Json f) {
    final name = f['patient']['display_name'] as String;
    const steps = [
      (Icons.directions_walk_rounded, 'Datangi rumah segera', 'Anda tetangga terdekat, menit pertama paling berharga.'),
      (Icons.event_seat_rounded, 'Temani dan posisikan aman', 'Duduk atau berbaring miring. Jangan ditinggal sendirian.'),
      (Icons.no_food_rounded, 'Jangan beri makan, minum, atau obat', 'Risiko tersedak bila ada gangguan menelan.'),
      (Icons.schedule_rounded, 'Catat jam terakhir normal', 'Informasi ini menentukan terapi di IGD.'),
      (Icons.local_hospital_rounded, 'Hubungi 119 / ambulans desa', 'Bawa ke RS dengan CT yang disebut KRING.'),
    ];
    return RefreshIndicator(
      onRefresh: refreshNow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          if (f['no_answer'] != null && f['no_answer']['stage'] != 'answered') ...[
            NoAnswerCard(feed: f, contactId: widget.contactId, onChanged: refreshNow),
            const SizedBox(height: 14),
          ],
          _patientHero(f, callButton: false),
          if (f['care']?['schedule'] != null) ...[
            const SizedBox(height: 22),
            _heading('Jadwal posyandu & kontrol'),
            ScheduleCard(feed: f, onChanged: refreshNow),
          ],
          const SizedBox(height: 22),
          _heading('Peran Anda'),
          HealthPanel(
            child: Text(
              'Anda adalah Sahabat Kring untuk $name: orang pertama yang ditelepon KRING saat ada tanda bahaya, '
              'karena paling dekat secara fisik. Kalau telepon pagi dan telepon ulang 15 menit kemudian tidak diangkat, '
              'Anda diminta menengok ke rumah. Anda tidak menerima rapor harian.',
              style: TText.body,
            ),
          ),
          const SizedBox(height: 22),
          _heading('Kalau KRING menelepon darurat'),
          HealthPanel(
            child: Column(
              children: [
                for (final (i, s) in steps.indexed)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: TColors.brandTint, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: TText.h3.copyWith(color: TColors.brandDeep)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.$2, style: TText.h3),
                              const SizedBox(height: 2),
                              Text(s.$3, style: TText.small),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(s.$1, color: TColors.muted, size: 26),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Center(child: DemoBadge()),
        ],
      ),
    );
  }

  Widget _inbox(Json f) {
    final notes = ((f['notifications'] as List?) ?? const []).cast<Json>();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: notes.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pesan', style: TText.h1),
              Text('WhatsApp dari KRING, disimulasikan di aplikasi ini.', style: TText.small),
              if (_isChild) ...[const SizedBox(height: 14), _composeCard(f)],
              const SizedBox(height: 16),
              if (notes.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 20), child: TiliSays('Belum ada pesan. Nanti rapor pagi muncul di sini.', mood: TiliMood.sleepy)),
              if (notes.isNotEmpty) const Text('Kotak masuk', style: TText.h2),
            ],
          );
        }
        final n = notes[i - 1];
        final red = (n['kind'] as String).startsWith('red');
        final unread = n['read_at'] == null;
        final call = n['channel'] == 'call_sim';
        return Material(
          color: red ? TColors.redTint : TColors.panel,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
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
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: red ? Colors.white : TColors.brandTint, shape: BoxShape.circle),
                    child: Icon(call ? Icons.phone_callback_rounded : Icons.chat_bubble_rounded, color: red ? TColors.red : TColors.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(n['title'] as String, style: TText.h3)),
                            if (unread)
                              Container(
                                width: 11,
                                height: 11,
                                decoration: const BoxDecoration(color: TColors.clay, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(n['body'] as String, style: TText.body),
                        const SizedBox(height: 6),
                        Text(
                          '${dayLabel(n['created_at'] as String?)} · ${hm(n['created_at'] as String?)}${call ? ' · ${n['status']}' : ''}',
                          style: TText.small,
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

  Widget _composeCard(Json f) {
    final name = f['patient']['display_name'] as String;
    final sent = ((f['pending_messages'] as List?) ?? const []).cast<Json>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TColors.butter, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: TColors.butterInk, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text('Titip pesan untuk $name', style: TText.h3)),
            ],
          ),
          const SizedBox(height: 4),
          Text('KRING membacakannya di telepon pagi berikutnya, diawali "${f['contact']['name']} titip pesan…". '
              'Pesan suara diputar apa adanya, dengan suara Anda sendiri.',
              style: TText.small.copyWith(color: TColors.butterInk)),
          const SizedBox(height: 10),
          VoiceRecorder(patientId: f['patient']['id'] as String, contactId: widget.contactId, onSent: refreshNow),
          const SizedBox(height: 10),
          TextField(
            controller: _msg,
            maxLines: 3,
            maxLength: 300,
            style: TText.body,
            decoration: const InputDecoration(hintText: 'Mis. "Bu, Sabtu Dika pulang. Jaga kesehatan, ya."'),
          ),
          FilledButton.icon(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded), label: const Text('Titipkan')),
          for (final m in sent.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(m['kind'] == 'audio' ? '🎙️ Pesan suara ${m['duration_s'] ?? ''} detik' : '“${m['text']}”',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: TText.small.copyWith(color: TColors.ink)),
                  ),
                  const SizedBox(width: 8),
                  LevelChip(m['status'] == 'delivered' ? 'green' : 'scheduled', text: m['status'] == 'delivered' ? 'Tersampaikan' : 'Menunggu'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
