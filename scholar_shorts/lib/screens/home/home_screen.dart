import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../widgets/short_paper_card.dart';
import '../../theme/app_theme.dart';
import '../../models/domain.dart';
import '../paper_detail_screen.dart';
import '../search_screen.dart';
import '../trending_screen.dart';
import '../profile_screen.dart';
import '../journals/journals_screen.dart';
import '../collections/collections_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFeed();
    });
  }

  void _initFeed() {
    final auth = context.read<AuthProvider>();
    final feed = context.read<FeedProvider>();
    if (auth.profile != null && !feed.hasContent) {
      feed.initialize(
        auth.profile!.selectedDomains,
        userId: auth.profile!.id,
      );
      // Also load bookmark state
      context.read<BookmarkProvider>().loadUserData(auth.profile!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildFeed(),
          const JournalsScreen(),
          const CollectionsScreen(),
          const SearchScreen(),
          const TrendingScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.accentTeal,
          unselectedItemColor: AppTheme.textDim.withValues(alpha: 0.5),
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.style_rounded),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_rounded),
              label: 'Journals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.collections_bookmark_rounded),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_rounded),
              label: 'Trending',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        final auth = context.read<AuthProvider>();
        final domains = auth.profile?.selectedDomains ?? [];

        return Stack(
          children: [
            _buildFeedContent(feed),
            
            // Premium Floating Navigation Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Tabs: For You | Trending | Latest
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['for-you', 'trending', 'latest'].map((id) {
                            final label = id == 'for-you' ? 'For You' : id[0].toUpperCase() + id.substring(1);
                            final filterId = id == 'for-you' ? null : id;
                            final isSelected = feed.activeFilterDomainId == filterId;
                            
                            return GestureDetector(
                              onTap: () {
                                feed.setActiveFilterDomain(filterId);
                                if (_pageController.hasClients) {
                                  _pageController.jumpToPage(0);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    color: isSelected ? Colors.white : Colors.white54,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        
                        // Active Indicator Line
                        _buildActiveIndicator(feed),

                        // Sub-Tier: Interests
                        if (domains.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: domains.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final domainId = domains[index];
                                final info = DomainInfo.getById(domainId);
                                final isSelected = feed.activeFilterDomainId == domainId;
                                
                                return GestureDetector(
                                  onTap: () {
                                    feed.setActiveFilterDomain(domainId);
                                    if (_pageController.hasClients) {
                                      _pageController.jumpToPage(0);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: 200.ms,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? info.color.withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? info.color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Text(
                                      '${info.icon} ${info.label}',
                                      style: GoogleFonts.inter(
                                        color: isSelected ? Colors.white : Colors.white38,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveIndicator(FeedProvider feed) {
    // Simplified indicator — in a real app, this would be an animated underline
    return Container(
      height: 2,
      width: 40,
      decoration: BoxDecoration(
        gradient: AppTheme.auroraGradient,
        borderRadius: BorderRadius.circular(1),
      ),
    ).animate().shimmer();
  }

  Widget _buildFeedContent(FeedProvider feed) {
    if (feed.isLoadingInitial && !feed.hasContent) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (feed.error != null && !feed.hasContent) {
      return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Text('Error: ${feed.error}', style: const TextStyle(color: Colors.white)),
             const SizedBox(height: 16),
             ElevatedButton(
               onPressed: () => _initFeed(),
               child: const Text('Retry'),
             )
           ],
         ),
      );
    }

    final papers = feed.feedPapers;

    if (papers.isEmpty) {
       return const Center(
         child: Text(
           'No papers found for this selection.\nTry changing your interests.',
           textAlign: TextAlign.center,
           style: TextStyle(color: Colors.white70),
         ),
       );
    }

    final auth = context.read<AuthProvider>();

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surfaceVariant,
      onRefresh: () async {
        final domains = auth.profile?.selectedDomains ?? [];
        await feed.refresh(domains);
        // Ensure we explicitly start at the top of the new feed
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        // Using AlwaysScrollableScrollPhysics to allow overscroll for RefreshIndicator
        physics: const ReelsScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        allowImplicitScrolling: false,
        itemCount: papers.length + (feed.hasMore ? 1 : 0),
        onPageChanged: (index) {
          if (index >= papers.length - 2) {
            if (!feed.isLoadingMore && feed.hasMore && feed.error == null) {
              feed.loadMore();
            }
          }
        },
        itemBuilder: (context, index) {
          if (index == papers.length) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          final paper = papers[index].paper;
          return ShortPaperCard(
            paper: paper,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaperDetailScreen(paper: paper),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Instagram Reels-style scroll physics.
/// - Quick, decisive snap with minimal drag
/// - Light flick instantly commits to next/prev page
/// - No hesitation or "bouncing back" feeling
class ReelsScrollPhysics extends ScrollPhysics {
  const ReelsScrollPhysics({super.parent});

  @override
  ReelsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReelsScrollPhysics(parent: buildParent(ancestor));
  }

  /// Very low threshold — even a gentle flick triggers page change.
  @override
  double get minFlingVelocity => 50.0;

  /// Snappy, fast spring: light mass + high stiffness + overdamped.
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 1,        // Light — responds instantly
        stiffness: 800,  // High — snaps fast
        damping: 60,     // Overdamped (critical = sqrt(4*1*800) ≈ 56.6). No overshoot.
      );

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Boundary handling
    if ((velocity < 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity > 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = this.tolerance;
    final double target = _getTargetPixels(position, tolerance, velocity);

    if (target != position.pixels) {
      return ScrollSpringSimulation(spring, position.pixels, target, velocity,
          tolerance: tolerance);
    }
    return null;
  }

  double _getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    final double page = position.pixels / position.viewportDimension;

    // Key: Use a SMALL offset (0.15) so that dragging just 15% of the page
    // is enough to commit to the next/prev page. Instagram Reels commits
    // very early — you barely need to swipe.
    if (velocity < -minFlingVelocity) {
      // Flick up → go to next page
      return (page + 0.15).ceilToDouble() * position.viewportDimension;
    } else if (velocity > minFlingVelocity) {
      // Flick down → go to previous page
      return (page - 0.15).floorToDouble() * position.viewportDimension;
    }

    // No fling — snap to whichever page is closest.
    // But with a bias: if dragged past 30%, commit to next page.
    final double currentPageFraction = page - page.floorToDouble();
    if (currentPageFraction > 0.3) {
      return page.ceilToDouble() * position.viewportDimension;
    } else if (currentPageFraction < -0.3) {
      return page.floorToDouble() * position.viewportDimension;
    }
    return page.roundToDouble() * position.viewportDimension;
  }
}
