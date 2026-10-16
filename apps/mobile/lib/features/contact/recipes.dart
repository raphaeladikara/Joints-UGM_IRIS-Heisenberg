import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/mascot.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Resep rumahan rendah garam untuk lansia hipertensi (DRAF, perlu review ahli gizi). Natrium per porsi adalah
/// estimasi kasar dengan garam ±¼ sdt per resep; batas harian yang dipakai aplikasi: 1 sdt garam (±2.000 mg natrium).
class Recipe {
  const Recipe(this.id, this.name, this.emoji, this.color, this.meals, this.tags, this.kcal, this.sodium, this.minutes, this.why, this.ingredients,
      this.steps);
  final String id, name, emoji, why;
  final Color color;
  final List<String> meals, tags, ingredients, steps;
  final int kcal, sodium, minutes;
}

const mealLabels = {'sarapan': ('☕', 'Sarapan'), 'siang': ('🍛', 'Makan siang'), 'malam': ('🌙', 'Makan malam'), 'camilan': ('🍌', 'Camilan')};
const tagLabels = {
  'rendah_garam': ('🧂', 'Rendah garam'), 'kalium': ('🍌', 'Tinggi kalium'), 'lunak': ('🥣', 'Lunak dikunyah'),
  'cepat': ('⏱️', 'Cepat'), 'protein': ('💪', 'Tinggi protein'), 'serat': ('🌾', 'Tinggi serat'),
};

