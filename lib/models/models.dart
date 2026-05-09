// ─── models/search_result.dart ───────────────────────────────────────────────

class SearchResult {
  final String filename;
  final String filePath;
  final String fileType;
  final double score;
  final DateTime modifiedDate;
  final String snippet; // HTML with <mark> tags for highlighting

  SearchResult({
    required this.filename,
    required this.filePath,
    required this.fileType,
    required this.score,
    required this.modifiedDate,
    required this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      filename: json['filename'] ?? '',
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      modifiedDate: DateTime.tryParse(json['modified_date'] ?? '') ?? DateTime.now(),
      snippet: json['snippet'] ?? '',
    );
  }
}

// ─── models/search_response.dart ─────────────────────────────────────────────

class SearchResponse {
  final List<SearchResult> results;
  final int total;
  final String? didYouMean;
  final int page;
  final int totalPages;

  SearchResponse({
    required this.results,
    required this.total,
    this.didYouMean,
    required this.page,
    required this.totalPages,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['results'] as List<dynamic>? ?? [])
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return SearchResponse(
      results: items,
      total: json['total'] ?? 0,
      didYouMean: json['did_you_mean'],
      page: json['page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}

// ─── models/index_stats.dart ──────────────────────────────────────────────────

class TermFreq {
  final String term;
  final int count;
  TermFreq({required this.term, required this.count});

  factory TermFreq.fromJson(Map<String, dynamic> json) =>
      TermFreq(term: json['term'], count: json['count']);
}

class IndexStats {
  final int totalDocs;
  final Map<String, int> byType;
  final List<TermFreq> topTerms;
  final bool indexed;

  IndexStats({
    required this.totalDocs,
    required this.byType,
    required this.topTerms,
    required this.indexed,
  });

  factory IndexStats.fromJson(Map<String, dynamic> json) {
    final byTypeRaw = json['by_type'] as Map<String, dynamic>? ?? {};
    final byType = byTypeRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
    final topTermsRaw = json['top_terms'] as List<dynamic>? ?? [];
    final topTerms = topTermsRaw
        .map((e) => TermFreq.fromJson(e as Map<String, dynamic>))
        .toList();
    return IndexStats(
      totalDocs: json['total_docs'] ?? 0,
      byType: byType,
      topTerms: topTerms,
      indexed: json['indexed'] ?? false,
    );
  }
}

// ─── models/build_result.dart ─────────────────────────────────────────────────

class BuildResult {
  final bool success;
  final int docCount;
  final Map<String, int> byType;
  final String? error;

  BuildResult({
    required this.success,
    required this.docCount,
    required this.byType,
    this.error,
  });

  factory BuildResult.fromJson(Map<String, dynamic> json) {
    final byTypeRaw = json['by_type'] as Map<String, dynamic>? ?? {};
    final byType = byTypeRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
    return BuildResult(
      success: json['success'] ?? false,
      docCount: json['doc_count'] ?? 0,
      byType: byType,
      error: json['error'],
    );
  }
}
