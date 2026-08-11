import 'dart:convert';

class JsonUtils {
  static String pretty(dynamic input) => const JsonEncoder.withIndent('  ').convert(input);
}