const recipes = [
  Recipe('bening', 'Sayur bening bayam jagung', '🥬', Color(0xFFE2F0E8), ['siang', 'malam'], ['rendah_garam', 'kalium', 'lunak', 'cepat'], 90, 120, 15,
      'Bayam dan jagung kaya kalium yang membantu menurunkan tensi. Kuahnya gurih dari temu kunci, bukan garam.',
      ['1 ikat bayam', '1 jagung manis, dipipil', '2 siung bawang merah, iris', '1 ruas temu kunci', '600 ml air', 'Garam ¼ sdt, gula sedikit'],
      ['Didihkan air bersama bawang merah dan temu kunci.', 'Masukkan jagung, masak 5 menit.', 'Masukkan bayam, matikan api setelah layu.', 'Bumbui garam sedikit saja di akhir.']),
  Recipe('pepes', 'Pepes ikan kembung kemangi', '🐟', Color(0xFFE2F0E8), ['siang', 'malam'], ['rendah_garam', 'protein'], 210, 260, 40,
      'Ikan kembung mengandung omega-3 yang baik untuk jantung. Rasa dari kemangi, tomat, dan kunyit.',
      ['2 ekor ikan kembung', '1 ikat kemangi', '1 tomat, iris', 'Bumbu halus: bawang merah, bawang putih, kunyit, kemiri', 'Daun pisang', 'Garam ¼ sdt'],
      ['Lumuri ikan dengan bumbu halus.', 'Letakkan di daun pisang bersama kemangi dan tomat, bungkus.', 'Kukus 30 menit, lalu bakar sebentar bila suka.']),
  Recipe('kacijo', 'Bubur kacang hijau', '🫘', Color(0xFFFFF0C7), ['sarapan', 'camilan'], ['rendah_garam', 'serat', 'lunak', 'kalium'], 220, 15, 45,
      'Kacang hijau tinggi serat dan kalium. Pakai gula aren secukupnya, tanpa santan kental.',
      ['150 g kacang hijau, rendam semalam', '1 ruas jahe, memarkan', '1 lembar daun pandan', '50 g gula aren', '1 liter air'],
      ['Rebus kacang hijau bersama jahe dan pandan hingga empuk.', 'Masukkan gula aren, aduk sampai larut.', 'Sajikan hangat.']),
  Recipe('tempe', 'Tumis tempe kacang panjang', '🫛', Color(0xFFF7E4DA), ['siang'], ['protein', 'serat', 'cepat'], 230, 240, 20,
      'Tempe adalah protein nabati murah dan baik untuk kolesterol. Tumis dengan sedikit minyak.',
      ['1 papan tempe, potong dadu', '1 ikat kacang panjang', 'Bawang merah & putih', '1 cabai merah besar, buang biji', 'Kecap manis 1 sdt', 'Garam ¼ sdt'],
      ['Tumis bawang dan cabai sampai harum.', 'Masukkan tempe, aduk hingga kecokelatan.', 'Masukkan kacang panjang dan sedikit air, masak hingga matang.']),
  Recipe('sup', 'Sup ayam kampung sayuran', '🍲', Color(0xFFEDEAE3), ['malam'], ['lunak', 'protein', 'rendah_garam'], 240, 300, 50,
      'Hangat dan lunak untuk gigi lansia. Kaldu dari ayam dan sayur, tanpa penyedap.',
      ['250 g ayam kampung tanpa kulit', 'Wortel, kentang, buncis', 'Daun bawang & seledri', 'Bawang putih geprek', 'Merica', 'Garam ¼ sdt'],
      ['Rebus ayam dengan bawang putih hingga kaldu keluar.', 'Masukkan kentang dan wortel, masak sampai empuk.', 'Tambahkan buncis, daun bawang, seledri, merica.']),
  Recipe('oat', 'Bubur oat pisang', '🍌', Color(0xFFFFF0C7), ['sarapan'], ['kalium', 'serat', 'lunak', 'cepat', 'rendah_garam'], 260, 40, 10,
      'Oat membantu kolesterol, pisang menambah kalium. Sarapan cepat yang mengenyangkan.',
      ['5 sdm oat', '200 ml susu rendah lemak atau air', '1 pisang, iris', 'Kayu manis sedikit'],
      ['Masak oat dengan susu sambil diaduk 5 menit.', 'Tuang ke mangkuk, beri pisang dan kayu manis.']),
  Recipe('tahu', 'Tahu kukus telur', '🥚', Color(0xFFE2F0E8), ['sarapan', 'malam'], ['protein', 'lunak', 'rendah_garam', 'cepat'], 180, 200, 25,
      'Lembut seperti puding, mudah ditelan. Protein dari tahu dan telur.',
      ['2 buah tahu putih', '1 butir telur', 'Daun bawang iris', 'Wortel parut', 'Merica, garam sejumput'],
      ['Haluskan tahu, campur telur, wortel, daun bawang, merica.', 'Tuang ke wadah tahan panas.', 'Kukus 20 menit.']),
  Recipe('gado', 'Gado-gado saus kacang ringan', '🥗', Color(0xFFE2F0E8), ['siang'], ['serat', 'kalium', 'protein'], 320, 280, 30,
      'Sayur rebus aneka warna dengan saus kacang tanpa terasi dan garam dikurangi.',
      ['Kangkung, tauge, kol, kacang panjang, kentang rebus', 'Tahu & tempe kukus', 'Saus: kacang tanah sangrai, bawang putih, gula merah, jeruk limau'],
      ['Rebus sayur sebentar agar tetap renyah.', 'Haluskan bahan saus dengan air hangat.', 'Tata sayur dan siram saus secukupnya.']),
  Recipe('semangka', 'Es semangka timun', '🍉', Color(0xFFFDE2E1), ['camilan'], ['kalium', 'rendah_garam', 'cepat'], 90, 10, 5,
      'Menyegarkan dan menambah cairan. Cocok untuk Mbah yang kurang minum.',
      ['2 potong semangka', '½ timun, parut kasar', 'Daun mint', 'Es batu secukupnya'],
      ['Potong dadu semangka, campur timun dan mint.', 'Tambahkan es batu dan sedikit air.']),
  Recipe('ubi', 'Ubi rebus & teh tawar hangat', '🍠', Color(0xFFF7E4DA), ['camilan', 'sarapan'], ['serat', 'kalium', 'rendah_garam', 'lunak'], 150, 30, 25,
      'Pengganti gorengan saat ngeteh. Ubi ungu kaya antioksidan.',
      ['2 buah ubi jalar ungu', 'Teh tubruk tawar'],
      ['Cuci ubi, rebus 20 menit hingga empuk.', 'Sajikan dengan teh tawar hangat.']),
  Recipe('garangasem', 'Garang asem ayam kukus', '🍃', Color(0xFFE2F0E8), ['malam'], ['protein', 'rendah_garam'], 250, 320, 45,
      'Asam belimbing wuluh dan tomat menggantikan rasa asin. Dikukus dalam daun pisang.',
      ['250 g dada ayam', 'Belimbing wuluh, tomat hijau', 'Cabai rawit utuh, daun salam, lengkuas', 'Bawang merah & putih iris', 'Garam ¼ sdt'],
      ['Campur ayam dengan semua bumbu dan sedikit air.', 'Bungkus dengan daun pisang.', 'Kukus 40 menit.']),
  Recipe('nasimerah', 'Nasi merah & ikan bakar sambal tomat', '🍚', Color(0xFFEDEAE3), ['siang', 'malam'], ['serat', 'protein'], 380, 290, 35,
      'Nasi merah lebih lambat menaikkan gula darah. Sambal tomat segar tanpa terasi.',
      ['1 porsi nasi merah', '1 ekor ikan nila', 'Jeruk nipis', 'Sambal: tomat, cabai, bawang merah, sedikit gula'],
      ['Lumuri ikan dengan jeruk nipis dan bawang putih.', 'Bakar di teflon hingga matang.', 'Ulek sambal tomat kasar, sajikan dengan nasi merah.']),
];

