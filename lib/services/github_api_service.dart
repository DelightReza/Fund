import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/github_models.dart';

class GitHubFileResponse {
  final String sha;
  final String content;

  GitHubFileResponse({required this.sha, required this.content});
}

class GitHubUpdateResult {
  final bool isSuccess;
  final int statusCode;
  final String? newSha;
  final String? errorMessage;

  GitHubUpdateResult({
    required this.isSuccess,
    required this.statusCode,
    this.newSha,
    this.errorMessage,
  });

  bool get isConflict => statusCode == 409 || statusCode == 422;
}

class GitHubApiResult<T> {
  final T? data;
  final int statusCode;
  final String? errorMessage;

  GitHubApiResult({this.data, required this.statusCode, this.errorMessage});

  bool get isSuccess => data != null && statusCode >= 200 && statusCode < 300;
}

class GitHubApiService {
  static const String baseUrl = 'https://api.github.com';

  static String formatAuthHeader(String token) {
    final t = token.trim();
    if (t.isEmpty) return '';
    final lower = t.toLowerCase();
    if (lower.startsWith('token ') || lower.startsWith('bearer ')) {
      return t;
    }
    // 'Bearer' is supported by all modern GitHub tokens (ghp_, github_pat_, etc.)
    return 'Bearer $t';
  }

  static String _encodeContentPath(String path) {
    return path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }

