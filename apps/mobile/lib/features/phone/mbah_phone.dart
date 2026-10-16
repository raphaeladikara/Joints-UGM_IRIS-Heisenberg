import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../core/widgets.dart';

enum _Phase { idle, ringing, inCall, ended }

/// Simulator "HP jadul" Mbah. Di produksi ini adalah panggilan PSTN biasa (Twilio + Pipecat);
/// di prototype, layar ini memutar suara TILIK (TTS) dan menerima jawaban lewat mikrofon, ketik, atau tombol.
class MbahPhone extends StatefulWidget {
  const MbahPhone({super.key, required this.patientId});
  final String patientId;
  @override
  State<MbahPhone> createState() => _MbahPhoneState();
}

class _Line {
  _Line(this.fromTilik, this.text);
  final bool fromTilik;
  final String text;
}

class _MbahPhoneState extends State<MbahPhone> with Poller<MbahPhone>, SingleTickerProviderStateMixin {
  final _api = Api.instance;
  final _voice = Voice.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  _Phase _phase = _Phase.idle;
  Json? _patient;
  String? _sid;
  String _trigger = 'daily';
  String _state = 'RINGING';
  String _stateLabel = '';
  String _level = 'green';
  String? _outcome;
  final List<_Line> _lines = [];
  bool _speaking = false;
  int _speakToken = 0;
  bool _listening = false;
  bool _sending = false;
  bool _autoListen = false;
  String _partial = '';
  bool _helpComing = false;
  bool _familyMsg = false;
  DateTime? _answeredAt;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _api.patient(widget.patientId).then((p) => mounted ? setState(() => _patient = p) : null).catchError((_) => null);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    startPolling(const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    _voice.stop();
    _voice.stopListening();
    super.dispose();
  }

  @override
  Future<void> poll() async {
    if (_phase != _Phase.idle) return;
    final r = await _api.incoming(widget.patientId);
    if (r['ringing'] == true && mounted && _phase == _Phase.idle) {
      final s = r['session'] as Json;
      setState(() {
        _phase = _Phase.ringing;
        _sid = s['id'] as String;
        _trigger = s['trigger'] as String? ?? 'daily';
      });
    }
  }

