import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/journal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../paper_detail_screen.dart';

/// Shows papers for a specific journal, with Top / Recent / Trending tabs.
class JournalPapersScreen extends StatefulWidget {
  final String journalId;
  final String journalName;

  const JournalPapersScreen({
    super.key,
    required this.journalId,
    required this.journalName,
  });

  @override
  State<JournalPapersScreen> createState() => _JournalPapersScreenState();
}

class _JournalPapersScreenState extends State<JournalPapersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _sortOptions = ['top', 'recent', 'trending'];
  final List<String> _sortLabels = ['Top Cited', 'Most Recent', 'Trending'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalProvider>().loadJournalPapers(
            widget.journalId,
            sort: 'top',
          );
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final sort = _sortOptions[_tabController.index];
      context.read<JournalProvider>().loadJournalPapers(
            widget.journalId,
            sort: sort,
          );
    }
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.journalName,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textDim,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: _sortLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                final sort = _sortOptions[_tabController.index];
                context.read<JournalProvider>().loadJournalPapers(
                      widget.journalId,
                      sort: sort,
                      query: val,
                    );
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search within journal...',
                hintStyle: const TextStyle(color: AppTheme.textDim),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textDim, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textDim, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    final sort = _sortOptions[_tabController.index];
                    context.read<JournalProvider>().loadJournalPapers(
                          widget.journalId,
                          sort: sort,
                          query: '',
                        );
                  },
                ),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
              ),
            ),
          ),
          // ── Papers List ──
          Expanded(
            child: Consumer<JournalProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingPapers) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Error loading papers',
                          style: TextStyle(color: AppTheme.textDim),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final sort = _sortOptions[_tabController.index];
                            provider.loadJournalPapers(widget.journalId, sort: sort, query: _searchController.text);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.journalPapers.isEmpty) {
                  return Center(
                    child: Text(
                      provider.journalSearchQuery.isNotEmpty 
                          ? 'No papers found matching "${provider.journalSearchQuery}".' 
                          : 'No papers found.',
                      style: const TextStyle(color: AppTheme.textDim),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surfaceVariant,
                  onRefresh: () async {
                    final sort = _sortOptions[_tabController.index];
                    await context.read<JournalProvider>().loadJournalPapers(
                          widget.journalId,
                          sort: sort,
                          query: _searchController.text,
                          ignoreCache: true,
                        );
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!provider.isLoadingMorePapers &&
                          provider.hasMorePapers &&
                          scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent * 0.7) {
                        provider.loadMoreJournalPapers(widget.journalId);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: provider.journalPapers.length + (provider.isLoadingMorePapers ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.journalPapers.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(color: AppTheme.accent),
                            ),
                          );
                        }

                        final paper = provider.journalPapers[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            borderRadius: 16,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              title: Text(
                                paper.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (paper.year != null)
                                      _infoChip('${paper.year}'),
                                    _infoChip(
                                      '${paper.citationCount} citations',
                                      icon: Icons.format_quote_rounded,
                                    ),
                                    if (paper.authors.isNotEmpty)
                                      Text(
                                        'By ${paper.authors.first}',
                                        style: const TextStyle(
                                          color: AppTheme.textDim,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaperDetailScreen(
                                      paper: paper,
                                      isFromJournalSection: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),


    );
  }

  Widget _infoChip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppTheme.accent),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
