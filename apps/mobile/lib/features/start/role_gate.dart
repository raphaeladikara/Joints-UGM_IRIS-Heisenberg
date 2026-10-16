import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../contact/contact_home.dart';
import '../igd/igd_board.dart';
import '../phone/mbah_phone.dart';
import '../puskesmas/daftar_tilik.dart';

/// Pilih peran. Satu APK untuk demo: HP Mbah (simulator telepon biasa), keluarga, Sahabat Tilik, Puskesmas, IGD.
/// Di produksi, Mbah tidak butuh aplikasi apa pun: TILIK menelepon nomor HP biasa.
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
    final ctrl = TextEditingController(text: Api.instance.base);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alamat server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'http://192.168.1.10:8080'),
            ),
            const SizedBox(height: 8),
            Text('Kosongkan untuk kembali ke bawaan: ${Api.platformDefault}', style: TText.small),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (saved == true) {
      await Api.instance.setBase(ctrl.text);
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
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: TColors.leaf, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TILIK', style: TText.display),
                          Text('Cegah · Deteksi · Arahkan', style: TText.small),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _settings, icon: const Icon(Icons.settings_rounded), tooltip: 'Alamat server'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Jalur cepat stroke dimulai dari rumah Mbah, bukan dari pintu IGD.',
                  style: TText.h3.copyWith(color: TColors.leafDeep),
                ),
                const SizedBox(height: 6),
                Text(
                  'TILIK menelepon lansia hipertensi setiap pagi lewat telepon biasa, mengecek obat, tensi, dan gejala, '
                  'lalu menggerakkan tetangga, anak, dan IGD saat ada tanda stroke.',
                  style: TText.body.copyWith(color: TColors.muted),
                ),
                const SizedBox(height: 12),
                _serverStatus(),
                const SectionTitle('Masuk sebagai'),
                _RoleCard(
                  icon: Icons.phone_android_rounded,
                  color: TColors.clay,
                  title: 'HP Mbah (Bu Sri)',
                  subtitle: 'Simulator telepon biasa: TILIK menelepon, Mbah menjawab dengan suara.',
                  onTap: () => _open(const MbahPhone(patientId: 'p-sri')),
                ),
                _RoleCard(
                  icon: Icons.family_restroom_rounded,
                  color: TColors.leaf,
                  title: 'Keluarga (Mas Dika)',
                  subtitle: 'Rapor pagi, bahan obrolan, titip pesan, alert darurat.',
                  onTap: () => _open(const ContactHome(contactId: 'c-dika')),
                  onLongPress: () => _pickContact('child'),
                ),
                _RoleCard(
                  icon: Icons.volunteer_activism_rounded,
                  color: const Color(0xFF6A5ACD),
                  title: 'Sahabat Tilik (Bu Tini)',
                  subtitle: 'Tetangga yang dihubungi pertama saat darurat.',
                  onTap: () => _open(const ContactHome(contactId: 'c-tini')),
                  onLongPress: () => _pickContact('sahabat_tilik'),
                ),
                _RoleCard(
                  icon: Icons.local_hospital_outlined,
                  color: TColors.green,
                  title: 'Puskesmas',
                  subtitle: 'Daftar Tilik Hari Ini, tombol "Tilik sekarang", simulasi jam tangan.',
                  onTap: () => _open(const DaftarTilik()),
                ),
                _RoleCard(
                  icon: Icons.monitor_heart_outlined,
                  color: TColors.red,
                  title: 'IGD RS',
                  subtitle: 'Board pre-alert: jam onset, skrining, obat, ETA.',
                  onTap: () => _open(const IgdBoard()),
                ),
                const SizedBox(height: 8),
                Text('Tahan kartu Keluarga/Sahabat untuk memilih orang lain.', style: TText.small, textAlign: TextAlign.center),
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

  Widget _serverStatus() {
    final ok = _health != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ok ? TColors.greenTint : TColors.yellowTint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: ok ? TColors.green : TColors.yellow, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'Server tersambung · ${Api.instance.base}${_health!['llm'] == true ? ' · LLM aktif' : ' · jalur aturan'}'
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TText.h3),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TText.small),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: TColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
