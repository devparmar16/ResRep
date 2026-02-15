import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/domain.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../repositories/feed_repository.dart';
import '../../screens/paper_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_shimmer.dart';

/// Personalized research feed screen.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        if (feed.isLoadingInitial && !feed.hasContent) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Building your feed…',
                  style: TextStyle(
                    color: AppTheme.textDim,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const LoadingShimmer(itemCount: 3),
              ],
            ),
          );
        }

        if (feed.error != null && !feed.hasContent) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load feed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feed.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _initFeed,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final papers = feed.feedPapers;

        if (papers.isEmpty && !feed.isLoadingInitial) {
          return const Center(
            child: Text(
              'No papers found for your interests.',
              style: TextStyle(color: AppTheme.textDim, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: papers.length + 1, // +1 for load-more button
          itemBuilder: (context, index) {
            if (index == papers.length) {
              return _buildLoadMore(feed);
            }

            final ranked = papers[index];
            return _FeedPaperCard(
              ranked: ranked,
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadMore(FeedProvider feed) {
    if (!feed.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'You\'ve reached the end 🎉',
            style: TextStyle(
              color: AppTheme.textDim.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: feed.isLoadingMore
            ? const Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading more papers…',
                    style: TextStyle(color: AppTheme.textDim, fontSize: 13),
                  ),
                ],
              )
            : GestureDetector(
                onTap: () => feed.loadMore(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, Color(0xFFE052A0)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Load More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Individual feed paper card with similarity score badge.
class _FeedPaperCard extends StatelessWidget {
  final RankedPaper ranked;
  final int index;

  const _FeedPaperCard({required this.ranked, required this.index});

  @override
  Widget build(BuildContext context) {
    final paper = ranked.paper;
    final score = ranked.similarityScore;
    final domainInfo = DomainInfo.getInfo(paper.domain);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaperDetailScreen(paper: paper),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: domain badge + score
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: domainInfo.badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${domainInfo.icon} ${domainInfo.label}',
                    style: TextStyle(
                      color: domainInfo.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Similarity score badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _scoreColor(score).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: _scoreColor(score),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(score * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _scoreColor(score),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              paper.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Abstract snippet
            if (paper.abstract_ != null && paper.abstract_!.isNotEmpty)
              Text(
                paper.abstract_!,
                style: const TextStyle(
                  color: AppTheme.textDim,
                  fontSize: 12.5,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            // Footer
            Row(
              children: [
                if (paper.year != null)
                  Text(
                    '${paper.year}',
                    style: TextStyle(
                      color: AppTheme.textDim.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                if (paper.year != null) const SizedBox(width: 12),
                Icon(
                  Icons.format_quote_rounded,
                  color: AppTheme.textDim.withValues(alpha: 0.5),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${paper.citationCount}',
                  style: TextStyle(
                    color: AppTheme.textDim.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (paper.authors.isNotEmpty)
                  Flexible(
                    child: Text(
                      paper.authors.take(2).join(', '),
                      style: TextStyle(
                        color: AppTheme.textDim.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: (index * 50).clamp(0, 500)))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0, duration: 300.ms);
  }

  Color _scoreColor(double score) {
    if (score >= 0.7) return const Color(0xFF34D399);
    if (score >= 0.4) return const Color(0xFFFBBF24);
    return const Color(0xFF94A3B8);
  }
}
