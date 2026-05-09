import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Change this to your backend URL when deploying
  static const String _baseUrl = 'http://localhost:5000';

  // ── Build / Rebuild Index ─────────────────────────────────────────────────
  Future<BuildResult> buildIndex({
    required String folderPath,
    required List<String> formats,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/build-index');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'folder_path': folderPath, 'formats': formats}),
    );
    if (response.statusCode == 200) {
      return BuildResult.fromJson(jsonDecode(response.body));
    }
    throw Exception('Build failed: ${response.body}');
  }

  // ── Search ────────────────────────────────────────────────────────────────
  Future<SearchResponse> search({
    required String query,
    String? fromDate,
    String? toDate,
    String? fileType,
    int page = 1,
  }) async {
    final params = {
      'q': query,
      if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
      if (fileType != null && fileType.isNotEmpty && fileType != 'All') 'file_type': fileType,
      'page': page.toString(),
    };
    final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return SearchResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Search failed: ${response.body}');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Future<IndexStats> getStats() async {
    final uri = Uri.parse('$_baseUrl/api/stats');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return IndexStats.fromJson(jsonDecode(response.body));
    }
    throw Exception('Stats failed: ${response.body}');
  }
}
