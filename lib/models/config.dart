class MemberConfig {
  const MemberConfig({
    required this.id,
    required this.name,
    this.active = true,
  });

  final String id;
  final String name;
  final bool active;

  factory MemberConfig.fromJson(Map<String, dynamic> json) {
    return MemberConfig(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      active: json['active'] is bool ? json['active'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'active': active,
      };

  MemberConfig copyWith({String? id, String? name, bool? active}) {
    return MemberConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
    );
  }
}

class BillTypeConfig {
  const BillTypeConfig({
    required this.id,
    required this.name,
    this.icon = '🧾',
    this.active = true,
  });

  final String id;
  final String name;
  final String icon;
  final bool active;

  factory BillTypeConfig.fromJson(Map<String, dynamic> json) {
    return BillTypeConfig(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '🧾').toString(),
      active: json['active'] is bool ? json['active'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'active': active,
      };

  BillTypeConfig copyWith({String? id, String? name, String? icon, bool? active}) {
    return BillTypeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      active: active ?? this.active,
    );
  }
}

class AppConfig {
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

  final String siteTitle;
  final String siteSubtitle;
  final String currency;
  final String repoOwner;
  final String repoName;
  final String repoBranch;
  final String dataFileName;
  final List<MemberConfig> people;
  final List<BillTypeConfig> billTypes;

  bool get hasRepository => repoOwner.isNotEmpty && repoName.isNotEmpty;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    List<MemberConfig> parsePeople(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => MemberConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (raw is Map) {
        return raw.entries.map((entry) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is Map) {
            final json = Map<String, dynamic>.from(value);
            return MemberConfig.fromJson({
              ...json,
              if ((json['id'] ?? '').toString().isEmpty) 'id': key,
              if ((json['name'] ?? '').toString().isEmpty) 'name': key,
            });
          }
          return MemberConfig(id: key, name: value?.toString() ?? key);
        }).toList();
      }
      return const [];
    }

    List<BillTypeConfig> parseBillTypes(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => BillTypeConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (raw is Map) {
        return raw.entries.map((entry) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is Map) {
            final json = Map<String, dynamic>.from(value);
            return BillTypeConfig.fromJson({
              ...json,
              if ((json['id'] ?? '').toString().isEmpty) 'id': key,
              if ((json['name'] ?? '').toString().isEmpty) 'name': key,
            });
          }
          return BillTypeConfig(id: key, name: value?.toString() ?? key);
        }).toList();
      }
      return const [];
    }

    return AppConfig(
      siteTitle: (json['siteTitle'] ?? json['site_title'] ?? 'Fund').toString(),
      siteSubtitle: (json['siteSubtitle'] ?? json['site_subtitle'] ?? 'Expense Tracker').toString(),
      currency: (json['currency'] ?? json['currency_symbol'] ?? '₹').toString(),
      repoOwner: (json['repoOwner'] ?? json['repo_owner'] ?? '').toString(),
      repoName: (json['repoName'] ?? json['repo_name'] ?? '').toString(),
      repoBranch: (json['repoBranch'] ?? json['repo_branch'] ?? 'main').toString(),
      dataFileName: (json['dataFileName'] ?? json['data_file_name'] ?? 'data.json').toString(),
      people: parsePeople(json['people']),
      billTypes: parseBillTypes(json['billTypes'] ?? json['bill_types']),
    );
  }

  Map<String, dynamic> toJson() => {
        'siteTitle': siteTitle,
        'siteSubtitle': siteSubtitle,
        'currency': currency,
        'repoOwner': repoOwner,
        'repoName': repoName,
        'repoBranch': repoBranch,
        'dataFileName': dataFileName,
        'people': people.map((p) => p.toJson()).toList(),
        'billTypes': billTypes.map((b) => b.toJson()).toList(),
      };

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
}
