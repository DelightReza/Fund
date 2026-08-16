import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/config.dart';
import '../models/fund_data.dart';

class TokenVerificationResult {
  const TokenVerificationResult({
    required this.isVerified,
    this.adminHandle,
    this.error,
  });

  final bool isVerified;
  final String? adminHandle;
  final String? error;
}

class GitHubService {
  GitHubService({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.dataFileName,
    this.token,
  });

  final String owner;
  final String repo;
  final String branch;
  final String dataFileName;
  final String? token;

  String get _authHeaderValue {
    if (token == null || token!.trim().isEmpty) return '';
    var clean = token!.trim();
    if (clean.toLowerCase().startsWith('bearer ')) {
      clean = clean.substring(7).trim();
    } else if (clean.toLowerCase().startsWith('token ')) {
      clean = clean.substring(6).trim();
    }
    if (clean.startsWith('github_pat_')) {
      return 'Bearer $clean';
    }
    return 'token $clean';
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    final auth = _authHeaderValue;
    if (auth.isNotEmpty) {
      headers['Authorization'] = auth;
    }
    return headers;
  }

  Future<TokenVerificationResult> verifyToken(String tokenToVerify) async {
    final clean = tokenToVerify.trim();
    if (clean.isEmpty) {
      return const TokenVerificationResult(isVerified: false, error: 'Token is empty');
    }

    var cleanAuth = clean;
    if (cleanAuth.toLowerCase().startsWith('bearer ')) {
      cleanAuth = cleanAuth.substring(7).trim();
    } else if (cleanAuth.toLowerCase().startsWith('token ')) {
      cleanAuth = cleanAuth.substring(6).trim();
    }
    final authVal = cleanAuth.startsWith('github_pat_') ? 'Bearer $cleanAuth' : 'token $cleanAuth';

    try {
      final userUri = Uri.parse('https://api.github.com/user');
      final userRes = await http.get(userUri, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': authVal,
      });

      if (userRes.statusCode != 200) {
        return const TokenVerificationResult(isVerified: false, error: 'Invalid GitHub token');
      }

      final userData = jsonDecode(userRes.body) as Map<String, dynamic>;
      final adminHandle = userData['login']?.toString();

      if (owner.isNotEmpty && repo.isNotEmpty) {
        final repoUri = Uri.parse('https://api.github.com/repos/$owner/$repo');
        final repoRes = await http.get(repoUri, headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': authVal,
        });

        if (repoRes.statusCode != 200) {
          return TokenVerificationResult(
            isVerified: false,
            adminHandle: adminHandle,
            error: 'Repository not found or access denied ($owner/$repo)',
          );
        }

        final repoData = jsonDecode(repoRes.body) as Map<String, dynamic>;
        final permissions = repoData['permissions'] as Map<String, dynamic>?;
        final hasPush = permissions?['push'] == true || permissions?['admin'] == true;
        if (!hasPush) {
          return TokenVerificationResult(
            isVerified: false,
            adminHandle: adminHandle,
            error: 'Token lacks write/push permissions for $owner/$repo',
          );
        }
      }

