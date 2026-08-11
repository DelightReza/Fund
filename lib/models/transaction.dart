import '../utils/date_utils.dart';

enum TransactionType {
  expense,
  credit,
  debit,
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
    required this.amount,
    required this.timestamp,
    this.note = '',
    this.actorId,
    this.targetId,
    this.participantIds = const [],
    this.exemptions = const [],
    this.parentId,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String timestamp;
  final String note;
  final String? actorId;
  final String? targetId;
  final List<String> participantIds;
  final List<String> exemptions;
  final String? parentId;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final parsedType = TransactionType.parse((json['type'] ?? 'debit').toString());
    final split = (json['participantIds'] ?? json['splitAmong']) as List?;
    final ex = (json['exemptions']) as List?;

    String? legacyActor;
    String? legacyTarget;
    if (parsedType == TransactionType.credit ||
        parsedType == TransactionType.transfer ||
        parsedType == TransactionType.settlement) {
      legacyActor = (json['payerId'] ?? json['whoOrBill'])?.toString();
    }
    if (parsedType == TransactionType.debit || parsedType == TransactionType.expense) {
      legacyTarget = (json['billTypeId'] ?? json['whoOrBill'])?.toString();
    }

    return Transaction(
      id: (json['id'] ?? AppDateUtils.generateId()).toString(),
      type: parsedType,
      amount: _toDouble(json['amount']),
      timestamp: (json['timestamp'] ?? json['date'] ?? AppDateUtils.nowIso()).toString(),
      note: (json['note'] ?? '').toString(),
      actorId: (json['actorId'] ?? legacyActor)?.toString(),
      targetId: (json['targetId'] ?? legacyTarget)?.toString(),
      participantIds: split == null ? const [] : split.map((e) => e.toString()).toList(),
      exemptions: ex == null ? const [] : ex.map((e) => e.toString()).toList(),
      parentId: json['parentId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final whoOrBill = switch (type) {
      TransactionType.credit || TransactionType.transfer || TransactionType.settlement => actorId,
      _ => targetId,
    };

    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'timestamp': timestamp,
      'date': timestamp,
      'note': note,
      'actorId': actorId,
      'targetId': targetId,
      'participantIds': participantIds,
      'splitAmong': participantIds,
      'exemptions': exemptions,
      'parentId': parentId,
      'payerId': actorId,
      'billTypeId': targetId,
      'whoOrBill': whoOrBill,
    };
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? timestamp,
    String? note,
    String? actorId,
    String? targetId,
    List<String>? participantIds,
    List<String>? exemptions,
    String? parentId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      actorId: actorId ?? this.actorId,
      targetId: targetId ?? this.targetId,
      participantIds: participantIds ?? this.participantIds,
      exemptions: exemptions ?? this.exemptions,
      parentId: parentId ?? this.parentId,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
