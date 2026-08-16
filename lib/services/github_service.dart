import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/config.dart';
import '../models/fund_data.dart';

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

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<bool> verifyToken(String tokenToVerify) async {
    final uri = owner.isNotEmpty && repo.isNotEmpty
        ? Uri.parse('https://api.github.com/repos/$owner/$repo')
        : Uri.parse('https://api.github.com/user');
    
    final response = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Authorization': 'Bearer $tokenToVerify',
    });
    
    return response.statusCode == 200;
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

    final uri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$branch/config.json');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
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

    final uri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$branch/$dataFileName');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load $dataFileName (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FundData.fromJson(json);
  }

  Future<AppConfig> fetchRelativeConfig() async {
    final candidates = _relativeCandidates('config.json');
    for (final uri in candidates) {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    }
    throw Exception('Failed to load web config.json');
  }

  Future<FundData> fetchRelativeData(String fileName) async {
    final candidates = _relativeCandidates(fileName);
    for (final uri in candidates) {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return FundData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
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

  Future<List<Map<String, dynamic>>> getCommits({int perPage = 20}) async {
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/commits?sha=$branch&per_page=$perPage');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch commits (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List;
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> resetToCommit(String sha) async {
    _assertToken();
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/git/refs/heads/$branch');
    final response = await http.patch(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'sha': sha, 'force': true}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Reset failed (${response.statusCode})');
    }
  }

  Future<void> commitConfig(AppConfig config, {required String message}) async {
    await _commitJsonFile(path: 'config.json', payload: config.toJson(), message: message);
  }

  Future<void> commitData(FundData data, {required String message}) async {
    await _commitJsonFile(path: dataFileName, payload: data.toJson(), message: message);
  }

  Future<Map<String, dynamic>> _getRepoFile(String path) async {
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Unable to fetch $path (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (body['content'] as String).replaceAll('\n', '');
    final decoded = utf8.decode(base64Decode(content));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Future<String?> _getFileSha(String path) async {
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['sha']?.toString();
  }

  Future<void> _commitJsonFile({
    required String path,
    required Map<String, dynamic> payload,
    required String message,
    int maxAttempts = 3,
  }) async {
    _assertToken();
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path');

    int attempt = 0;
    int backoffMs = 400;

    while (attempt < maxAttempts) {
      attempt++;
      final sha = await _getFileSha(path);
      final rawJson = const JsonEncoder.withIndent('  ').convert(payload);
      final body = <String, dynamic>{
        'message': message,
        'content': base64Encode(utf8.encode(rawJson)),
        if (branch.isNotEmpty) 'branch': branch,
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

      // Handle 409 Conflict (remote SHA changed) or 422
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
        throw Exception('Commit failed for $path (${response.statusCode}): $detail');
      }
    }
  }

  void _assertToken() {
    if (token == null || token!.isEmpty) {
      throw Exception('PAT required for write operations');
    }
  }
}
