// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebRoutePlatform {
  static void setUrlHash(String route, {bool replace = false}) {
    try {
      final normalized = route.startsWith('/') ? route : '/$route';
      if (html.window.location.hash != '#$normalized') {
        if (replace) {
          html.window.history.replaceState(null, '', '#$normalized');
        } else {
          html.window.history.pushState(null, '', '#$normalized');
        }
      }
    } catch (_) {}
  }

  static String? getUrlHash() {
    try {
      final hash = html.window.location.hash;
      if (hash.isNotEmpty) {
        var clean = hash;
        if (clean.startsWith('#/')) {
          return clean.substring(2);
        } else if (clean.startsWith('#')) {
          return clean.substring(1);
        }
        return clean;
      }
    } catch (_) {}
    return null;
  }
}
