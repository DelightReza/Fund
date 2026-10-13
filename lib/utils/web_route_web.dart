// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebRoutePlatform {
  static void setUrlHash(String route, {bool replace = false}) {
    try {
      final clean = route.trim();
      final lower = clean.toLowerCase();

      // If route is default (transactions, home, or empty), keep URL clean at base pathname
      if (lower == 'transactions' || lower == '/' || lower.isEmpty) {
        final path = html.window.location.pathname ?? '';
        final search = html.window.location.search ?? '';
        final target = '$path$search';
        if (html.window.location.hash.isNotEmpty) {
          if (replace) {
            html.window.history.replaceState(null, '', target);
          } else {
            html.window.history.pushState(null, '', target);
          }
        }
        return;
      }

      var normalized = clean.startsWith('/') ? clean.substring(1) : clean;
      final targetHash = '#/$normalized';
      if (html.window.location.hash != targetHash) {
        if (replace) {
          html.window.history.replaceState(null, '', targetHash);
        } else {
          html.window.history.pushState(null, '', targetHash);
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
          clean = clean.substring(2);
        } else if (clean.startsWith('#')) {
          clean = clean.substring(1);
        }
        clean = clean.trim();
        while (clean.startsWith('/')) {
          clean = clean.substring(1);
        }
        if (clean.isEmpty || clean.toLowerCase() == 'transactions') {
          return null;
        }
        return clean;
      }

      // Fallback: check query parameters if hash is not present
      final search = html.window.location.search;
      if (search != null && search.isNotEmpty) {
        var cleanSearch = search;
        if (cleanSearch.startsWith('?')) {
          cleanSearch = cleanSearch.substring(1);
        }
        final uri = Uri.tryParse('http://app/?$cleanSearch');
        if (uri != null && uri.queryParameters.isNotEmpty) {
          if (uri.queryParameters.containsKey('member')) {
            return 'member?id=${uri.queryParameters['member']}';
          }
          if (uri.queryParameters.containsKey('tx')) {
            return 'tx?id=${uri.queryParameters['tx']}';
          }
          if (uri.queryParameters.containsKey('category')) {
            return 'category?id=${uri.queryParameters['category']}';
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
