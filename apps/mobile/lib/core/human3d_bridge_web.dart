import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: model-viewer ada di DOM halaman yang sama (HtmlElementView), skrip `relatedJs` tidak dijalankan oleh
/// innerHTML, jadi hotspot diurus langsung dari Dart.
class Human3DBridge {
  void Function(String id)? onTap;
  final _wired = <String>{};

  void attach(Object _) {}

  void update(String viewerId, String stateJson) => _apply(viewerId, stateJson, 0);

  void _apply(String viewerId, String stateJson, int attempt) {
    final mv = web.document.getElementById(viewerId);
    if (mv == null) {
      if (attempt < 20) Timer(const Duration(milliseconds: 300), () => _apply(viewerId, stateJson, attempt + 1));
      return;
    }
    final s = jsonDecode(stateJson) as Map<String, dynamic>;
    final spots = (s['spots'] as Map).cast<String, String>();
    const colors = {'red': '#C4261D', 'yellow': '#E0A100', 'green': '#1F9D57'};
    final nodes = mv.querySelectorAll('.hs');
    for (var i = 0; i < nodes.length; i++) {
      final el = nodes.item(i) as web.HTMLElement;
      final id = el.dataset['id'];
      el.style.setProperty('--c', colors[spots[id]] ?? '#8C97AA');
      el.classList.toggle('sel', id == s['selected']);
      if (_wired.add('$viewerId/$id')) {
        el.addEventListener('click', ((web.Event e) {
          e.stopPropagation();
          onTap?.call(id);
        }).toJS);
      }
    }
  }
}
