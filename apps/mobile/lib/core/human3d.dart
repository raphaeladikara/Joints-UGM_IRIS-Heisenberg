import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'body3d.dart';
import 'human3d_bridge_io.dart' if (dart.library.js_interop) 'human3d_bridge_web.dart' as bridge;
import 'theme.dart';

export 'body3d.dart' show BodySpot, spotColor;

/// Model 3D lansia realistis (GLB dari aset MakeHuman CC0, lihat `tool/build_elder_glb.py`) di `<model-viewer>`.
/// Titik status organ = hotspot model-viewer; ketuk titik → [onSelect]. Warna titik & pilihan diperbarui lewat JS
/// tanpa memuat ulang model. Di platform tanpa WebView (desktop) jatuh ke [Body3D] prosedural.
class Human3D extends StatefulWidget {
  const Human3D({super.key, required this.spots, this.sex = 'F', this.selected, this.onSelect, this.height = 420, this.interactive = true});
  final List<BodySpot> spots;
  final String sex;
  final String? selected;
  final ValueChanged<String>? onSelect;
  final double height;
  final bool interactive;

  static bool get supported => kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  static Map<String, dynamic>? _anchors;
  static Future<Map<String, dynamic>> anchors() async =>
      _anchors ??= jsonDecode(await rootBundle.loadString('assets/models/anchors.json')) as Map<String, dynamic>;

  @override
  State<Human3D> createState() => _Human3DState();
}

class _Human3DState extends State<Human3D> {
  Map<String, dynamic>? _model;
  late final String _viewerId = 'mv${identityHashCode(this)}';
  final _bridge = bridge.Human3DBridge();

  String get _key => widget.sex == 'M' ? 'elder_male' : 'elder_female';

  @override
  void initState() {
    super.initState();
    Human3D.anchors().then((a) {
      if (mounted) setState(() => _model = a[_key] as Map<String, dynamic>);
    });
    _bridge.onTap = (id) => widget.onSelect?.call(id);
  }

  @override
  void didUpdateWidget(covariant Human3D old) {
    super.didUpdateWidget(old);
    _bridge.onTap = (id) => widget.onSelect?.call(id);
    _bridge.update(_viewerId, _state());
  }

  String _state() => jsonEncode({
    'selected': widget.selected,
    'spots': {for (final s in widget.spots) s.id: s.level},
  });

  static String _color(String level) => switch (level) {
    'red' => '#C4261D',
    'yellow' => '#E0A100',
    'green' => '#1F9D57',
    _ => '#8C97AA',
  };

  String _hotspots() {
    final pos = (_model!['spots'] as Map).cast<String, dynamic>();
    final b = StringBuffer();
    for (final s in widget.spots) {
      final p = (pos[s.id] as List?)?.cast<num>();
      if (p == null) continue;
      final sel = s.id == widget.selected ? ' sel' : '';
      b.write('<button class="hs$sel" slot="hotspot-${s.id}" data-id="${s.id}" data-position="${p[0]}m ${p[1]}m ${p[2]}m" '
          'data-normal="0m 0m 1m" style="--c:${_color(s.level)}" aria-label="${s.label}"><span class="ring"></span><span class="lbl">${s.label}</span></button>');
    }
    return b.toString();
  }

  static const _css = '''
  model-viewer { --poster-color: transparent; }
  .hs { position: relative; width: 22px; height: 22px; border-radius: 50%; border: 3px solid #fff; background: var(--c); padding: 0;
        box-shadow: 0 2px 8px rgba(14,26,43,.35); cursor: pointer; transition: transform .25s ease; }
  .hs .ring { position: absolute; inset: -9px; border-radius: 50%; border: 2px solid var(--c); opacity: .0; animation: pulse 2.2s ease-out infinite; }
  .hs.sel { transform: scale(1.25); }
  .hs.sel .ring { opacity: .9; }
  .hs .lbl { position: absolute; left: 26px; top: 50%; transform: translateY(-50%); white-space: nowrap; background: #0E1A2B; color: #fff;
             font: 700 12px system-ui, sans-serif; padding: 4px 9px; border-radius: 99px; opacity: 0; transition: opacity .2s; pointer-events: none; }
  .hs.sel .lbl { opacity: 1; }
  .hs[data-visible="false"] { opacity: .25; }
  @keyframes pulse { 0% { transform: scale(.6); opacity: .9 } 100% { transform: scale(1.6); opacity: 0 } }
  @media (prefers-reduced-motion: reduce) { .hs .ring { animation: none; } }
  ''';

