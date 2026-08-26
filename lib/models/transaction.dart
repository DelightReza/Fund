class TransactionModel {
  final String id;
  final String type; // 'credit' | 'debit'
  final String? payerId;
  final String? billTypeId;
  final List<String>? splitAmong;
  final List<String>? exemptions;
  final String whoOrBill;
  final String note;
  final double amount;
  final String date;
  final String? parentId;
  final double? distributionTotal;

  TransactionModel({
    required this.id,
    required this.type,
    this.payerId,
    this.billTypeId,
    this.splitAmong,
    this.exemptions,
    required this.whoOrBill,
    required this.note,
    required this.amount,
    required this.date,
    this.parentId,
    this.distributionTotal,
  });

  TransactionModel copyWith({
    String? id,
    String? type,
    String? payerId,
    String? billTypeId,
    List<String>? splitAmong,
    List<String>? exemptions,
    String? whoOrBill,
    String? note,
    double? amount,
    String? date,
    String? parentId,
    double? distributionTotal,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      payerId: payerId ?? this.payerId,
      billTypeId: billTypeId ?? this.billTypeId,
      splitAmong: splitAmong ?? this.splitAmong,
      exemptions: exemptions ?? this.exemptions,
      whoOrBill: whoOrBill ?? this.whoOrBill,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      parentId: parentId ?? this.parentId,
      distributionTotal: distributionTotal ?? this.distributionTotal,
    );
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final double parsedAmount = rawAmount is num ? rawAmount.toDouble() : 0.0;

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      payerId: json['payerId']?.toString(),
      billTypeId: json['billTypeId']?.toString(),
      splitAmong: (json['splitAmong'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      exemptions: (json['exemptions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      whoOrBill: json['whoOrBill']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      amount: parsedAmount,
      date: json['date']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      distributionTotal: json['distributionTotal'] != null
          ? (json['distributionTotal'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
      'type': type,
      'whoOrBill': whoOrBill.isNotEmpty
          ? whoOrBill
          : (type == 'credit' ? (payerId ?? '') : (billTypeId ?? '')),
      'amount': amount % 1.0 == 0.0 ? amount.toInt() : amount,
      'note': note,
      'date': date,
    };

    if (splitAmong != null && splitAmong!.isNotEmpty) {
      map['splitAmong'] = splitAmong;
    }
    if ((splitAmong == null || splitAmong!.isEmpty) &&
        exemptions != null &&
        exemptions!.isNotEmpty) {
      map['exemptions'] = exemptions;
    }
    if (distributionTotal != null) {
      map['distributionTotal'] = distributionTotal;
    }
    return map;
  }
}
