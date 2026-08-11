
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'config.g.dart';

@JsonSerializable()
class MemberConfig extends Equatable {
  final String id;
  final String name;
  final bool active;

  const MemberConfig({
    required this.id,
    required this.name,
    this.active = true,
  });

  factory MemberConfig.fromJson(Map<String, dynamic> json) =>
      _$MemberConfigFromJson(json);
  Map<String, dynamic> toJson() => _$MemberConfigToJson(this);

  MemberConfig copyWith({String? id, String? name, bool? active}) {
    return MemberConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
    );
  }

  @override
  List<Object?> get props => [id, name, active];
}

@JsonSerializable()
class BillTypeConfig extends Equatable {
  final String id;
  final String name;
  final String icon;

  const BillTypeConfig({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory BillTypeConfig.fromJson(Map<String, dynamic> json) =>
      _$BillTypeConfigFromJson(json);
  Map<String, dynamic> toJson() => _$BillTypeConfigToJson(this);

  BillTypeConfig copyWith({String? id, String? name, String? icon}) {
    return BillTypeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
    );
  }

  @override
  List<Object?> get props => [id, name, icon];
}

@JsonSerializable()
class AppConfig extends Equatable {
  final String siteTitle;
  final String siteSubtitle;
  final String currency;
  final String repoOwner;
  final String repoName;
  final String repoBranch;
  final String dataFileName;
  final List<MemberConfig> people;
  final List<BillTypeConfig> billTypes;

  const AppConfig({
    this.siteTitle = 'Fund',
    this.siteSubtitle = 'Expense Tracker',
    this.currency = '₹',
    this.repoOwner = '',
    this.repoName = '',
    this.repoBranch = 'main',
    this.dataFileName = 'data.json',
    this.people = const [],
    this.billTypes = const [],
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    String? siteTitle,
    String? siteSubtitle,
    String? currency,
    String? repoOwner,
    String? repoName,
    String? repoBranch,
    String? dataFileName,
    List<MemberConfig>? people,
    List<BillTypeConfig>? billTypes,
  }) {
    return AppConfig(
      siteTitle: siteTitle ?? this.siteTitle,
      siteSubtitle: siteSubtitle ?? this.siteSubtitle,
      currency: currency ?? this.currency,
      repoOwner: repoOwner ?? this.repoOwner,
      repoName: repoName ?? this.repoName,
      repoBranch: repoBranch ?? this.repoBranch,
      dataFileName: dataFileName ?? this.dataFileName,
      people: people ?? this.people,
      billTypes: billTypes ?? this.billTypes,
    );
  }

  @override
  List<Object?> get props => [
        siteTitle,
        siteSubtitle,
        currency,
        repoOwner,
        repoName,
        repoBranch,
        dataFileName,
        people,
        billTypes,
      ];
}

