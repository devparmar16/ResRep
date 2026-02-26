import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/collection.dart';
import '../../models/paper.dart';
import '../../models/saved_paper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_theme.dart';
import '../paper_detail_screen.dart';

/// Shows all papers saved in a specific collection.
class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      context.read<BookmarkProvider>().loadCollectionPapers(
            userId: userId,
            collectionId: widget.collection.id,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildHeader(),
          _buildPaperList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.background.withValues(alpha: 0.9),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.collection.name,
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.collection.description != null &&
                widget.collection.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.collection.description!,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textDim,
                  ),
                ),
              ),
            Consumer<BookmarkProvider>(
              builder: (_, bm, __) => Text(
                '${bm.collectionPapers.length} papers',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentTeal,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildPaperList() {
    return Consumer<BookmarkProvider>(
      builder: (context, bookmark, _) {
        if (bookmark.isLoading) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentTeal),
            ),
          );
        }

        if (bookmark.collectionPapers.isEmpty) {
          return SliverFillRemaining(child: _buildEmpty());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final paper = bookmark.collectionPapers[index];
                return _SavedPaperCard(
                  paper: paper,
                  onTap: () => _openPaperDetail(paper),
                  onRemove: () => _removePaper(paper),
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: index * 60),
                    ).slideX(begin: 0.05, end: 0);
              },
              childCount: bookmark.collectionPapers.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 56,
            color: AppTheme.textDim.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No papers yet',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDim,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the bookmark icon on any paper to save it here',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Future<void> _removePaper(SavedPaper paper) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text('Remove paper?',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text(
          paper.title ?? 'Untitled paper',
          style: GoogleFonts.outfit(color: AppTheme.textDim, fontSize: 14),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.outfit(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<BookmarkProvider>().removePaper(
            userId: userId,
            collectionId: widget.collection.id,
            openalexId: paper.openalexId,
          );
    }
  }

  void _openPaperDetail(SavedPaper saved) {
    // Create a minimal Paper object from saved data for the detail screen
    final paper = Paper(
      paperId: saved.openalexId,
      title: saved.title ?? 'Untitled',
      journal: saved.journalName,
      publicationDate: saved.publicationDate?.toIso8601String().split('T').first,
      isOpenAccess: saved.isOpenAccess ?? false,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaperDetailScreen(paper: paper),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SAVED PAPER CARD
// ═════════════════════════════════════════════════════════════════════════

class _SavedPaperCard extends StatelessWidget {
  final SavedPaper paper;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedPaperCard({required this.paper, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.glassGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.glassBorder),
              ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title ?? 'Untitled',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (paper.journalName != null) ...[
                            Flexible(
                              child: Text(
                                paper.journalName!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.accentTeal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (paper.publicationDate != null)
                            Text(
                              _formatDate(paper.publicationDate!),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textDim,
                              ),
                            ),
                          if (paper.isOpenAccess == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Open',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.redAccent, size: 22),
                  onPressed: onRemove,
                  tooltip: 'Remove from collection',
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
