import 'transaction.dart';

class FundData {
  const FundData({
    this.billTypes = const {},
    this.people = const {},
    this.transactions = const [],
  });

  final Map<String, double> billTypes;
  final Map<String, double> people;
  final List<Transaction> transactions;

  factory FundData.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];
    final txs = rawTransactions is List
        ? rawTransactions
            .whereType<Map>()
            .map((entry) => Transaction.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <Transaction>[];

    Map<String, double> parseMap(dynamic raw) {
      if (raw is! Map) return {};
      final map = <String, double>{};
      for (final entry in raw.entries) {
        map[entry.key.toString()] = _toDouble(entry.value);
      }
      return map;
    }

    return FundData(
      billTypes: parseMap(json['billTypes']),
      people: parseMap(json['people']),
      transactions: txs,
    );
  }

  Map<String, dynamic> toJson() {
    final bMap = <String, dynamic>{};
    billTypes.forEach((k, v) {
      bMap[k] = (v % 1.0 == 0.0) ? v.toInt() : double.parse(v.toStringAsFixed(2));
    });

    final pMap = <String, dynamic>{};
    people.forEach((k, v) {
      pMap[k] = (v % 1.0 == 0.0) ? v.toInt() : double.parse(v.toStringAsFixed(2));
    });

    return {
      'billTypes': bMap,
      'people': pMap,
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }

  FundData copyWith({
    Map<String, double>? billTypes,
    Map<String, double>? people,
    List<Transaction>? transactions,
  }) {
    return FundData(
      billTypes: billTypes ?? this.billTypes,
      people: people ?? this.people,
      transactions: transactions ?? this.transactions,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }
}