  String _js() => '''
  (function(){
    const colors = {red:'#C4261D', yellow:'#E0A100', green:'#1F9D57', none:'#8C97AA'};
    const mv = document.getElementById('$_viewerId') || document.querySelector('model-viewer');
    function send(id){ try { KringJs.postMessage(id); } catch(e) {} }
    function focus(id){
      const el = mv.querySelector('[data-id="'+id+'"]'); if(!el) return;
      const p = el.dataset.position.replaceAll('m','').trim().split(' ').filter(Boolean).map(Number);
      const cy = ${_model!['center_y']};
      // auto-rotate memutar model (turntable), bukan kamera: kembalikan supaya titik menghadap pengguna.
      if (mv.resetTurntableRotation) mv.resetTurntableRotation(0);
      mv.cameraTarget = '0m ' + (cy + (p[1] - cy) * 0.35) + 'm 0m';
      mv.cameraOrbit = (p[0] > 0.12 ? '28deg' : (p[0] < -0.12 ? '-28deg' : '0deg')) + ' 82deg 2.7m';
      mv.fieldOfView = '30deg';
    }
    // Beberapa GPU Android macet di render pertama WebView: paksa render ulang setelah model dimuat.
    function nudge(){ mv.exposure = Number(mv.exposure || 1) + 0.0001; setTimeout(() => { mv.exposure = Number(mv.exposure) - 0.0001; }, 60); }
    mv.addEventListener('load', () => { setTimeout(nudge, 300); setTimeout(nudge, 1500); });
    mv.querySelectorAll('.hs').forEach(el => el.addEventListener('click', ev => { ev.stopPropagation(); send(el.dataset.id); }));
    window.tilikUpdate = function(json){
      const s = JSON.parse(json);
      mv.querySelectorAll('.hs').forEach(el => {
        const lv = s.spots[el.dataset.id] || 'none';
        el.style.setProperty('--c', colors[lv] || colors.none);
        el.classList.toggle('sel', el.dataset.id === s.selected);
      });
      if (s.selected) focus(s.selected);
    };
  })();
  ''';

  @override
  Widget build(BuildContext context) {
    if (!Human3D.supported) {
      return Body3D(spots: widget.spots, sex: widget.sex, selected: widget.selected, onSelect: widget.onSelect, height: widget.height);
    }
    final m = _model;
    if (m == null) return SizedBox(height: widget.height);
    final cy = m['center_y'] as num;
    return SizedBox(
      height: widget.height,
      child: ModelViewer(
        id: _viewerId,
        src: kIsWeb ? 'assets/assets/models/$_key.glb' : 'assets/models/$_key.glb',
        alt: widget.sex == 'M' ? 'Model 3D lansia pria' : 'Model 3D lansia wanita',
        backgroundColor: Colors.transparent,
        cameraControls: widget.interactive,
        disableZoom: !widget.interactive,
        disablePan: true,
        touchAction: TouchAction.panY,
        autoRotate: true,
        autoRotateDelay: 2500,
        rotationPerSecond: '14deg',
        interactionPrompt: InteractionPrompt.none,
        cameraOrbit: '-18deg 84deg 3.1m',
        cameraTarget: '0m ${cy}m 0m',
        fieldOfView: '30deg',
        minCameraOrbit: 'auto 55deg auto',
        maxCameraOrbit: 'auto 100deg auto',
        environmentImage: 'neutral',
        exposure: 1.08,
        shadowIntensity: 0.9,
        shadowSoftness: 1,
        interpolationDecay: 120,
        innerModelViewerHtml: widget.interactive ? _hotspots() : null,
        relatedCss: _css,
        relatedJs: widget.interactive ? _js() : null,
        javascriptChannels: {JavascriptChannel('KringJs', onMessageReceived: (msg) => _bridge.onTap?.call(msg.message))},
        onWebViewCreated: _bridge.attach,
        debugLogging: false,
      ),
    );
  }
}

/// Warna titik status untuk UI Flutter di sekitar model (chip, panel).
Color levelColor(String level) => switch (level) {
  'red' => TColors.red,
  'yellow' => const Color(0xFFE0A100),
  'green' => TColors.green,
  _ => TColors.muted,
};
