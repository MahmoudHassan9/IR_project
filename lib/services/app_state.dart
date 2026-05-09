import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

// Note: cannot use `index` as an enum value — it conflicts with the built-in .index getter
enum AppTab { indexing, search, stats }

extension AppTabX on AppTab {
  int get tabIndex => AppTab.values.indexOf(this);
}

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ── Navigation ─────────────────────────────────────────────────────────
  AppTab currentTab = AppTab.indexing;

  void navigate(AppTab tab) {
    currentTab = tab;
    notifyListeners();
  }

  // ── Index State ────────────────────────────────────────────────────────
  String folderPath = '';
  Set<String> selectedFormats = {'pdf', 'txt', 'json', 'csv', 'xlsx'};
  bool isBuilding = false;
  BuildResult? lastBuildResult;
  String? buildError;

  void setFolderPath(String path) {
    folderPath = path;
    notifyListeners();
  }

  void toggleFormat(String fmt) {
    if (selectedFormats.contains(fmt)) {
      selectedFormats.remove(fmt);
    } else {
      selectedFormats.add(fmt);
    }
    notifyListeners();
  }

  Future<void> buildIndex() async {
    if (folderPath.isEmpty) return;
    isBuilding = true;
    buildError = null;
    lastBuildResult = null;
    notifyListeners();
    try {
      lastBuildResult = await _api.buildIndex(
        folderPath: folderPath,
        formats: selectedFormats.toList(),
      );
    } catch (e) {
      buildError = e.toString();
    } finally {
      isBuilding = false;
      notifyListeners();
    }
  }

  // ── Search State ────────────────────────────────────────────────────────
  String searchQuery = '';
  DateTime? fromDate;
  DateTime? toDate;
  String selectedFileType = 'All';
  int currentPage = 1;
  bool isSearching = false;
  SearchResponse? searchResponse;
  String? searchError;

  final List<String> fileTypeOptions = [
    'All',
    'pdf',
    'txt',
    'json',
    'csv',
    'xlsx'
  ];

  void setQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setFromDate(DateTime? d) {
    fromDate = d;
    notifyListeners();
  }

  void setToDate(DateTime? d) {
    toDate = d;
    notifyListeners();
  }

  void setFileType(String t) {
    selectedFileType = t;
    notifyListeners();
  }

  void setPage(int p) {
    currentPage = p;
    runSearch(resetPage: false);
  }

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> runSearch({bool resetPage = true}) async {
    if (searchQuery.trim().isEmpty) return;
    if (resetPage) currentPage = 1;
    isSearching = true;
    searchError = null;
    notifyListeners();
    try {
      searchResponse = await _api.search(
        query: searchQuery.trim(),
        fromDate: _fmt(fromDate),
        toDate: _fmt(toDate),
        fileType: selectedFileType,
        page: currentPage,
      );
    } catch (e) {
      searchError = e.toString();
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    searchQuery = '';
    fromDate = null;
    toDate = null;
    selectedFileType = 'All';
    currentPage = 1;
    searchResponse = null;
    searchError = null;
    notifyListeners();
  }

  // ── Stats State ─────────────────────────────────────────────────────────
  bool isLoadingStats = false;
  IndexStats? stats;
  String? statsError;

  Future<void> loadStats() async {
    isLoadingStats = true;
    statsError = null;
    notifyListeners();
    try {
      stats = await _api.getStats();
    } catch (e) {
      statsError = e.toString();
    } finally {
      isLoadingStats = false;
      notifyListeners();
    }
  }
}
