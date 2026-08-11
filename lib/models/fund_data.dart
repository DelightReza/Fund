
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'transaction.dart';

part 'fund_data.g.dart';

@JsonSerializable()
class FundData extends Equatable {
  @JsonKey(defaultValue: {})
  final Map<String, double> people;

  @JsonKey(defaultValue: {})
  final Map<String, double> billTypes;

  @JsonKey(defaultValue: [])
  final List<Transaction> transactions;

  const FundData({
    this.people = const {},
    this.billTypes = const {},
    this.transactions = const [],
  });

  factory FundData.fromJson(Map<String, dynamic> json) =>
      _$FundDataFromJson(json);
  Map<String, dynamic> toJson() => _$FundDataToJson(this);

  FundData copyWith({
    Map<String, double>? people,
    Map<String, double>? billTypes,
    List<Transaction>? transactions,
  }) {
    return FundData(
      people: people ?? this.people,
      billTypes: billTypes ?? this.billTypes,
      transactions: transactions ?? this.transactions,
    );
  }

  @override
  List<Object?> get props => [people, billTypes, transactions];
}

