import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_route_stub.dart'
    if (dart.library.html) 'web_route_web.dart';

class ParsedRoute {
  final String path;
  final Map<String, String> queryParameters;

  ParsedRoute(this.path, this.queryParameters);

  String? get id => queryParameters['id'];
  String? get from => queryParameters['from'];
  String? get catId => queryParameters['catId'];
  String? get memberId => queryParameters['memberId'];

  /// Computes the exact parent route to return to when Back is pressed
  String get parentRoute {
    if (path == 'tx' || path == 'transaction') {
      if (from == 'category') {
        final cid = catId;
        return (cid != null && cid.isNotEmpty) ? 'category?id=$cid' : 'expenses';
      } else if (from == 'member') {
        final mid = memberId;
        return (mid != null && mid.isNotEmpty) ? 'member?id=$mid' : 'people';
      } else if (from == 'expenses' || from == 'bills') {
        return 'expenses';
      } else if (from == 'people') {
        return 'people';
      } else if (from == 'transactions') {
        return 'transactions';
      } else if (from == 'admin') {
        return 'admin';
      }
      return 'transactions';
    } else if (path == 'category') {
      return 'expenses';
    } else if (path == 'member' || path == 'profile') {
      return 'people';
    } else if (path == 'add_tx') {
      return from == 'transactions' ? 'transactions' : 'admin';
    } else if (path == 'manage_config' || path == 'reset_commit') {
      return 'admin';
    } else if (path == 'admin' || path == 'expenses' || path == 'people') {
      return 'transactions';
    }
    return 'transactions';
  }

  static ParsedRoute parse(String? rawRoute) {
    if (rawRoute == null || rawRoute.trim().isEmpty) {
      return ParsedRoute('transactions', {});
    }

    var clean = rawRoute.trim();
    while (clean.startsWith('#') || clean.startsWith('/')) {
      clean = clean.substring(1);
    }

    final uri = Uri.tryParse('http://app/$clean');
    if (uri != null) {
      var p = uri.path;
      while (p.startsWith('/')) {
        p = p.substring(1);
      }
      if (p.isEmpty) p = 'transactions';
      return ParsedRoute(p.toLowerCase(), uri.queryParameters);
    }
    return ParsedRoute(clean.toLowerCase(), {});
  }
}

class WebRouteHelper {
  static void setRoute(String route, {bool replace = false}) {
    if (kIsWeb) {
      WebRoutePlatform.setUrlHash(route, replace: replace);
    }
  }

  static String buildCategoryRoute(String catId) {
    return 'category?id=$catId';
  }

  static String buildMemberRoute(String memberId) {
    return 'member?id=$memberId';
  }

  static String buildAddTxRoute({String? from}) {
    return from != null && from.isNotEmpty ? 'add_tx?from=$from' : 'add_tx';
  }

  static String buildTxRoute(
    String txId, {
    String? from,
    String? catId,
    String? memberId,
  }) {
    var route = 'tx?id=$txId';
    if (from != null && from.isNotEmpty) {
      route += '&from=$from';
    }
    if (catId != null && catId.isNotEmpty) {
      route += '&catId=$catId';
    }
    if (memberId != null && memberId.isNotEmpty) {
      route += '&memberId=$memberId';
    }
    return route;
  }

  static String buildTxRouteFromReturnRoute(String txId, String returnRoute) {
    final parsed = ParsedRoute.parse(returnRoute);
    if (parsed.path == 'category') {
      return buildTxRoute(txId, from: 'category', catId: parsed.id);
    } else if (parsed.path == 'member') {
      return buildTxRoute(txId, from: 'member', memberId: parsed.id);
    } else if (parsed.path == 'expenses' || parsed.path == 'bills') {
      return buildTxRoute(txId, from: 'expenses');
    } else if (parsed.path == 'people') {
      return buildTxRoute(txId, from: 'people');
    } else {
      return buildTxRoute(txId, from: 'transactions');
    }
  }

  static String? getCurrentRoute() {
    if (kIsWeb) {
      final hash = WebRoutePlatform.getUrlHash();
      if (hash != null && hash.isNotEmpty) {
        return hash;
      }
      final frag = Uri.base.fragment;
      if (frag.isNotEmpty) {
        var clean = frag;
        while (clean.startsWith('#') || clean.startsWith('/')) {
          clean = clean.substring(1);
        }
        return clean;
      }
    }
    return null;
  }
}
