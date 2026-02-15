import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/domain.dart';
import '../../providers/auth_provider.dart';
import '../../providers/search_provider.dart';
import '../../repositories/paper_repository.dart';
import '../../screens/home/feed_screen.dart';
import '../../screens/paper_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/domain_filter_chips.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/paper_card.dart';
import '../../widgets/search_bar_widget.dart';

/// Main home screen with bottom navigation: Feed | Search | Profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE052A0).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildFeedTab(),
                _buildSearchTab(),
                _buildProfileTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Feed Tab ────────────────────────────────────────
  Widget _buildFeedTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFFE052A0)],
                ).createShader(bounds),
                child: const Text(
                  'Your Feed',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.textDim,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: FeedScreen()),
      ],
    );
  }

  // ─── Search Tab ──────────────────────────────────────
  Widget _buildSearchTab() {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        return CustomScrollView(
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
                ),
              ),
            ),

            // Quick tags
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickTag('Machine Learning', provider),
                      _quickTag('Cloud & K8s', provider),
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
              // Pagination
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (provider.hasPrevPage)
                        _pageButton('← Prev', () => provider.prevPage()),
                      const SizedBox(width: 16),
                      Text(
                        'Page ${provider.currentPage} of ${provider.maxPage}',
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (provider.hasNextPage)
                        _pageButton('Next →', () => provider.nextPage()),
                    ],
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

  // ─── Profile Tab ─────────────────────────────────────
  Widget _buildProfileTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final profile = auth.profile;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFFE052A0)],
                ).createShader(bounds),
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Profile card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, Color(0xFFE052A0)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (profile?.fullName ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile?.fullName ?? 'User',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? '',
                      style: const TextStyle(
                        color: AppTheme.textDim,
                        fontSize: 14,
                      ),
                    ),
                    if (profile?.collegeName.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile!.collegeName,
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Selected domains
                    if (profile?.selectedDomains.isNotEmpty ?? false)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile!.selectedDomains.map((id) {
                          final d = DomainInfo.getById(id);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: d.badgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${d.icon} ${d.label}',
                              style: TextStyle(
                                color: d.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const Spacer(),

              // Sign out
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF43F5E),
                    side: BorderSide(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textDim,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_rounded),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
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

  Widget _pageButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Returns a color based on the similarity score.
  Color _scoreColor(double score) {
    if (score >= 0.75) return const Color(0xFF34D399); // green
    if (score >= 0.50) return const Color(0xFFFBBF24); // amber
    return const Color(0xFFF87171); // red
  }
}
