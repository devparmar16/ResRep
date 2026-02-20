import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/short_paper_card.dart';
import '../../theme/app_theme.dart';
import '../paper_detail_screen.dart';
import '../search_screen.dart';
import '../profile_screen.dart';

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
      feed.initialize(auth.profile!.selectedDomains);
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
          const SearchScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9), // Transparent floating look
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0, // Flat
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.style_rounded),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
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
               'No papers found.\nTry selecting topics in Profile.',
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.white70),
             ),
           );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const ReelsScrollPhysics(parent: ClampingScrollPhysics()),
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
        );
      },
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
