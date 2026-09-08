import 'dart:convert';
import '../models/app_config.dart';
import '../models/fund_data.dart';

class JsonFormatter {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Formats raw JSON string to match the exact styling of the Fund Web & App:
  /// - 2-space indentation
  /// - Flat arrays like splitAmong: ["me", "bob"] on single line
  /// - Empty arrays as []
  /// - People and BillType objects in config.json as single-line objects
  /// - Objects with simple key-value pairs formatted cleanly
  static String formatJsonStringLikeWebsite(String rawPrettyJson) {
    var jsonStr = rawPrettyJson;

    // 1. Format flat arrays (like splitAmong: ["me"]) to single line
    jsonStr = jsonStr.replaceAllMapped(
      RegExp(r'\[\n\s+([^\[\]{}]+?)\n\s+\]'),
      (match) {
        final inner = match.group(1) ?? '';
        final singleLine = inner.replaceAll(RegExp(r'\n\s+'), ' ').trim();
        return '[$singleLine]';
      },
    );

    // 2. Format empty arrays
    jsonStr = jsonStr.replaceAll(RegExp(r'\[\n\s+\]'), '[]');

    // 3. Format Person objects in config to single line: { "id": "me", "name": "Me", "active": true }
    jsonStr = jsonStr.replaceAllMapped(
      RegExp(r'\{\n\s+"id":\s*"([^"]+)",\n\s+"name":\s*"([^"]+)",\n\s+"active":\s*(true|false)\n\s+\}'),
      (match) {
        final id = match.group(1);
        final name = match.group(2);
        final active = match.group(3);
        return '{ "id": "$id", "name": "$name", "active": $active }';
      },
    );

    // 4. Format BillType objects in config to single line: { "id": "groceries", "name": "Groceries", "icon": "🛒" }
    jsonStr = jsonStr.replaceAllMapped(
      RegExp(r'\{\n\s+"id":\s*"([^"]+)",\n\s+"name":\s*"([^"]+)",\n\s+"icon":\s*"([^"]+)"\n\s+\}'),
      (match) {
        final id = match.group(1);
        final name = match.group(2);
        final icon = match.group(3);
        return '{ "id": "$id", "name": "$name", "icon": "$icon" }';
      },
    );

    // Also support any trailing active flag if reading legacy objects
    jsonStr = jsonStr.replaceAllMapped(
      RegExp(r'\{\n\s+"id":\s*"([^"]+)",\n\s+"name":\s*"([^"]+)",\n\s+"icon":\s*"([^"]+)",\n\s+"active":\s*(true|false)\n\s+\}'),
      (match) {
        final id = match.group(1);
        final name = match.group(2);
        final icon = match.group(3);
        final active = match.group(4);
        return '{ "id": "$id", "name": "$name", "icon": "$icon", "active": $active }';
      },
    );

    // 5. Format simple customSplit maps to single line: "customSplit": { "aabid": 120, "gulam": 80 }
    jsonStr = jsonStr.replaceAllMapped(
      RegExp(r'"customSplit":\s*\{\n\s+([^{}]+?)\n\s+\}'),
      (match) {
        final inner = match.group(1) ?? '';
        final singleLine = inner.replaceAll(RegExp(r'\n\s+'), ' ').trim();
        return '"customSplit": { $singleLine }';
      },
    );

    return jsonStr;
  }

  /// Formats AppConfig to pretty-printed styled JSON string
  static String formatAppConfig(AppConfig config) {
    final rawPretty = _encoder.convert(config.toJson());
    return formatJsonStringLikeWebsite(rawPretty);
  }

  /// Formats FundData to pretty-printed styled JSON string
  static String formatFundData(FundData data) {
    final rawPretty = _encoder.convert(data.toJson());
    return formatJsonStringLikeWebsite(rawPretty);
  }

  /// Formats any Map or List JSON structure
  static String formatJson(dynamic jsonObject) {
    final rawPretty = _encoder.convert(jsonObject);
    return formatJsonStringLikeWebsite(rawPretty);
  }
}
