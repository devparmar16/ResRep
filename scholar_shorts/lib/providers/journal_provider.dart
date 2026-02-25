import 'package:flutter/foundation.dart';
import '../models/journal.dart';
import '../models/paper.dart';
import '../services/backend_api_service.dart';

/// State management for the Journals screen.
class JournalProvider extends ChangeNotifier {
  final BackendApiService _apiService;

  JournalProvider({BackendApiService? apiService})
      : _apiService = apiService ?? BackendApiService();

  // ─── State ────────────────────────────────────────────
  List<Journal> _journals = [];
  List<Paper> _journalPapers = [];
  String _selectedDomain = 'ai-ml';
  String _selectedSort = 'top';
  String _searchQuery = '';
  
  bool _isLoadingJournals = false;
  bool _isLoadingMoreJournals = false;
  bool _hasMoreJournals = true;
  int _journalSkip = 0;
  final int _journalLimit = 20;

  bool _isLoadingPapers = false;
  String? _error;

  // ─── Getters ──────────────────────────────────────────
  List<Journal> get journals => _journals;
  List<Paper> get journalPapers => _journalPapers;
  String get selectedDomain => _selectedDomain;
  String get selectedSort => _selectedSort;
  String get searchQuery => _searchQuery;
  
  bool get isLoadingJournals => _isLoadingJournals;
  bool get isLoadingMoreJournals => _isLoadingMoreJournals;
  bool get hasMoreJournals => _hasMoreJournals;
  bool get isLoadingPapers => _isLoadingPapers;
  String? get error => _error;

  // ─── Actions ──────────────────────────────────────────

  /// Load journals for a domain (first page).
  Future<void> loadJournals(String domain) async {
    _selectedDomain = domain;
    _isLoadingJournals = true;
    _hasMoreJournals = true;
    _journalSkip = 0;
    _error = null;
    notifyListeners();

    try {
      final raw = await _apiService.fetchJournals(
        domain: domain,
        query: _searchQuery,
        skip: _journalSkip,
        limit: _journalLimit,
      );
      _journals = raw.map((j) => Journal.fromJson(j)).toList();
      _hasMoreJournals = _journals.length == _journalLimit;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingJournals = false;
      notifyListeners();
    }
  }

  /// Load next page of journals.
  Future<void> loadMoreJournals() async {
    if (_isLoadingMoreJournals || !_hasMoreJournals || _isLoadingJournals) return;

    _isLoadingMoreJournals = true;
    _journalSkip += _journalLimit;
    notifyListeners();

    try {
      final raw = await _apiService.fetchJournals(
        domain: _selectedDomain,
        query: _searchQuery,
        skip: _journalSkip,
        limit: _journalLimit,
      );
      final newJournals = raw.map((j) => Journal.fromJson(j)).toList();
      if (newJournals.isEmpty) {
        _hasMoreJournals = false;
      } else {
        _journals.addAll(newJournals);
        _hasMoreJournals = newJournals.length == _journalLimit;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMoreJournals = false;
      notifyListeners();
    }
  }

  /// Search journals.
  void searchJournals(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadJournals(_selectedDomain);
  }

  /// Search query inside the selected journal
  String _journalSearchQuery = '';
  String get journalSearchQuery => _journalSearchQuery;

  /// Load papers for a journal with given sort.
  Future<void> loadJournalPapers(String journalId, {String sort = 'top', String? query}) async {
    _selectedSort = sort;
    if (query != null) {
      _journalSearchQuery = query;
    }
    
    _isLoadingPapers = true;
    _error = null;
    notifyListeners();

    try {
      _journalPapers = await _apiService.fetchJournalPapers(
        journalId: journalId,
        sort: sort,
        query: _journalSearchQuery,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingPapers = false;
      notifyListeners();
    }
  }

  /// Change domain selection.
  void selectDomain(String domain) {
    if (domain != _selectedDomain) {
      loadJournals(domain);
    }
  }

  /// Reset state.
  void reset() {
    _journals = [];
    _journalPapers = [];
    _searchQuery = '';
    _journalSearchQuery = '';
    _journalSkip = 0;
    _hasMoreJournals = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
