// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebPrefetchPlatform {
  static String? getPrefetchedConfigRaw() {
    try {
      // Purge any lingering global legacy keys
      html.window.localStorage.remove('fund_early_config');

      final dynamic raw = (html.window as dynamic)['__PREFETCHED_CONFIG_RAW__'];
      if (raw is String &&
          raw.isNotEmpty &&
          !raw.startsWith('<!DOCTYPE') &&
          !raw.startsWith('<html')) {
        return raw;
      }
    } catch (_) {}
    return null;
  }

  static String? getPrefetchedDataRaw() {
    try {
      // Purge any lingering global legacy keys
      html.window.localStorage.remove('fund_early_data');

      final dynamic raw = (html.window as dynamic)['__PREFETCHED_DATA_RAW__'];
      if (raw is String &&
          raw.isNotEmpty &&
          !raw.startsWith('<!DOCTYPE') &&
          !raw.startsWith('<html')) {
        return raw;
      }
    } catch (_) {}
    return null;
  }

  static void updateEarlyCache(String configRaw, String dataRaw) {
    try {
      // Clean up legacy keys
      html.window.localStorage.remove('fund_early_config');
      html.window.localStorage.remove('fund_early_data');

      if (configRaw.isNotEmpty) {
        (html.window as dynamic)['__PREFETCHED_CONFIG_RAW__'] = configRaw;
      }
      if (dataRaw.isNotEmpty) {
        (html.window as dynamic)['__PREFETCHED_DATA_RAW__'] = dataRaw;
      }
    } catch (_) {}
  }
}
