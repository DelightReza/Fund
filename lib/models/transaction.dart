
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'transaction.g.dart';

@JsonSerializable()
class Transaction extends Equatable {
  final String id;
  final String type; // 'credit' or 'debit'
  @JsonKey(includeIfNull: false)
  final String? payerId;
  @JsonKey(includeIfNull: false)
  final String? billTypeId;
  @JsonKey(includeIfNull: false)
  final List<String>? splitAmong;
  final String whoOrBill;
  final String note;
  final double amount;
  final String date;
  @JsonKey(includeIfNull: false)
  final List<String>? exemptions;
  @JsonKey(includeIfNull: false)
  final String? parentId;
  @JsonKey(includeIfNull: false)
  final double? distributionTotal;

  const Transaction({
    required this.id,
    required this.type,
    this.payerId,
    this.billTypeId,
    this.splitAmong,
    required this.whoOrBill,
    this.note = '',
    required this.amount,
    required this.date,
    this.exemptions,
    this.parentId,
    this.distributionTotal,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  Transaction copyWith({
    String? id,
    String? type,
    String? payerId,
    String? billTypeId,
    List<String>? splitAmong,
    String? whoOrBill,
    String? note,
    double? amount,
    String? date,
    List<String>? exemptions,
    String? parentId,
    double? distributionTotal,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      payerId: payerId ?? this.payerId,
      billTypeId: billTypeId ?? this.billTypeId,
      splitAmong: splitAmong ?? this.splitAmong,
      whoOrBill: whoOrBill ?? this.whoOrBill,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      exemptions: exemptions ?? this.exemptions,
      parentId: parentId ?? this.parentId,
      distributionTotal: distributionTotal ?? this.distributionTotal,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        payerId,
        billTypeId,
        splitAmong,
        whoOrBill,
        note,
        amount,
        date,
        exemptions,
        parentId,
        distributionTotal,
      ];
}

