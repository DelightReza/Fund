// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebPrefetchPlatform {
  static String? getPrefetchedConfigRaw() {
    try {
      final dynamic raw = (html.window as dynamic)['__PREFETCHED_CONFIG_RAW__'];
      if (raw is String && raw.isNotEmpty && !raw.startsWith('<!DOCTYPE') && !raw.startsWith('<html')) {
        return raw;
      }
      final cached = html.window.localStorage['fund_early_config'];
      if (cached != null && cached.isNotEmpty && !cached.startsWith('<!DOCTYPE') && !cached.startsWith('<html')) {
        return cached;
      }
    } catch (_) {}
    return null;
  }

  static String? getPrefetchedDataRaw() {
    try {
      final dynamic raw = (html.window as dynamic)['__PREFETCHED_DATA_RAW__'];
      if (raw is String && raw.isNotEmpty && !raw.startsWith('<!DOCTYPE') && !raw.startsWith('<html')) {
        return raw;
      }
      final cached = html.window.localStorage['fund_early_data'];
      if (cached != null && cached.isNotEmpty && !cached.startsWith('<!DOCTYPE') && !cached.startsWith('<html')) {
        return cached;
      }
    } catch (_) {}
    return null;
  }

  static void updateEarlyCache(String configRaw, String dataRaw) {
    try {
      if (configRaw.isNotEmpty) {
        html.window.localStorage['fund_early_config'] = configRaw;
        (html.window as dynamic)['__PREFETCHED_CONFIG_RAW__'] = configRaw;
      }
      if (dataRaw.isNotEmpty) {
        html.window.localStorage['fund_early_data'] = dataRaw;
        (html.window as dynamic)['__PREFETCHED_DATA_RAW__'] = dataRaw;
      }
    } catch (_) {}
  }
}
