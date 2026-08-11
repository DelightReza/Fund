
import 'dart:convert';

class JsonUtils {
  static String prettyJson(dynamic object) {
    return const JsonEncoder.withIndent('  ').convert(object);
  }
}

