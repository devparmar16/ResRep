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
  int _nextOffset = 0;

  // Filters
  String? _modeFilter;
  String? _countryFilter;
  String? _cityFilter;
  String? _domainFilter;

  static const int _pageSize = 25;

  // ─── Getters ────────────────────────────────────────
  List<Conference> get conferences => List.unmodifiable(_conferences);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get hasContent => _conferences.isNotEmpty;

  String? get modeFilter => _modeFilter;
  String? get countryFilter => _countryFilter;
  String? get cityFilter => _cityFilter;
  String? get domainFilter => _domainFilter;
  bool get hasActiveFilters =>
      _modeFilter != null ||
      _countryFilter != null ||
      _cityFilter != null ||
      _domainFilter != null;

  // ─── Actions ────────────────────────────────────────

  /// Fetch initial list of conferences with current filters.
  Future<void> loadConferences({bool ignoreCache = false}) async {
    _isLoading = true;
    _error = null;
    _hasMore = true;
    _nextOffset = 0;
    _conferences = [];
    notifyListeners();

    try {
      final result = await _api.fetchConferences(
        mode: _modeFilter,
        country: _countryFilter,
        city: _cityFilter,
        domain: _domainFilter,
        limit: _pageSize,
        offset: 0,
        ignoreCache: ignoreCache,
      );
      _conferences = result.conferences;
      _hasMore = result.hasMore;
      _nextOffset = result.nextOffset;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch next page of conferences (offset-based).
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _api.fetchConferences(
        mode: _modeFilter,
        country: _countryFilter,
        city: _cityFilter,
        domain: _domainFilter,
        limit: _pageSize,
        offset: _nextOffset,
      );
      _conferences = [..._conferences, ...result.conferences];
      _hasMore = result.hasMore;
      _nextOffset = result.nextOffset;
    } catch (e) {
      // Swallow load-more errors for UX
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh
  Future<void> refresh() async {
    await loadConferences(ignoreCache: true);
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

  void setCityFilter(String? city) {
    if (_cityFilter == city) return;
    _cityFilter = city;
    loadConferences();
  }

  void setDomainFilter(String? domain) {
    if (_domainFilter == domain) return;
    _domainFilter = domain;
    loadConferences();
  }

  void clearFilters() {
    _modeFilter = null;
    _countryFilter = null;
    _cityFilter = null;
    _domainFilter = null;
    loadConferences();
  }
}
