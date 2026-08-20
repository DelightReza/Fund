import '../utils/date_utils.dart';

enum TransactionType {
  credit,
  debit,
  expense,
  distribution,
  settlement,
  transfer;

  static TransactionType parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    return TransactionType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => TransactionType.debit,
    );
  }
}

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.whoOrBill,
    required this.amount,
    this.note = '',
    required this.date,
    this.splitAmong,
    this.exemptions,
    this.parentId,
    this.distributionTotal,
    // Optional compatibility helpers:
    this.payerId,
    this.billTypeId,
  });

  final String id;
  final TransactionType type;
  final String whoOrBill;
  final double amount;
  final String note;
  final String date;
  final List<String>? splitAmong;
  final List<String>? exemptions;
  final String? parentId;
  final double? distributionTotal;
  final String? payerId;
  final String? billTypeId;

  bool get isCredit => type == TransactionType.credit;
  bool get isDebit => type == TransactionType.debit;
  bool get isExpense => type == TransactionType.expense || (parentId != null && parentId!.startsWith('tx_exp'));

  String? get actorId => isCredit ? whoOrBill : (payerId ?? (type == TransactionType.expense ? whoOrBill : null));
  String? get targetId => isDebit ? whoOrBill : (billTypeId ?? (type == TransactionType.expense ? whoOrBill : null));
  String get timestamp => date;
  List<String> get participantIds => splitAmong ?? const [];

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? 'debit').toString().toLowerCase().trim();
    final parsedType = switch (rawType) {
      'credit' => TransactionType.credit,
      'debit' => TransactionType.debit,
      'expense' => TransactionType.expense,
      'distribution' => TransactionType.distribution,
      'settlement' => TransactionType.settlement,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.debit,
    };

    final who = (json['whoOrBill'] ?? json['payerId'] ?? json['billTypeId'] ?? json['actorId'] ?? json['targetId'] ?? '').toString();
    final date = (json['date'] ?? json['timestamp'] ?? AppDateUtils.nowIso()).toString();

    List<String>? split;
    if (json['splitAmong'] is List) {
      split = (json['splitAmong'] as List).map((e) => e.toString()).toList();
    } else if (json['participantIds'] is List) {
      split = (json['participantIds'] as List).map((e) => e.toString()).toList();
    }

    List<String>? ex;
    if (json['exemptions'] is List) {
      ex = (json['exemptions'] as List).map((e) => e.toString()).toList();
    }

    return Transaction(
      id: (json['id'] ?? AppDateUtils.generateId()).toString(),
      type: parsedType,
      whoOrBill: who,
      amount: _toDouble(json['amount']),
      note: (json['note'] ?? '').toString(),
      date: date,
      splitAmong: split,
      exemptions: ex,
      parentId: json['parentId']?.toString(),
      distributionTotal: json['distributionTotal'] != null ? _toDouble(json['distributionTotal']) : null,
      payerId: json['payerId']?.toString(),
      billTypeId: json['billTypeId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    // Only standard keys from the original contract
    final normalizedType = (type == TransactionType.expense || type == TransactionType.debit) ? 'debit' : 'credit';
    final effectiveWho = whoOrBill.isNotEmpty
        ? whoOrBill
        : (normalizedType == 'credit' ? (payerId ?? '') : (billTypeId ?? ''));

    final num formattedAmount = (amount % 1.0 == 0.0)
        ? amount.toInt()
        : double.parse(amount.toStringAsFixed(2));

    final map = <String, dynamic>{
      'id': id,
      if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
      'type': normalizedType,
      'whoOrBill': effectiveWho,
      'amount': formattedAmount,
      'note': note,
      'date': date,
    };

    if (splitAmong != null && splitAmong!.isNotEmpty) {
      map['splitAmong'] = splitAmong;
    } else if (exemptions != null && exemptions!.isNotEmpty) {
      map['exemptions'] = exemptions;
    }

    if (distributionTotal != null) {
      final num formattedTotal = (distributionTotal! % 1.0 == 0.0)
          ? distributionTotal!.toInt()
          : double.parse(distributionTotal!.toStringAsFixed(2));
      map['distributionTotal'] = formattedTotal;
    }

    return map;
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? whoOrBill,
    double? amount,
    String? note,
    String? date,
    List<String>? splitAmong,
    List<String>? exemptions,
    String? parentId,
    double? distributionTotal,
    String? payerId,
    String? billTypeId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      whoOrBill: whoOrBill ?? this.whoOrBill,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      splitAmong: splitAmong ?? this.splitAmong,
      exemptions: exemptions ?? this.exemptions,
      parentId: parentId ?? this.parentId,
      distributionTotal: distributionTotal ?? this.distributionTotal,
      payerId: payerId ?? this.payerId,
      billTypeId: billTypeId ?? this.billTypeId,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }
}