  Future<void> _requestCall() async {
    try {
      await _api.startCall(widget.patientId);
      await refreshNow();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _answer() async {
    final sid = _sid;
    if (sid == null) return;
    try {
      final r = await _api.answer(sid);
      setState(() {
        _phase = _Phase.inCall;
        _answeredAt = DateTime.now();
        _lines.clear();
        _helpComing = false;
        _familyMsg = false;
      });
      await _applyTurn(r);
    } catch (e) {
      if (mounted) showError(context, e);
      setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _decline() async {
    final sid = _sid;
    if (sid == null) return;
    try {
      final r = await _api.noAnswer(sid);
      setState(() {
        _phase = _Phase.ended;
        _outcome = 'no_answer';
        _level = r['level'] as String? ?? 'green';
        _helpComing = (r['hints'] as List?)?.contains('escalation_started') ?? false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _applyTurn(Json r) async {
    final text = (r['tilik_text'] as String?) ?? '';
    final hints = ((r['hints'] as List?) ?? const []).cast<String>();
    setState(() {
      if (text.isNotEmpty) _lines.add(_Line(true, text));
      _state = r['state'] as String? ?? _state;
      _stateLabel = r['state_label'] as String? ?? '';
      _level = r['level'] as String? ?? _level;
      if (hints.contains('escalation_started')) _helpComing = true;
      if (hints.contains('family_message')) _familyMsg = true;
      if (r['ended'] == true) _outcome = r['outcome'] as String?;
    });
    _scrollDown();
    if (text.isNotEmpty) {
      final token = ++_speakToken;
      setState(() => _speaking = true);
      await _voice.speak(text);
      // Pasien memotong (barge-in) → giliran baru sudah mulai, jangan lanjutkan alur lama.
      if (token != _speakToken || !mounted) return;
      setState(() => _speaking = false);
    }
    if (r['ended'] == true) {
      if (mounted) setState(() => _phase = _Phase.ended);
      return;
    }
    if (_autoListen && mounted) _listen();
  }

  Future<void> _send(String text) async {
    final sid = _sid;
    if (sid == null || text.trim().isEmpty || _sending) return;
    _speakToken++;
    await _voice.stop();
    setState(() {
      _speaking = false;
      _sending = true;
      _lines.add(_Line(false, text.trim()));
      _input.clear();
      _partial = '';
    });
    _scrollDown();
    try {
      final r = await _api.say(sid, text.trim());
      if (mounted) setState(() => _sending = false);
      // Suara TILIK diputar tanpa mengunci tombol: pasien boleh memotong kapan saja.
      unawaited(_applyTurn(r));
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showError(context, e);
      }
    }
  }

  Future<void> _listen() async {
    if (_listening) {
      await _voice.stopListening();
      return;
    }
    setState(() {
      _listening = true;
      _partial = '';
    });
    final text = await _voice.listenOnce(onPartial: (p) => mounted ? setState(() => _partial = p) : null);
    if (!mounted) return;
    setState(() => _listening = false);
    if (text.trim().isNotEmpty) {
      await _send(text);
    } else if (!_voice.sttAvailable) {
      showError(context, 'Mikrofon/pengenal suara tidak tersedia di perangkat ini. Pakai tombol jawaban atau ketik.');
    }
  }

  Future<void> _hangup() async {
    final sid = _sid;
    await _voice.stop();
    if (sid != null) {
      try {
        final r = await _api.hangup(sid);
        _outcome = r['outcome'] as String? ?? 'hung_up';
      } catch (_) {}
    }
    if (mounted) setState(() => _phase = _Phase.ended);
  }

  void _reset() {
    setState(() {
      _phase = _Phase.idle;
      _sid = null;
      _lines.clear();
      _outcome = null;
      _level = 'green';
      _helpComing = false;
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  List<String> _suggestions() {
    final last = _lines.where((l) => l.fromTilik).map((l) => l.text).lastOrNull ?? '';
    const stroke = 'Ngomongku kok angel, tangan kiwa lemes';
    if (_trigger == 'fall' && _state == 'GREETING') {
      return ['Saya baik-baik saja, cuma kepleset', 'Tolong, saya tidak bisa bangun'];
    }
    return switch (_state) {
      'GREETING' => ['Iya, saya sendiri', 'Inggih, leres', 'Bukan, saya cucunya', 'Niki tiyang napa robot?'],
      'MEDICATION' => ['Sampun, tadi habis sarapan', 'Belum, lupa', 'Belum, obatnya habis', stroke],
      'MED_REASON' => ['Lupa', 'Obatnya habis', 'Merasa sudah sehat'],
      'BLOOD_PRESSURE' => ['Seratus lima puluh per sembilan puluh', '184 per 104', 'Belum ngukur'],
      'BP_CONFIRM' => ['Iya betul', 'Bukan, seratus empat puluh per sembilan puluh'],
      'SYMPTOMS' => ['Tidak ada keluhan', 'Agak pusing sedikit', stroke, 'Dada saya nyeri seperti ditindih'],
      'STORY' => ['Tomatnya sudah panen, dibagi ke tetangga', 'Kangen sama Dika', 'Biasa saja'],
      'STROKE_SCREEN' when last.contains('ulangi kalimat') => ['Langit… biru… desa', 'Langit biru di atas desa'],
      'STROKE_SCREEN' when last.contains('kedua tangan') => ['Yang kiri turun, lemes', 'Tidak ada, kuat semua'],
      'STROKE_SCREEN' => ['Jam enam lewat empat puluh', 'Setengah tujuh', 'Waktu bangun tidur'],
      _ => const [],
    };
  }

  // ---------------- tampilan ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1513),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1513),
        foregroundColor: Colors.white,
        title: Text('HP ${_patient?['display_name'] ?? 'Mbah'}', style: TText.h2.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _voice.muted ? 'Suara TILIK mati' : 'Suara TILIK nyala',
            onPressed: () => setState(() => _voice.muted = !_voice.muted),
            icon: Icon(_voice.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: switch (_phase) {
              _Phase.idle => _idle(),
              _Phase.ringing => _ringing(),
              _Phase.inCall => _inCall(),
              _Phase.ended => _ended(),
            },
          ),
        ),
      ),
    );
  }

  Widget _idle() {
    final now = toWib(DateTime.now());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text(
            '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontFamily: 'Jakarta', fontSize: 72, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          Text(dayLabel(DateTime.now().toIso8601String()), style: TText.body.copyWith(color: Colors.white70)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Icon(Icons.phone_android_rounded, color: Colors.white54, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Telepon biasa, tanpa aplikasi & internet.',
                  style: TText.body.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Menunggu TILIK menelepon (dijadwalkan ${_patient?['call_time_local'] ?? '07.00'} atau tombol "Tilik sekarang" di Puskesmas).',
                  style: TText.small.copyWith(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (pollError != null) ...[const SizedBox(height: 12), Text(pollError!, style: TText.small.copyWith(color: Colors.orangeAccent))],
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: TColors.clay, minimumSize: const Size.fromHeight(54)),
            onPressed: _requestCall,
            icon: const Icon(Icons.ring_volume_rounded),
            label: const Text('Demo: minta TILIK menelepon sekarang'),
          ),
          const SizedBox(height: 10),
          Text(
            'Simulator ini hanya untuk demo. Di lapangan, Mbah cukup mengangkat HP biasanya.',
            style: TText.small.copyWith(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ringing() {
    final fall = _trigger == 'fall';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text(fall ? 'Panggilan cek jatuh' : 'Panggilan masuk', style: TText.body.copyWith(color: Colors.white60)),
          const SizedBox(height: 18),
          ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: TColors.brand,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: TColors.brand.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 6)],
              ),
              child: const Icon(Icons.phone_in_talk_rounded, size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: 22),
          Text('TILIK', style: TText.display.copyWith(color: Colors.white)),
          Text('Puskesmas · asisten AI', style: TText.body.copyWith(color: Colors.white70)),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _roundAction(Icons.call_end_rounded, TColors.red, 'Tidak diangkat', _decline)),
              Expanded(child: _roundAction(Icons.call_rounded, TColors.green, 'Angkat', _answer)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _roundAction(IconData icon, Color color, String label, VoidCallback onTap) => Column(
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

  Widget _inCall() {
    final dur = _answeredAt == null ? Duration.zero : DateTime.now().difference(_answeredAt!);
    final mm = dur.inMinutes.toString().padLeft(2, '0');
    final ss = (dur.inSeconds % 60).toString().padLeft(2, '0');
    final suggestions = _suggestions();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: TColors.brand,
                child: Icon(Icons.support_agent_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TILIK · $mm:$ss', style: TText.h3.copyWith(color: Colors.white)),
                    Text(_stateLabel, style: TText.small.copyWith(color: Colors.white60)),
                  ],
                ),
              ),
              LevelChip(_level),
            ],
          ),
        ),
        if (_helpComing)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: TColors.red, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.emergency_share_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bantuan sedang dihubungi: Sahabat Tilik, keluarga, dan pre-alert IGD.',
                    style: TText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        if (_familyMsg && !_helpComing)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.mark_chat_read_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Titip pesan keluarga dibacakan.', style: TText.small.copyWith(color: Colors.white70)),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [for (final l in _lines) _bubble(l), if (_listening && _partial.isNotEmpty) _bubble(_Line(false, '$_partial…'))],
          ),
        ),
        if (suggestions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF223029),
                      disabledColor: const Color(0xFF223029),
                      side: const BorderSide(color: Color(0xFF34443C)),
                      label: Text(s, style: TText.small.copyWith(color: Colors.white)),
                      onPressed: _sending ? null : () => _send(s),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: TText.body,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: _listening ? 'Mendengarkan…' : 'Ketik jawaban Mbah…',
                    isDense: true,
                    suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), onPressed: () => _send(_input.text)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _listening ? TColors.clay : const Color(0xFF223029),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : _listen,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: TColors.red,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _hangup,
                  child: const SizedBox(width: 52, height: 52, child: Icon(Icons.call_end_rounded, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_speaking) ...[
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                const SizedBox(width: 8),
                Text('TILIK sedang bicara', style: TText.small.copyWith(color: Colors.white54)),
                const SizedBox(width: 16),
              ],
              Text('Dengar otomatis', style: TText.small.copyWith(color: Colors.white54)),
              Switch(value: _autoListen, onChanged: (v) => setState(() => _autoListen = v)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(_Line l) {
    return Align(
      alignment: l.fromTilik ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: l.fromTilik ? const Color(0xFF1F2D27) : TColors.brand,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(l.fromTilik ? 4 : 16),
            bottomRight: Radius.circular(l.fromTilik ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.fromTilik ? 'TILIK' : (_patient?['display_name'] as String? ?? 'Mbah'),
              style: TText.label.copyWith(color: Colors.white54, fontSize: 10.5),
            ),
            const SizedBox(height: 2),
            Text(l.text, style: TText.body.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _ended() {
    final s = LevelStyle.of(_level);
    final (title, desc) = switch (_outcome) {
      'escalated' => (
        'Disambungkan ke konferensi',
        'TILIK menyambungkan Mbah dengan Sahabat Tilik dan keluarga. Pre-alert sudah ada di Board IGD.',
      ),
      'no_answer' => (
        'Panggilan tidak diangkat',
        _helpComing
            ? 'Jam tangan mendeteksi jatuh dan tidak ada jawaban: TILIK langsung mengeskalasi ke Sahabat Tilik, keluarga, dan IGD.'
            : 'Tercatat. Dua kali berturut-turut → masuk daftar tindak lanjut Puskesmas.',
      ),
      'wrong_person' => ('Bukan Mbah yang mengangkat', 'TILIK tidak menyebut data medis apa pun dan akan menelepon lagi nanti.'),
      'hung_up' => ('Panggilan diakhiri', 'Data yang sudah terkumpul tetap tersimpan.'),
      _ => ('Panggilan selesai', 'Rapor dan bahan obrolan sudah dikirim ke keluarga. Daftar Tilik Puskesmas ter-update.'),
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(_outcome == 'escalated' ? Icons.groups_rounded : Icons.call_end_rounded, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            title,
            style: TText.h1.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TText.body.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          LevelChip(_level, big: true, text: 'Hasil: ${s.label}'),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _reset,
            child: const Text('Kembali ke layar HP'),
          ),
        ],
      ),
    );
  }
}
