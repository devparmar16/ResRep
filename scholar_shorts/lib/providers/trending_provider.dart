import 'package:flutter/foundation.dart';
import '../services/backend_api_service.dart';

/// State management for the Social Trending tab.
class TrendingProvider extends ChangeNotifier {
  final BackendApiService _api;

  TrendingProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  // ─── State ──────────────────────────────────
  List<TrendingPaper> _papers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _selectedDomain;
  final int _pageSize = 30;

  // ─── Getters ────────────────────────────────
  List<TrendingPaper> get papers => List.unmodifiable(_papers);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get selectedDomain => _selectedDomain;
  bool get hasContent => _papers.isNotEmpty;

  // ─── Actions ────────────────────────────────

  /// Load trending papers (initial or domain-filtered).
  Future<void> loadTrending({String? domain, bool ignoreCache = false}) async {
    _isLoading = true;
    _error = null;
    _selectedDomain = domain;
    _hasMore = true;
    notifyListeners();

    try {
      _papers = await _api.fetchSocialTrending(
        domain: domain,
        limit: _pageSize,
        skip: 0,
        ignoreCache: ignoreCache,
      );
      if (_papers.length < _pageSize) _hasMore = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch next page
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final newPapers = await _api.fetchSocialTrending(
        domain: _selectedDomain,
        limit: _pageSize,
        skip: _papers.length,
      );
      if (newPapers.isEmpty || newPapers.length < _pageSize) {
        _hasMore = false;
      }
      _papers.addAll(newPapers);
    } catch (e) {
      // Ignore background errors for now
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Change domain filter and reload.
  Future<void> filterByDomain(String? domain) async {
    await loadTrending(domain: domain);
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    await loadTrending(domain: _selectedDomain, ignoreCache: true);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