      return TokenVerificationResult(
        isVerified: true,
        adminHandle: adminHandle,
        error: null,
      );
    } catch (e) {
      return TokenVerificationResult(
        isVerified: false,
        error: 'Network error during verification: $e',
      );
    }
  }

  Future<AppConfig> fetchConfig() async {
    if (owner.isEmpty || repo.isEmpty) {
      throw Exception('Repository not set');
    }

    if (token != null && token!.isNotEmpty) {
      try {
        final file = await _getRepoFile('config.json');
        return AppConfig.fromJson(file)
            .copyWith(repoOwner: owner, repoName: repo, repoBranch: branch, dataFileName: dataFileName);
      } catch (_) {
        // Fallback to raw below.
      }
    }

    final targetBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final uri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$targetBranch/config.json');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      // Try fallback to master branch
      if (targetBranch == 'main') {
        final masterUri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/master/config.json');
        final masterRes = await http.get(masterUri);
        if (masterRes.statusCode == 200) {
          final json = jsonDecode(masterRes.body) as Map<String, dynamic>;
          return AppConfig.fromJson(json)
              .copyWith(repoOwner: owner, repoName: repo, repoBranch: 'master', dataFileName: dataFileName);
        }
      }
      throw Exception('Failed to load config.json (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AppConfig.fromJson(json)
        .copyWith(repoOwner: owner, repoName: repo, repoBranch: branch, dataFileName: dataFileName);
  }

  Future<FundData> fetchData() async {
    if (owner.isEmpty || repo.isEmpty) {
      throw Exception('Repository not set');
    }

    if (token != null && token!.isNotEmpty) {
      try {
        final file = await _getRepoFile(dataFileName);
        return FundData.fromJson(file);
      } catch (_) {
        // Fallback to raw below.
      }
    }

    final targetBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final uri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$targetBranch/$dataFileName');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      if (targetBranch == 'main') {
        final masterUri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/master/$dataFileName');
        final masterRes = await http.get(masterUri);
        if (masterRes.statusCode == 200) {
          final json = jsonDecode(masterRes.body) as Map<String, dynamic>;
          return FundData.fromJson(json);
        }
      }
      throw Exception('Failed to load $dataFileName (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FundData.fromJson(json);
  }

  Future<AppConfig> fetchRelativeConfig() async {
    final candidates = _relativeCandidates('config.json');
    for (final uri in candidates) {
      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    throw Exception('Failed to load web config.json');
  }

  Future<FundData> fetchRelativeData(String fileName) async {
    final candidates = _relativeCandidates(fileName);
    for (final uri in candidates) {
      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          return FundData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    throw Exception('Failed to load web $fileName');
  }

  List<Uri> _relativeCandidates(String fileName) {
    final candidates = <Uri>{};
    candidates.add(Uri.base.resolve(fileName));
    candidates.add(Uri.parse('${Uri.base.origin}/$fileName'));

    final pathSegments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isNotEmpty) {
      final first = pathSegments.first;
      candidates.add(Uri.parse('${Uri.base.origin}/$first/$fileName'));
    }

    return candidates.toList();
  }

  Future<List<Map<String, dynamic>>> getCommits({int perPage = 15}) async {
    final cleanBranch = branch.trim();
    final url = cleanBranch.isNotEmpty
        ? 'https://api.github.com/repos/$owner/$repo/commits?sha=${Uri.encodeComponent(cleanBranch)}&per_page=$perPage'
        : 'https://api.github.com/repos/$owner/$repo/commits?per_page=$perPage';
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      // Fallback without sha
      if (cleanBranch.isNotEmpty) {
        final fallbackUri = Uri.parse('https://api.github.com/repos/$owner/$repo/commits?per_page=$perPage');
        final fallbackRes = await http.get(fallbackUri, headers: _headers);
        if (fallbackRes.statusCode == 200) {
          final list = jsonDecode(fallbackRes.body) as List;
          return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      throw Exception('Failed to fetch commits (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List;
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> resetToCommit(String sha) async {
    _assertToken();
    final cleanBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/git/refs/heads/${Uri.encodeComponent(cleanBranch)}');
    final response = await http.patch(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'sha': sha, 'force': true}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    // Fallback for master branch
    if (cleanBranch == 'main') {
      final masterUri = Uri.parse('https://api.github.com/repos/$owner/$repo/git/refs/heads/master');
      final masterRes = await http.patch(
        masterUri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'sha': sha, 'force': true}),
      );
      if (masterRes.statusCode >= 200 && masterRes.statusCode < 300) {
        return;
      }
    }
    throw Exception('Reset failed (${response.statusCode}): ${response.body}');
  }

  Future<void> commitConfig(AppConfig config, {required String message}) async {
    await _commitJsonFile(path: 'config.json', payload: config.toJson(), message: message);
  }

  Future<void> commitData(FundData data, {required String message}) async {
    await _commitJsonFile(path: dataFileName, payload: data.toJson(), message: message);
  }

  /// The branch to read/write via the Contents API. GitHub's Contents API
  /// silently falls back to the repo's *default* branch whenever no
  /// explicit branch/ref is given, regardless of what's configured here.
  /// Always resolve to a concrete value so reads/writes never drift onto
  /// the wrong branch.
  String get _effectiveBranch => branch.trim().isEmpty ? 'main' : branch.trim();

  Future<Map<String, dynamic>> _getRepoFile(String path) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$path'
      '?ref=${Uri.encodeQueryComponent(_effectiveBranch)}',
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Unable to fetch $path on branch $_effectiveBranch (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (body['content'] as String).replaceAll('\n', '').replaceAll('\r', '');
    final decoded = utf8.decode(base64Decode(content));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Future<String?> _getFileSha(String path) async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/contents/$path'
        '?ref=${Uri.encodeQueryComponent(_effectiveBranch)}',
      );
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['sha']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _commitJsonFile({
    required String path,
    required Map<String, dynamic> payload,
    required String message,
    int maxAttempts = 3,
  }) async {
    _assertToken();
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path');
    final targetBranch = _effectiveBranch;

    int attempt = 0;
    int backoffMs = 400;

    while (attempt < maxAttempts) {
      attempt++;
      final sha = await _getFileSha(path);
      final rawJson = const JsonEncoder.withIndent('  ').convert(payload);
      final body = <String, dynamic>{
        'message': message,
        'content': base64Encode(utf8.encode(rawJson)),
        'branch': targetBranch,
        if (sha != null && sha.isNotEmpty) 'sha': sha,
      };

      final response = await http.put(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      // Handle 409 Conflict (remote SHA changed) or 422 (stale SHA)
      if ((response.statusCode == 409 || response.statusCode == 422) && attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: backoffMs));
        backoffMs *= 2;
        continue;
      }

      if (attempt >= maxAttempts || (response.statusCode != 409 && response.statusCode != 422 && response.statusCode != 500 && response.statusCode != 502 && response.statusCode != 503)) {
        String detail = response.body;
        try {
          final errMap = jsonDecode(response.body);
          if (errMap is Map && errMap.containsKey('message')) {
            detail = errMap['message'].toString();
          }
        } catch (_) {}
        throw Exception('GitHub commit failed for $path (status ${response.statusCode}): $detail');
      }
    }
  }

  void _assertToken() {
    if (token == null || token!.trim().isEmpty) {
      throw Exception('PAT required for write operations');
    }
  }
}
