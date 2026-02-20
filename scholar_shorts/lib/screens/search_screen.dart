import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/domain_filter_chips.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/paper_card.dart';
import '../theme/app_theme.dart';
import 'paper_detail_screen.dart';
import '../services/huggingface_embedding_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<SearchProvider>();
      if (!provider.isLoadingMore && provider.hasMore && provider.error == null) {
        provider.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.accent, Color(0xFFE052A0)],
                  ).createShader(bounds),
                  child: const Text(
                    'Explore',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBarWidget(
                  onSearch: (query) => provider.search(query),
                  isLoading: provider.isLoading,
                ),
              ),
            ),

            // Quick tags
            if (!provider.hasSearched)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickTag('Machine Learning', provider),
                        _quickTag('Cloud Computing', provider),
                        _quickTag('Cybersecurity', provider),
                        _quickTag('Web Development', provider),
                        _quickTag('Data Science', provider),
                      ],
                    ),
                  ),
                ),
              ),

            // Domain filters
            if (provider.hasSearched && provider.papers.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                  child: DomainFilterChips(
                    counts: provider.domainCounts,
                    activeDomain: provider.activeDomain,
                    onDomainSelected: (d) => provider.setDomain(d),
                  ),
                ),
              ),

            // Sort controls
            if (provider.hasSearched && provider.filteredResults.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '${provider.totalResults} results',
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      _sortChip('Relevance', SortMode.relevance, provider),
                      const SizedBox(width: 8),
                      _sortChip('Citations', SortMode.citations, provider),
                      const SizedBox(width: 8),
                      _sortChip('Newest', SortMode.year, provider),
                    ],
                  ),
                ),
              ),

            // Loading
            if (provider.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingShimmer(itemCount: 3),
                ),
              ),

            // Error
            if (!provider.isLoading && provider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        provider.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Empty state
            if (!provider.isLoading &&
                provider.error == null &&
                !provider.hasSearched)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔎', style: TextStyle(fontSize: 56)),
                      SizedBox(height: 16),
                      Text(
                        'Semantic Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Powered by BAAI/bge-m3 embeddings',
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Results
            if (!provider.isLoading &&
                provider.error == null &&
                provider.filteredResults.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final result = provider.filteredResults[index];
                      final paper = result.paper;
                      final score = result.similarityScore;
                      return Stack(
                        children: [
                          PaperCard(
                            paper: paper,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PaperDetailScreen(paper: paper),
                                ),
                              );
                            },
                          ),
                          // Similarity score badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _scoreColor(score)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _scoreColor(score)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                '${(score * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: _scoreColor(score),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    childCount: provider.filteredResults.length,
                  ),
                ),
              ),
              // Pagination / Loading More
              if (provider.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                )
              else if (provider.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Error loading next batch',
                            style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: provider.loadMore,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accent,
                              side: const BorderSide(color: AppTheme.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!provider.hasMore && provider.semanticResults.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'End of results',
                        style: TextStyle(
                          color: AppTheme.textDim.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _quickTag(String label, SearchProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppTheme.surface,
        labelStyle: const TextStyle(color: AppTheme.textPrimary),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => provider.search(label),
      ),
    );
  }

  Widget _sortChip(String label, SortMode mode, SearchProvider provider) {
    final isActive = provider.currentSort == mode;
    return GestureDetector(
      onTap: () => provider.setSort(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppTheme.accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.accent : AppTheme.textDim,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.75) return const Color(0xFF34D399); // green
    if (score >= 0.50) return const Color(0xFFFBBF24); // amber
    return const Color(0xFFF87171); // red
  }
}
