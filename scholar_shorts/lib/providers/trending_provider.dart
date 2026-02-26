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
  String? _error;
  String? _selectedDomain;

  // ─── Getters ────────────────────────────────
  List<TrendingPaper> get papers => List.unmodifiable(_papers);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedDomain => _selectedDomain;
  bool get hasContent => _papers.isNotEmpty;

  // ─── Actions ────────────────────────────────

  /// Load trending papers (initial or domain-filtered).
  Future<void> loadTrending({String? domain}) async {
    _isLoading = true;
    _error = null;
    _selectedDomain = domain;
    notifyListeners();

    try {
      _papers = await _api.fetchSocialTrending(
        domain: domain,
        limit: 50,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change domain filter and reload.
  Future<void> filterByDomain(String? domain) async {
    await loadTrending(domain: domain);
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    await loadTrending(domain: _selectedDomain);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
