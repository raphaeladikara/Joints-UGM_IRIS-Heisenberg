import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Android/iOS: perbarui hotspot lewat WebView; ketukan datang dari JavascriptChannel `KringJs`.
class Human3DBridge {
  WebViewController? _c;
  String? _pending;
  void Function(String id)? onTap;

  /// Build uji saja: `--dart-define=WEBVIEW_DEBUG=true` membuka WebView untuk chrome://inspect.
  static const _debug = bool.fromEnvironment('WEBVIEW_DEBUG');

  void attach(WebViewController c) {
    _c = c;
    if (_debug) AndroidWebViewController.enableDebugging(true);
    c.setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
      final p = _pending;
      if (p != null) Future<void>.delayed(const Duration(milliseconds: 400), () => _run(p));
    }));
  }

  void update(String viewerId, String stateJson) {
    _pending = stateJson;
    _run(stateJson);
  }

  void _run(String json) {
    final escaped = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    _c?.runJavaScript("window.tilikUpdate && window.tilikUpdate('$escaped')").catchError((_) {});
  }
}
