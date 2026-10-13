class MemberConfig {
  final String id;
  final String name;
  final bool active;

  MemberConfig({
    required this.id,
    required this.name,
    this.active = true,
  });

  factory MemberConfig.fromJson(dynamic json) {
    if (json is String) {
      return MemberConfig(id: json, name: json, active: true);
    }
    if (json is Map<String, dynamic>) {
      return MemberConfig(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['id']?.toString() ?? '',
        active: json['active'] as bool? ?? true,
      );
    }
    return MemberConfig(id: '', name: '', active: true);
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
  final String id;
  final String name;
  final String icon;
  final bool active;

  BillTypeConfig({
    required this.id,
    required this.name,
    this.icon = '🧾',
    this.active = true,
  });

  factory BillTypeConfig.fromJson(dynamic json) {
    if (json is String) {
      return BillTypeConfig(id: json, name: json, icon: '🧾', active: true);
    }
    if (json is Map<String, dynamic>) {
      return BillTypeConfig(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['id']?.toString() ?? '',
        icon: json['icon']?.toString() ?? '🧾',
        active: json['active'] as bool? ?? true,
      );
    }
    return BillTypeConfig(id: '', name: '', icon: '🧾', active: true);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
      };

  BillTypeConfig copyWith(
      {String? id, String? name, String? icon, bool? active}) {
    return BillTypeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      active: active ?? this.active,
    );
  }
}

class AppConfig {
  final String siteTitle;
  final String siteSubtitle;
  final String currency;
  final String repoOwner;
  final String repoName;
  final String repoBranch;
  final String dataFileName;
  final List<MemberConfig> members;
  final List<BillTypeConfig> billTypes;

  AppConfig({
    this.siteTitle = 'Fund',
    this.siteSubtitle = 'Expense Tracker',
    this.currency = '₹',
    this.repoOwner = '',
    this.repoName = '',
    this.repoBranch = 'main',
    this.dataFileName = 'data.json',
    this.members = const [],
    this.billTypes = const [],
  });

  AppConfig copyWith({
    String? siteTitle,
    String? siteSubtitle,
    String? currency,
    String? repoOwner,
    String? repoName,
    String? repoBranch,
    String? dataFileName,
    List<MemberConfig>? members,
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
      members: members ?? this.members,
      billTypes: billTypes ?? this.billTypes,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawPeople = json['people'] ?? json['members'];
    final rawBillTypes = json['billTypes'] ?? json['categories'];

    List<MemberConfig> membersList = [];
    if (rawPeople is List) {
      membersList = rawPeople
          .where((m) => m != null)
          .map((m) => MemberConfig.fromJson(m))
          .where((m) => m.id.isNotEmpty || m.name.isNotEmpty)
          .toList();
    }

    List<BillTypeConfig> billTypesList = [];
    if (rawBillTypes is List) {
      billTypesList = rawBillTypes
          .where((b) => b != null)
          .map((b) => BillTypeConfig.fromJson(b))
          .where((b) => b.id.isNotEmpty || b.name.isNotEmpty)
          .toList();
    }

    return AppConfig(
      siteTitle: json['siteTitle']?.toString() ?? 'Fund',
      siteSubtitle: json['siteSubtitle']?.toString() ?? 'Expense Tracker',
      currency: json['currency']?.toString() ?? '₹',
      repoOwner: json['repoOwner']?.toString() ?? '',
      repoName: json['repoName']?.toString() ?? '',
      repoBranch: json['repoBranch']?.toString() ?? 'main',
      dataFileName: json['dataFileName']?.toString() ?? 'data.json',
      members: membersList,
      billTypes: billTypesList,
    );
  }

  bool get hasRepository =>
      repoOwner.trim().isNotEmpty && repoName.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'siteTitle': siteTitle,
        'siteSubtitle': siteSubtitle,
        'currency': currency,
        if (repoOwner.isNotEmpty) 'repoOwner': repoOwner,
        if (repoName.isNotEmpty) 'repoName': repoName,
        'repoBranch': repoBranch,
        'dataFileName': dataFileName,
        'people': members.map((m) => m.toJson()).toList(),
        'billTypes': billTypes.map((b) => b.toJson()).toList(),
      };
}
