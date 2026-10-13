import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_prefetch_stub.dart' if (dart.library.html) 'web_prefetch_web.dart';

class WebPrefetchHelper {
  static String? getPrefetchedConfigRaw() {
    if (!kIsWeb) return null;
    return WebPrefetchPlatform.getPrefetchedConfigRaw();
  }

  static String? getPrefetchedDataRaw() {
    if (!kIsWeb) return null;
    return WebPrefetchPlatform.getPrefetchedDataRaw();
  }

  static void updateEarlyCache(String configRaw, String dataRaw) {
    if (!kIsWeb) return;
    WebPrefetchPlatform.updateEarlyCache(configRaw, dataRaw);
  }
}