  static Map<String, String> buildHeaders({String? token, String? accept}) {
    final headers = <String, String>{
      'Accept': accept ?? 'application/vnd.github.v3+json',
    };
    // Note: Setting User-Agent header in browser/web environment is forbidden and causes fetch rejections
    if (!kIsWeb) {
      headers['User-Agent'] = 'Fund-Expense-Tracker/1.0';
    }
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = formatAuthHeader(token);
    }
    return headers;
  }

  /// Verifies if a Personal Access Token has write/read access to the repository
  Future<bool> verifyRepoAccess({
    required String token,
    required String owner,
    required String repo,
  }) async {
    if (token.trim().isEmpty || owner.trim().isEmpty || repo.trim().isEmpty) {
      return false;
    }

    try {
      final url = Uri.parse('$baseUrl/repos/$owner/$repo');
      final headers = buildHeaders(token: token);

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map) {
          final permissions = json['permissions'];
          if (permissions is Map) {
            final push =
                permissions['push'] == true || permissions['admin'] == true;
            return push;
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches relative file directly on Web deployment
  Future<String?> fetchRelativeFile(String path) async {
    try {
      final uri =
          Uri.base.resolve('$path?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        // Ensure response is not an HTML 404 fallback page
        final body = response.body.trim();
        if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
          return body;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<GitHubFileResponse?> getFileDetails({
    required String? token,
    required String owner,
    required String repo,
    required String path,
    String? branch,
  }) async {
    if (owner.isEmpty || repo.isEmpty) return null;

    final sanitizedToken = token?.trim();

    // 1. Direct GitHub REST API call
    final query = (branch != null && branch.isNotEmpty)
        ? '?ref=${Uri.encodeQueryComponent(branch)}'
        : '';
    final encodedPath = _encodeContentPath(path);
    final url = Uri.parse(
      '$baseUrl/repos/$owner/$repo/contents/$encodedPath$query',
    );
    final headers = buildHeaders(token: sanitizedToken);

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json['content'] != null) {
          return GitHubFileResponse(
            sha: json['sha']?.toString() ?? '',
            content: (json['content'] as String)
                .replaceAll('\n', '')
                .replaceAll('\r', ''),
          );
        }
      }
    } catch (_) {}

    // 2. Raw GitHub UserContent Fallback (supports token auth for private repos as well!)
    final branchesToTry = [
      if (branch != null && branch.isNotEmpty) branch,
      'main',
      'master',
      'HEAD',
    ].toSet().toList();

    for (final b in branchesToTry) {
      try {
        final rawUrl =
            'https://raw.githubusercontent.com/$owner/$repo/$b/$path?t=${DateTime.now().millisecondsSinceEpoch}';
        final rawHeaders = buildHeaders(token: sanitizedToken, accept: '*/*');
        final rawResponse = await http
            .get(Uri.parse(rawUrl), headers: rawHeaders)
            .timeout(const Duration(seconds: 6));
        if (rawResponse.statusCode == 200 &&
            rawResponse.body.trim().isNotEmpty) {
          final body = rawResponse.body.trim();
          if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
            final encoded = base64.encode(utf8.encode(body));
            return GitHubFileResponse(sha: '', content: encoded);
          }
        }
      } catch (_) {}
    }

    // 3. Fast CDN mirror for public repositories (no rate limit / robust CORS)
    for (final b in branchesToTry) {
      try {
        final cdnUrl =
            'https://cdn.jsdelivr.net/gh/$owner/$repo@$b/$path?t=${DateTime.now().millisecondsSinceEpoch}';
        final cdnResponse = await http
            .get(Uri.parse(cdnUrl))
            .timeout(const Duration(seconds: 6));
        if (cdnResponse.statusCode == 200 &&
            cdnResponse.body.trim().isNotEmpty) {
          final body = cdnResponse.body.trim();
          if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
            final encoded = base64.encode(utf8.encode(body));
            return GitHubFileResponse(sha: '', content: encoded);
          }
        }
      } catch (_) {}
    }

    // 4. GitHub Pages endpoint
    try {
      final pagesUrls = [
        'https://$owner.github.io/$repo/$path?t=${DateTime.now().millisecondsSinceEpoch}',
        'https://$owner.github.io/${repo.toLowerCase()}/$path?t=${DateTime.now().millisecondsSinceEpoch}',
      ];
      for (final pUrl in pagesUrls) {
        final pagesResp =
            await http.get(Uri.parse(pUrl)).timeout(const Duration(seconds: 6));
        if (pagesResp.statusCode == 200 && pagesResp.body.trim().isNotEmpty) {
          final body = pagesResp.body.trim();
          if (!body.startsWith('<!DOCTYPE') && !body.startsWith('<html')) {
            final encoded = base64.encode(utf8.encode(body));
            return GitHubFileResponse(sha: '', content: encoded);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<GitHubUpdateResult> updateFileWithResult({
    required String token,
    required String owner,
    required String repo,
    required String path,
    required String message,
    required String base64Content,
    String? sha,
    String? branch,
  }) async {
    final encodedPath = _encodeContentPath(path);
    final url = Uri.parse('$baseUrl/repos/$owner/$repo/contents/$encodedPath');
    final headers = buildHeaders(token: token);
    headers['Content-Type'] = 'application/json';

    final body = jsonEncode({
      'message': message,
      'content': base64Content,
      if (sha != null && sha.isNotEmpty) 'sha': sha,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    });

    try {
      final response = await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? newSha;
        try {
          final json = jsonDecode(response.body);
          newSha = json['content']?['sha']?.toString();
        } catch (_) {}
        return GitHubUpdateResult(
          isSuccess: true,
          statusCode: response.statusCode,
          newSha: newSha,
        );
      }

      String? errorMsg;
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['message']?.toString();
      } catch (_) {}

      return GitHubUpdateResult(
        isSuccess: false,
        statusCode: response.statusCode,
        errorMessage: errorMsg ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return GitHubUpdateResult(
        isSuccess: false,
        statusCode: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> updateFile({
    required String token,
    required String owner,
    required String repo,
    required String path,
    required String message,
    required String base64Content,
    String? sha,
    String? branch,
  }) async {
    final res = await updateFileWithResult(
      token: token,
      owner: owner,
      repo: repo,
      path: path,
      message: message,
      base64Content: base64Content,
      sha: sha,
      branch: branch,
    );
    return res.isSuccess;
  }

  /// Hard resets the branch ref to a target commit SHA (equivalent to git reset --hard <targetSha> && git push --force)
  Future<GitHubUpdateResult> hardResetBranchRef({
    required String token,
    required String owner,
    required String repo,
    required String branch,
    required String targetSha,
  }) async {
    final cleanBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final url =
        Uri.parse('$baseUrl/repos/$owner/$repo/git/refs/heads/$cleanBranch');
    final headers = buildHeaders(token: token);

    try {
      final response = await http
          .patch(
            url,
            headers: headers,
            body: jsonEncode({
              'sha': targetSha.trim(),
              'force': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return GitHubUpdateResult(
          isSuccess: true,
          statusCode: 200,
          newSha: targetSha,
        );
      }

      String? errorMsg;
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson.containsKey('message')) {
          errorMsg = errJson['message']?.toString();
        }
      } catch (_) {}

      return GitHubUpdateResult(
        isSuccess: false,
        statusCode: response.statusCode,
        errorMessage: errorMsg ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return GitHubUpdateResult(
        isSuccess: false,
        statusCode: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<GitHubCommit>> getRecentCommits({
    required String? token,
    required String owner,
    required String repo,
    String? branch,
    String? path,
    int perPage = 50,
  }) async {
    String urlStr = '$baseUrl/repos/$owner/$repo/commits?per_page=$perPage';
    if (branch != null && branch.trim().isNotEmpty) {
      urlStr += '&sha=${Uri.encodeQueryComponent(branch.trim())}';
    }
    if (path != null && path.trim().isNotEmpty) {
      urlStr += '&path=${path.trim()}';
    }

    final url = Uri.parse(urlStr);
    final headers = buildHeaders(token: token);

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((c) => GitHubCommit.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> getFileContentAtCommit({
    required String owner,
    required String repo,
    required String sha,
    required String path,
    String? token,
  }) async {
    try {
      // 1. Try raw usercontent with token support
      final rawUrl =
          'https://raw.githubusercontent.com/$owner/$repo/$sha/$path';
      final content = await fetchRaw(rawUrl, token: token);
      if (content != null &&
          content.trim().isNotEmpty &&
          !content.startsWith('<!DOCTYPE') &&
          !content.startsWith('<html')) {
        return content;
      }

      // 2. Try REST API ref
      final fileDetails = await getFileDetails(
        token: token,
        owner: owner,
        repo: repo,
        path: path,
        branch: sha,
      );
      if (fileDetails != null && fileDetails.content.isNotEmpty) {
        return utf8.decode(base64.decode(fileDetails.content));
      }
    } catch (_) {}
    return null;
  }

  Future<String?> fetchRaw(String url, {String? token}) async {
    try {
      final headers = buildHeaders(token: token, accept: '*/*');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return response.body;
    } catch (_) {}
    return null;
  }
}
