class SavedRepo {
  const SavedRepo({
    required this.id,
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.dataFileName = 'data.json',
    this.title = '',
    this.token,
  });

  final String id;
  final String owner;
  final String repo;
  final String branch;
  final String dataFileName;
  final String title;
  final String? token;

  String get displayTitle => title.isNotEmpty ? title : '$owner/$repo';

  bool get hasToken => token != null && token!.isNotEmpty;

  factory SavedRepo.fromJson(Map<String, dynamic> json) {
    final owner = (json['owner'] ?? '').toString();
    final repo = (json['repo'] ?? '').toString();
    final branch = (json['branch'] ?? 'main').toString();
    final dataFileName = (json['dataFileName'] ?? 'data.json').toString();
    final id = (json['id'] ?? '$owner/$repo').toString();

    return SavedRepo(
      id: id.isNotEmpty ? id : '$owner/$repo',
      owner: owner,
      repo: repo,
      branch: branch,
      dataFileName: dataFileName,
      title: (json['title'] ?? '').toString(),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'dataFileName': dataFileName,
        'title': title,
        'token': token,
      };

  SavedRepo copyWith({
    String? id,
    String? owner,
    String? repo,
    String? branch,
    String? dataFileName,
    String? title,
    String? token,
  }) {
    return SavedRepo(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      dataFileName: dataFileName ?? this.dataFileName,
      title: title ?? this.title,
      token: token ?? this.token,
    );
  }
}
