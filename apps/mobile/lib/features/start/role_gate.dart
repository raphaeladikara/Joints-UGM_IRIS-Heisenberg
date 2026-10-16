import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/mascot.dart';
import '../../core/pipo.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../contact/contact_home.dart';
import '../igd/igd_board.dart';
import '../phone/mbah_phone.dart';
import '../puskesmas/daftar_tilik.dart';

/// Pilih peran. Satu APK untuk demo: HP Mbah (simulator telepon biasa), keluarga, Sahabat Kring, Puskesmas, IGD.
/// Di produksi, Mbah tidak butuh aplikasi apa pun: KRING menelepon nomor HP biasa.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});
  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  Json? _health;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final h = await Api.instance.health();
      if (mounted) setState(() => (_health = h, _error = null));
    } catch (e) {
      if (mounted) setState(() => (_health = null, _error = e.toString()));
    }
  }

  void _open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _pickContact(String role) async {
    try {
      final all = (await Api.instance.contacts()).cast<Json>().where((c) => c['role'] == role).toList();
      if (!mounted) return;
      final picked = await showModalBottomSheet<Json>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          shrinkWrap: true,
          children: [
            for (final c in all)
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text('${c['name']}', style: TText.h3),
                subtitle: Text('${c['relation']} · untuk ${c['patient_name']}', style: TText.small),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      );
      if (picked != null) _open(ContactHome(contactId: picked['id'] as String));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _settings() async {
    final ctrl = TextEditingController(text: Api.instance.isOffline ? '' : Api.instance.base);
    var offline = Api.instance.isOffline;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Sumber data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, icon: Icon(Icons.phone_android_rounded), label: Text('Offline')),
                  ButtonSegment(value: false, icon: Icon(Icons.dns_rounded), label: Text('Server')),
                ],
                selected: {offline},
                onSelectionChanged: (v) => setLocal(() => offline = v.first),
              ),
              const SizedBox(height: 12),
              if (offline)
                Text('Semua data demo disimpan di HP ini. Tidak butuh internet atau laptop.', style: TText.small)
              else ...[
                TextField(controller: ctrl, decoration: InputDecoration(hintText: Api.serverHint)),
                const SizedBox(height: 8),
                Text('Server KRING (FastAPI) untuk LLM dan suara asli. HP dan laptop harus satu Wi-Fi.', style: TText.small),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (saved == true) {
      await Api.instance.setBase(offline ? Api.offline : (ctrl.text.trim().isEmpty ? Api.serverHint : ctrl.text));
      _check();
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ulang data demo?'),
        content: const Text('Semua panggilan, alert, dan pesan kembali ke kondisi awal (data fiktif).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ulang')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.resetDemo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data demo sudah diulang.')));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Image.asset('assets/kring_icon_512.png', width: 48, height: 48, semanticLabel: 'Logo KRING'),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('KRING', style: TText.h1)),
                    IconButton(
                      onPressed: _settings,
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: 'Alamat server',
                      style: IconButton.styleFrom(backgroundColor: TColors.panel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _hero(),
                const SizedBox(height: 10),
                _serverStatus(),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text('Masuk sebagai', style: TText.h2),
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth >= 300 ? 2 : 1;
                    final w = (box.maxWidth - 12 * (cols - 1)) / cols;
                    final tiles = [
                      _RoleTile(
                        icon: Icons.phone_android_rounded,
                        color: TColors.peach,
                        ink: TColors.peachInk,
                        title: 'HP Mbah',
                        who: 'Bu Sri',
                        subtitle: 'KRING menelepon, Mbah menjawab dengan suara.',
                        onTap: () => _open(const MbahPhone(patientId: 'p-sri')),
                      ),
                      _RoleTile(
                        icon: Icons.family_restroom_rounded,
                        color: TColors.sky,
                        ink: TColors.skyInk,
                        title: 'Keluarga',
                        who: 'Mas Dika',
                        subtitle: 'Rapor pagi, jam tangan, tubuh 3D, titip pesan.',
                        onTap: () => _open(const ContactHome(contactId: 'c-dika')),
                        onLongPress: () => _pickContact('child'),
                      ),
                      _RoleTile(
                        icon: Icons.volunteer_activism_rounded,
                        color: TColors.lavender,
                        ink: TColors.lavenderInk,
                        title: 'Sahabat Kring',
                        who: 'Bu Tini',
                        subtitle: 'Tetangga yang dihubungi pertama saat darurat.',
                        onTap: () => _open(const ContactHome(contactId: 'c-tini')),
                        onLongPress: () => _pickContact('sahabat_tilik'),
                      ),
                      _RoleTile(
                        icon: Icons.local_hospital_rounded,
                        color: TColors.sage,
                        ink: TColors.sageInk,
                        title: 'Puskesmas',
                        who: 'Wonosari I',
                        subtitle: 'Daftar Kring Hari Ini dan simulasi jam tangan.',
                        onTap: () => _open(const DaftarTilik()),
                      ),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [for (final t in tiles) SizedBox(width: w, child: t)],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _igdTile(),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _pickContact('child'),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Pilih keluarga lain'),
                    ),
                    TextButton.icon(
                      onPressed: () => _pickContact('sahabat_tilik'),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Pilih Sahabat lain'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Ulang data demo')),
                const SizedBox(height: 16),
                const Center(child: DemoBadge()),
                const SizedBox(height: 6),
                Text(
                  'Aturan klinis masih draf dan belum direview tenaga kesehatan. Mode demo tidak pernah menelepon 119 atau RS.',
                  style: TText.small,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Blok pembuka: janji produk di kiri, maskot melambai di kanan.
  Widget _hero() {
    final c = context.compact;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: TShadow.soft),
      child: PipoBackground(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(right: 2, bottom: 4, child: Tili(size: c ? 96 : 132, waving: true)),
            Padding(
              padding: EdgeInsets.fromLTRB(18, c ? 16 : 22, c ? 100 : 138, c ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jalur cepat stroke dimulai dari rumah Mbah.', style: TText.h1.copyWith(fontSize: c ? 21 : 25)),
                  const SizedBox(height: 8),
                  Text(
                    c
                        ? 'Telepon tiap pagi: obat, tensi, gejala. Ada tanda bahaya, semua langsung bergerak.'
                        : 'Telepon biasa tiap pagi: obat, tensi, gejala. Ada tanda bahaya, tetangga, anak, dan IGD langsung bergerak.',
                    style: TText.body.copyWith(fontSize: c ? 14.5 : 15.5, color: TColors.ink.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _igdTile() {
    return Material(
      color: TColors.night,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(const IgdBoard()),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: TColors.red, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IGD rumah sakit', style: TText.h3.copyWith(color: Colors.white)),
                    Text(
                      'Board pre-alert: jam onset, skrining, obat, ETA.',
                      style: TText.small.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverStatus() {
    final ok = _health != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: ok ? TColors.greenTint : TColors.yellowTint, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(ok ? (_health!['offline'] == true ? Icons.offline_bolt_rounded : Icons.cloud_done_rounded) : Icons.cloud_off_rounded, color: ok ? TColors.green : TColors.yellow, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? (_health!['offline'] == true
                      ? 'Mode offline · data demo tersimpan di HP ini'
                      : 'Server tersambung${_health!['llm'] == true ? ' · LLM aktif' : ' · jalur aturan'}')
                  : (_error ?? 'Memeriksa server…'),
              style: TText.small.copyWith(color: TColors.ink),
            ),
          ),
          if (!ok) TextButton(onPressed: _check, child: const Text('Cek')),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.color,
    required this.ink,
    required this.title,
    required this.who,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });
  final IconData icon;
  final Color color;
  final Color ink;
  final String title;
  final String who;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(icon, color: ink, size: 23),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, color: ink, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: TText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(who, style: TText.small.copyWith(color: ink, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: TText.label.copyWith(color: TColors.ink.withValues(alpha: 0.78), fontWeight: FontWeight.w600, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}