/// Tab "Menu": pilihan hari ini, filter ala aplikasi resep, dan kirim resep ke Mbah lewat titip pesan KRING.
class RecipesView extends StatefulWidget {
  const RecipesView({super.key, required this.feed, required this.contactId, required this.onSent});
  final Json feed;
  final String contactId;
  final VoidCallback onSent;

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

class _RecipesViewState extends State<RecipesView> {
  final Set<String> _tags = {};
  String? _meal;
  double _maxSodium = 500;

  List<Recipe> get _filtered => [
    for (final r in recipes)
      if ((_meal == null || r.meals.contains(_meal)) && _tags.every(r.tags.contains) && r.sodium <= _maxSodium) r,
  ];

  String get _name => widget.feed['patient']['display_name'] as String;

  Future<void> _openFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TColors.night,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void update(VoidCallback f) {
            setLocal(f);
            setState(() {});
          }

          final n = _filtered.length;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.86,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: TColors.skyBright)),
                    Expanded(child: Text('Filter', textAlign: TextAlign.center, style: TText.h2.copyWith(color: Colors.white))),
                    TextButton(
                      onPressed: () => update(() {
                        _tags.clear();
                        _meal = null;
                        _maxSodium = 500;
                      }),
                      child: const Text('Reset', style: TextStyle(color: TColors.skyBright)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Filter populer', style: TText.h3.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                  children: [
                    for (final e in tagLabels.entries)
                      _FilterTile(
                        emoji: e.value.$1,
                        label: e.value.$2,
                        selected: _tags.contains(e.key),
                        onTap: () => update(() => _tags.contains(e.key) ? _tags.remove(e.key) : _tags.add(e.key)),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(color: TColors.nightLine),
                const SizedBox(height: 14),
                Text('Natrium per porsi', style: TText.h3.copyWith(color: Colors.white)),
                Text('mg (batas harian ±2.000 mg = 1 sdt garam)', style: TText.small.copyWith(color: Colors.white70)),
                Row(
                  children: [
                    Text('0', style: TText.small.copyWith(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: _maxSodium,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        label: '≤ ${_maxSodium.round()} mg',
                        activeColor: TColors.skyBright,
                        inactiveColor: TColors.nightLine,
                        onChanged: (v) => update(() => _maxSodium = v),
                      ),
                    ),
                    Text('${_maxSodium.round()}', style: TText.small.copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: TColors.nightLine),
                const SizedBox(height: 14),
                Text('Waktu makan', style: TText.h3.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in mealLabels.entries)
                      ChoiceChip(
                        selected: _meal == e.key,
                        onSelected: (_) => update(() => _meal = _meal == e.key ? null : e.key),
                        showCheckmark: false,
                        label: Text('${e.value.$1}  ${e.value.$2}'),
                        labelStyle: TText.body.copyWith(color: _meal == e.key ? TColors.night : Colors.white, fontWeight: FontWeight.w700),
                        backgroundColor: TColors.nightPanel,
                        selectedColor: TColors.skyBright,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: TColors.brand, minimumSize: const Size.fromHeight(60), shape: const StadiumBorder()),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(n == 0 ? 'Tidak ada resep cocok' : 'Lihat $n resep'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openRecipe(Recipe r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecipeSheet(recipe: r, patientName: _name, onSend: () => _send(r)),
    );
  }

  Future<void> _send(Recipe r) async {
    final me = widget.feed['contact']['name'] as String;
    try {
      await Api.instance.sendFamilyMessage(widget.feed['patient']['id'] as String, widget.contactId,
          '$me kirim ide masakan: ${r.name}. ${r.why.split('.').first}. Garamnya sedikit saja, ya.');
      widget.onSent();
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resep dititipkan. KRING membacakannya untuk $_name besok pagi.')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final day = DateTime.now().weekday;
    final pick = recipes[(day * 5) % recipes.length];
    final active = _tags.length + (_meal == null ? 0 : 1) + (_maxSodium < 500 ? 1 : 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menu sehat $_name', style: TText.h1),
                  const SizedBox(height: 4),
                  Text('Masakan rumahan rendah garam, resep baru tiap minggu.', style: TText.small),
                ],
              ),
            ),
            const Tili(size: 72, mood: TiliMood.happy),
          ],
        ),
        const SizedBox(height: 14),
        _TodayPick(recipe: pick, onTap: () => _openRecipe(pick)),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Text('Semua resep', style: TText.h2)),
            Badge(
              isLabelVisible: active > 0,
              label: Text('$active'),
              child: OutlinedButton.icon(onPressed: _openFilter, icon: const Icon(Icons.tune_rounded), label: const Text('Filter')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in mealLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _meal == e.key,
                    onSelected: (_) => setState(() => _meal = _meal == e.key ? null : e.key),
                    showCheckmark: false,
                    label: Text('${e.value.$1} ${e.value.$2}'),
                    selectedColor: TColors.night,
                    labelStyle: TText.small.copyWith(color: _meal == e.key ? Colors.white : TColors.ink, fontWeight: FontWeight.w800),
                    backgroundColor: TColors.panel,
                    shape: const StadiumBorder(side: BorderSide(color: TColors.line)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: TiliSays('Belum ada resep yang cocok. Coba longgarkan filternya, ya.', mood: TiliMood.worried),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
          itemBuilder: (_, i) => _RecipeCard(recipe: list[i], onTap: () => _openRecipe(list[i])),
        ),
        const SizedBox(height: 14),
        Text('Resep draf, perlu ditinjau ahli gizi Puskesmas. Natrium per porsi adalah perkiraan.', style: TText.small, textAlign: TextAlign.center),
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({required this.emoji, required this.label, required this.selected, required this.onTap});
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Material(
          color: selected ? const Color(0xFF1F6B4F) : TColors.nightPanel,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6DFD0), width: 3)),
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  if (selected)
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 34, color: TColors.night),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TText.small.copyWith(color: Colors.white)),
    ],
  );
}

