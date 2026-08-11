
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/config.dart';
import '../models/fund_data.dart';

class GitHubService {
  final String owner;
  final String repo;
  final String? token;
  final String branch;
  final String dataFileName;

  GitHubService({
    required this.owner,
    required this.repo,
    this.token,
    this.branch = 'main',
    this.dataFileName = 'data.json',
  });

  Map<String, String> get _headers {
    final headers = {'Accept': 'application/vnd.github.v3+json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _getFile(String path) async {
    final url =
        'https://api.github.com/repos/$owner/$repo/contents/$path';
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch $path: ${response.statusCode}');
    }
  }

  Future<AppConfig> fetchConfig() async {
    final data = await _getFile('config.json');
    final content = base64Decode(data['content'] as String);
    final json = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
    return AppConfig.fromJson(json);
  }

  Future<FundData> fetchData() async {
    final data = await _getFile(dataFileName);
    final content = base64Decode(data['content'] as String);
    final json = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
    return FundData.fromJson(json);
  }

  Future<void> commitFile(
    String path,
    String content,
    String message, {
    String? sha,
  }) async {
    final url = 'https://api.github.com/repos/$owner/$repo/contents/$path';
    final body = jsonEncode({
      'message': message,
      'content': base64Encode(utf8.encode(content)),
      'sha': sha,
    });
    final response = await http.put(
      Uri.parse(url),
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to commit $path: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> commitConfig(AppConfig config, String message) async {
    final sha = await _getSha('config.json');
    final json = jsonEncode(config.toJson());
    await commitFile('config.json', json, message, sha: sha);
  }

  Future<void> commitData(FundData data, String message) async {
    final sha = await _getSha(dataFileName);
    final json = jsonEncode(data.toJson());
    await commitFile(dataFileName, json, message, sha: sha);
  }

  Future<List<Map<String, dynamic>>> getCommits({int perPage = 15}) async {
    final url =
        'https://api.github.com/repos/$owner/$repo/commits?sha=$branch&per_page=$perPage';
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to fetch commits: ${response.statusCode}');
    }
  }

  Future<void> resetToCommit(String sha) async {
    final url =
        'https://api.github.com/repos/$owner/$repo/git/refs/heads/$branch';
    final body = jsonEncode({'sha': sha, 'force': true});
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to reset: ${response.statusCode}');
    }
  }

  Future<String?> _getSha(String path) async {
    try {
      final data = await _getFile(path);
      return data['sha'] as String?;
    } catch (_) {
      return null;
    }
  }

  // For fallback raw URLs
  static Future<AppConfig> fetchConfigRaw(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return AppConfig.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to fetch raw config: ${response.statusCode}');
    }
  }

  static Future<FundData> fetchDataRaw(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return FundData.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to fetch raw data: ${response.statusCode}');
    }
  }
}

