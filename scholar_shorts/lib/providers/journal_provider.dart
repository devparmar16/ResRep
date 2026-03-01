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
  List<Journal> _filteredJournals = [];
  List<Paper> _journalPapers = [];

  // Multi-domain: empty set = "All"
  final Set<String> _selectedDomains = {};
  String _selectedSort = 'top';
  String _searchQuery = '';
  String? _publisherFilter;

  bool _isLoadingJournals = false;
  bool _isLoadingMoreJournals = false;
  bool _hasMoreJournals = true;
  int _journalSkip = 0;
  final int _journalLimit = 20;

  bool _isLoadingPapers = false;
  bool _isLoadingMorePapers = false;
  bool _hasMorePapers = true;
  String? _papersNextCursor;
  String? _error;

  // ─── Getters ──────────────────────────────────────────
  List<Journal> get journals => _filteredJournals;
  List<Journal> get allJournals => _journals;
  List<Paper> get journalPapers => _journalPapers;
  Set<String> get selectedDomains => _selectedDomains.toSet();
  String get selectedDomain => _selectedDomains.isEmpty ? 'all' : _selectedDomains.first;
  String get selectedSort => _selectedSort;
  String get searchQuery => _searchQuery;
  String? get publisherFilter => _publisherFilter;

  bool get isLoadingJournals => _isLoadingJournals;
  bool get isLoadingMoreJournals => _isLoadingMoreJournals;
  bool get hasMoreJournals => _hasMoreJournals;
  bool get isLoadingPapers => _isLoadingPapers;
  bool get isLoadingMorePapers => _isLoadingMorePapers;
  bool get hasMorePapers => _hasMorePapers;
  String? get error => _error;

  bool get isAllSelected => _selectedDomains.isEmpty;

  /// Unique publishers from loaded journals for filter chips.
  List<String> get availablePublishers {
    final pubs = _journals
        .where((j) => j.publisher?.isNotEmpty == true)
        .map((j) => j.publisher!)
        .toSet()
        .toList();
    pubs.sort();
    return pubs;
  }

  // ─── Actions ──────────────────────────────────────────

  /// Load journals using multi-domain endpoint.
  Future<void> loadJournals([List<String>? domainOverride, bool ignoreCache = false]) async {
    _isLoadingJournals = true;
    _hasMoreJournals = true;
    _journalSkip = 0;
    _error = null;
    notifyListeners();

    try {
      final domains = domainOverride ?? 
          (_selectedDomains.isEmpty ? ['all'] : _selectedDomains.toList());

      final raw = await _apiService.fetchJournalsMultiDomain(
        domains: domains,
        query: _searchQuery,
        skip: _journalSkip,
        limit: _journalLimit,
        ignoreCache: ignoreCache,
      );
      _journals = raw.map((j) => Journal.fromJson(j)).toList();
      _applyPublisherFilter();
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
      final domains = _selectedDomains.isEmpty ? ['all'] : _selectedDomains.toList();

      final raw = await _apiService.fetchJournalsMultiDomain(
        domains: domains,
        query: _searchQuery,
        skip: _journalSkip,
        limit: _journalLimit,
      );
      final newJournals = raw.map((j) => Journal.fromJson(j)).toList();
      if (newJournals.isEmpty) {
        _hasMoreJournals = false;
      } else {
        _journals.addAll(newJournals);
        _applyPublisherFilter();
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
    loadJournals();
  }

  /// Search query inside the selected journal
  String _journalSearchQuery = '';
  String get journalSearchQuery => _journalSearchQuery;

  /// Load papers for a journal with given sort.
  Future<void> loadJournalPapers(String journalId, {String sort = 'top', String? query, bool ignoreCache = false}) async {
    _selectedSort = sort;
    if (query != null) {
      _journalSearchQuery = query;
    }

    _isLoadingPapers = true;
    _error = null;
    _journalPapers.clear();
    _papersNextCursor = '*';
    _hasMorePapers = true;
    notifyListeners();

    try {
      final result = await _apiService.fetchJournalPapers(
        journalId: journalId,
        sort: sort,
        cursor: _papersNextCursor!,
        query: _journalSearchQuery,
        ignoreCache: ignoreCache,
      );
      _journalPapers = result.papers;
      _papersNextCursor = result.nextCursor;
      _hasMorePapers = _papersNextCursor != null && _papersNextCursor!.isNotEmpty;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingPapers = false;
      notifyListeners();
    }
  }

  /// Load more papers for the current journal.
  Future<void> loadMoreJournalPapers(String journalId) async {
    if (_isLoadingPapers || _isLoadingMorePapers || !_hasMorePapers || _papersNextCursor == null) return;

    _isLoadingMorePapers = true;
    notifyListeners();

    try {
      final result = await _apiService.fetchJournalPapers(
        journalId: journalId,
        sort: _selectedSort,
        cursor: _papersNextCursor!,
        query: _journalSearchQuery,
      );
      
      _journalPapers.addAll(result.papers);
      _papersNextCursor = result.nextCursor;
      _hasMorePapers = _papersNextCursor != null && _papersNextCursor!.isNotEmpty;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMorePapers = false;
      notifyListeners();
    }
  }

  /// Toggle a domain on/off.
  void toggleDomain(String domain) {
    if (_selectedDomains.contains(domain)) {
      _selectedDomains.remove(domain);
    } else {
      _selectedDomains.add(domain);
    }
    _publisherFilter = null; // Reset publisher filter on domain change
    loadJournals();
  }

  /// Select "All" — clears domain selection.
  void selectAll() {
    _selectedDomains.clear();
    _publisherFilter = null;
    loadJournals();
  }

  /// Legacy single-select support.
  void selectDomain(String domain) {
    _selectedDomains.clear();
    _selectedDomains.add(domain);
    _publisherFilter = null;
    loadJournals();
  }

  /// Set publisher filter.
  void setPublisherFilter(String? publisher) {
    _publisherFilter = publisher;
    _applyPublisherFilter();
    notifyListeners();
  }

  void _applyPublisherFilter() {
    if (_publisherFilter?.isEmpty ?? true) {
      _filteredJournals = List.of(_journals);
    } else {
      _filteredJournals = _journals
          .where((j) => j.publisher == _publisherFilter)
          .toList();
    }
  }

  /// Reset state.
  void reset() {
    _journals = [];
    _filteredJournals = [];
    _journalPapers = [];
    _searchQuery = '';
    _journalSearchQuery = '';
    _journalSkip = 0;
    _hasMoreJournals = true;
    _selectedDomains.clear();
    _publisherFilter = null;
    _papersNextCursor = '*';
    _hasMorePapers = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
