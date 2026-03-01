import 'package:flutter/foundation.dart';
import '../models/conference.dart';
import '../services/backend_api_service.dart';

class ConferenceProvider extends ChangeNotifier {
  final BackendApiService _api;

  ConferenceProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  // ─── State ──────────────────────────────────────────
  List<Conference> _conferences = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Filters
  String? _modeFilter; // online, offline, hybrid
  String? _countryFilter;
  String? _domainFilter;
  String? _publisherFilter;

  final int _pageSize = 50;

  // ─── Getters ────────────────────────────────────────
  List<Conference> get conferences => List.unmodifiable(_conferences);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get hasContent => _conferences.isNotEmpty;

  String? get modeFilter => _modeFilter;
  String? get countryFilter => _countryFilter;
  String? get domainFilter => _domainFilter;
  String? get publisherFilter => _publisherFilter;

  // ─── Actions ────────────────────────────────────────

  /// Fetch initial list of conferences with current filters.
  Future<void> loadConferences() async {
    _isLoading = true;
    _error = null;
    _hasMore = true;
    notifyListeners();

    try {
      _conferences = await _api.fetchConferences(
        mode: _modeFilter,
        country: _countryFilter,
        domain: _domainFilter,
        publisher: _publisherFilter,
        limit: _pageSize,
        skip: 0,
      );
      if (_conferences.length < _pageSize) _hasMore = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch next page of conferences.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final newItems = await _api.fetchConferences(
        mode: _modeFilter,
        country: _countryFilter,
        domain: _domainFilter,
        publisher: _publisherFilter,
        limit: _pageSize,
        skip: _conferences.length,
      );
      if (newItems.isEmpty || newItems.length < _pageSize) {
        _hasMore = false;
      }
      _conferences.addAll(newItems);
    } catch (e) {
      // Background error ignored for UX
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh
  Future<void> refresh() async {
    await loadConferences();
  }

  // ─── Filter Updates ─────────────────────────────────

  void setModeFilter(String? mode) {
    if (_modeFilter == mode) return;
    _modeFilter = mode;
    loadConferences();
  }

  void setCountryFilter(String? country) {
    if (_countryFilter == country) return;
    _countryFilter = country;
    loadConferences();
  }

  void setDomainFilter(String? domain) {
    if (_domainFilter == domain) return;
    _domainFilter = domain;
    loadConferences();
  }

  void setPublisherFilter(String? publisher) {
    if (_publisherFilter == publisher) return;
    _publisherFilter = publisher;
    loadConferences();
  }

  void clearFilters() {
    _modeFilter = null;
    _countryFilter = null;
    _domainFilter = null;
    _publisherFilter = null;
    loadConferences();
  }
}
