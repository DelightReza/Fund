class GitHubCommit {
  final String sha;
  final String message;
  final String authorName;
  final String date;

  GitHubCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    required this.date,
  });

  factory GitHubCommit.fromJson(Map<String, dynamic> json) {
    final commitObj = json['commit'] as Map<String, dynamic>? ?? {};
    final authorObj = commitObj['author'] as Map<String, dynamic>? ?? {};
    final message = commitObj['message']?.toString() ?? '';
    final authorName = authorObj['name']?.toString() ?? '';
    final date = authorObj['date']?.toString() ?? '';
    final sha = json['sha']?.toString() ?? '';

    return GitHubCommit(
      sha: sha,
      message: message,
      authorName: authorName,
      date: date,
    );
  }
}

class SavedWorkspace {
  final String owner;
  final String repo;
  final String? title;
  final String? token;
  final DateTime lastAccessed;

  SavedWorkspace({
    required this.owner,
    required this.repo,
    this.title,
    this.token,
    required this.lastAccessed,
  });

  factory SavedWorkspace.fromJson(Map<String, dynamic> json) {
    return SavedWorkspace(
      owner: json['owner']?.toString() ?? '',
      repo: json['repo']?.toString() ?? '',
      title: json['title']?.toString(),
      token: json['token']?.toString(),
      lastAccessed: DateTime.tryParse(json['lastAccessed']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'repo': repo,
        'title': title,
        'token': token,
        'lastAccessed': lastAccessed.toIso8601String(),
      };
}