class Plate extends StatelessWidget {
  const Plate(this.emoji, {super.key, this.size = 92});
  final String emoji;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(colors: [Colors.white, Color(0xFFEFE8DA)], stops: [0.62, 1]),
      boxShadow: const [BoxShadow(color: Color(0x1F153A2C), blurRadius: 14, offset: Offset(0, 6))],
      border: Border.all(color: Colors.white, width: size * 0.05),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
  );
}

class _TodayPick extends StatelessWidget {
  const _TodayPick({required this.recipe, required this.onTap});
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TColors.night,
    borderRadius: BorderRadius.circular(30),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: TColors.skyBright, borderRadius: BorderRadius.circular(99)),
                    child: Text('PILIHAN HARI INI', style: TText.label.copyWith(color: TColors.night, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Text(recipe.name, style: TText.h2.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('${recipe.kcal} kkal · ${recipe.sodium} mg natrium · ${recipe.minutes} menit',
                      style: TText.small.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Lihat resep', style: TText.small.copyWith(color: TColors.skyBright, fontWeight: FontWeight.w800)),
                      const Icon(Icons.arrow_forward_rounded, color: TColors.skyBright, size: 18),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Plate(recipe.emoji, size: 110),
          ],
        ),
      ),
    ),
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onTap});
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: recipe.color,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Plate(recipe.emoji, size: 86)),
            const SizedBox(height: 10),
            Text(recipe.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TText.h3.copyWith(fontSize: 16.5)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 16, color: TColors.clay),
                Text(' ${recipe.kcal}', style: TText.label.copyWith(color: TColors.ink)),
                const SizedBox(width: 8),
                const Text('🧂', style: TextStyle(fontSize: 13)),
                Text(' ${recipe.sodium} mg', style: TText.label.copyWith(color: TColors.ink)),
              ],
            ),
            const SizedBox(height: 2),
            Text('${recipe.minutes} menit · ${mealLabels[recipe.meals.first]!.$2}', style: TText.label.copyWith(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class RecipeSheet extends StatelessWidget {
  const RecipeSheet({super.key, required this.recipe, required this.patientName, required this.onSend});
  final Recipe recipe;
  final String patientName;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final saltPct = (r.sodium / 2000).clamp(0.0, 1.0);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(30)),
            child: Center(child: Plate(r.emoji, size: 150)),
          ),
          const SizedBox(height: 16),
          Text(r.name, style: TText.h1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in r.tags) Chip(label: Text('${tagLabels[t]!.$1} ${tagLabels[t]!.$2}'), backgroundColor: TColors.panel)],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('${r.kcal}', 'kkal', Icons.local_fire_department_rounded, TColors.clay),
              _stat('${r.sodium}', 'mg natrium', Icons.water_drop_rounded, TColors.brand),
              _stat('${r.minutes}', 'menit', Icons.timer_rounded, TColors.green),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(22), boxShadow: TShadow.soft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Garam satu porsi dari batas harian', style: TText.small.copyWith(color: TColors.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: saltPct, minHeight: 12, backgroundColor: TColors.sunk, color: saltPct > 0.2 ? TColors.clay : TColors.green),
                ),
                const SizedBox(height: 6),
                Text('${(saltPct * 100).round()}% dari ±2.000 mg natrium per hari', style: TText.small),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Kenapa cocok untuk tensi', style: TText.h3),
          const SizedBox(height: 4),
          Text(r.why, style: TText.body),
          const SizedBox(height: 16),
          Text('Bahan', style: TText.h3),
          const SizedBox(height: 6),
          for (final i in r.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('•  ', style: TText.body), Expanded(child: Text(i, style: TText.body))],
              ),
            ),
          const SizedBox(height: 12),
          Text('Cara membuat', style: TText.h3),
          const SizedBox(height: 6),
          for (final (n, s) in r.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: TColors.brandTint, shape: BoxShape.circle),
                    child: Text('${n + 1}', style: TText.label.copyWith(color: TColors.brandDeep)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s, style: TText.body)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60), shape: const StadiumBorder()),
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded),
            label: Text('Kirim ke $patientName lewat KRING'),
          ),
          const SizedBox(height: 6),
          Text('KRING membacakan ide masakan ini di telepon pagi berikutnya.', style: TText.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _stat(String v, String unit, IconData icon, Color c) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: TColors.panel, borderRadius: BorderRadius.circular(20), boxShadow: TShadow.soft),
      child: Column(
        children: [
          Icon(icon, color: c),
          const SizedBox(height: 4),
          Text(v, style: TText.h2),
          Text(unit, style: TText.label),
        ],
      ),
    ),
  );
}
