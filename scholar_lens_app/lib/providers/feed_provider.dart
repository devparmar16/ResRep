import 'package:flutter/foundation.dart';
import '../models/domain.dart';
import '../repositories/feed_repository.dart';
import '../utils/constants.dart';

/// Session-based personalized feed state management.
class FeedProvider extends ChangeNotifier {
  final FeedRepository _feedRepo;

  FeedProvider({FeedRepository? feedRepo})
      : _feedRepo = feedRepo ?? FeedRepository();

  // ─── State ────────────────────────────────────────────
  final Map<int, List<RankedPaper>> _loadedPages = {};
  List<DomainInfo> _userDomains = [];
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  String? _error;
  int _totalPagesLoaded = 0;

  // ─── Getters ──────────────────────────────────────────
  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get totalPagesLoaded => _totalPagesLoaded;
  bool get hasContent => _loadedPages.isNotEmpty;

  bool get hasMore => _totalPagesLoaded < 50; // reasonable upper limit

  /// Flatten all loaded pages into a single list.
  List<RankedPaper> get feedPapers {
    final all = <RankedPaper>[];
    for (int i = 0; i < _totalPagesLoaded; i++) {
      if (_loadedPages.containsKey(i)) {
        all.addAll(_loadedPages[i]!);
      }
    }
    return all;
  }

  // ─── Actions ──────────────────────────────────────────

  /// Set the user's domains and load the initial batch.
  Future<void> initialize(List<String> domainIds) async {
    if (_loadedPages.isNotEmpty) return; // already loaded

    _userDomains = DomainInfo.getByIds(domainIds);
    if (_userDomains.isEmpty) return;

    await _loadBatch(isInitial: true);
  }

  /// Load more: fetches the next batch of pages.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    await _loadBatch(isInitial: false);
  }

  Future<void> _loadBatch({required bool isInitial}) async {
    if (isInitial) {
      _isLoadingInitial = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    notifyListeners();

    try {
      final startPage = _totalPagesLoaded;
      final endPage = startPage + AppConstants.pagesPerBatch;

      for (int page = startPage; page < endPage; page++) {
        final ranked = await _feedRepo.fetchRankedPage(
          domains: _userDomains,
          pageIndex: page,
        );

        if (ranked.isEmpty) break; // no more results

        _loadedPages[page] = ranked;
        _totalPagesLoaded = page + 1;

        // Notify after each page for progressive UI updates
        notifyListeners();

        // Small delay to respect API rate limits
        if (page < endPage - 1) {
          await Future.delayed(
            Duration(milliseconds: AppConstants.apiDelayMs),
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingInitial = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Reset feed (on logout or domain change).
  void reset() {
    _loadedPages.clear();
    _totalPagesLoaded = 0;
    _userDomains = [];
    _error = null;
    _feedRepo.clearCaches();
    notifyListeners();
  }

  @override
  void dispose() {
    _feedRepo.dispose();
    super.dispose();
  }
}
