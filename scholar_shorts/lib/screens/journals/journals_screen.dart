import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/journal_provider.dart';
import '../../models/domain.dart';
import '../../theme/app_theme.dart';
import 'journal_papers_screen.dart';
import '../../widgets/glass_card.dart';

/// Lists journals for selected domains, with domain filter chips, publisher filter, and search.
class JournalsScreen extends StatefulWidget {
  const JournalsScreen({super.key});

  @override
  State<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends State<JournalsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JournalProvider>();
      if (provider.journals.isEmpty) {
        provider.loadJournals();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<JournalProvider>().loadMoreJournals();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Journals',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -1,
              ),
            ),
          ),

          // ── Domain Filter Chips (multi-select + "All") ──
          SizedBox(
            height: 48,
            child: Consumer<JournalProvider>(
              builder: (context, provider, _) {
                final allDomains = DomainInfo.selectableDomains;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: allDomains.length + 1, // +1 for "All"
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "All" chip
                      final isSelected = provider.isAllSelected;
                      return ChoiceChip(
                        label: const Text('📚 All'),
                        selected: isSelected,
                        onSelected: (_) {
                          _searchController.clear();
                          provider.searchJournals('');
                          provider.selectAll();
                        },
                        selectedColor: AppTheme.accent.withOpacity(0.3),
                        backgroundColor: AppTheme.surfaceVariant,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textDim,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.accent.withOpacity(0.5)
                                : AppTheme.glassBorder,
                          ),
                        ),
                      );
                    }

                    final domain = allDomains[index - 1];
                    final isSelected = provider.selectedDomains.contains(domain.id);
                    return FilterChip(
                      label: Text('${domain.icon} ${domain.label}'),
                      selected: isSelected,
                      onSelected: (_) {
                        _searchController.clear();
                        provider.searchJournals('');
                        provider.toggleDomain(domain.id);
                      },
                      selectedColor: domain.color.withOpacity(0.3),
                      backgroundColor: AppTheme.surfaceVariant,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textDim,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: isSelected
                              ? domain.color.withOpacity(0.5)
                              : AppTheme.glassBorder,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Publisher Filter Chips ──
          Consumer<JournalProvider>(
            builder: (context, provider, _) {
              final publishers = provider.availablePublishers;
              if (publishers.isEmpty) return const SizedBox.shrink();

              return SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: publishers.length + 1, // +1 for "All Publishers"
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = provider.publisherFilter == null;
                      return ChoiceChip(
                        label: const Text('All Publishers'),
                        selected: isSelected,
                        onSelected: (_) => provider.setPublisherFilter(null),
                        selectedColor: AppTheme.accentTeal.withOpacity(0.25),
                        backgroundColor: AppTheme.surfaceVariant,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textDim,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: AppTheme.glassBorder),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }
                    final pub = publishers[index - 1];
                    final isSelected = provider.publisherFilter == pub;
                    return ChoiceChip(
                      label: Text(pub),
                      selected: isSelected,
                      onSelected: (_) => provider.setPublisherFilter(isSelected ? null : pub),
                      selectedColor: AppTheme.accentSapphire.withOpacity(0.25),
                      backgroundColor: AppTheme.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textDim,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.accentSapphire.withOpacity(0.5)
                              : AppTheme.glassBorder,
                        ),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<JournalProvider>().searchJournals(val);
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search journals...',
                hintStyle: const TextStyle(color: AppTheme.textDim),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textDim, size: 20),
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
          
          const SizedBox(height: 12),

          // ── Journal List ──
          Expanded(
            child: Consumer<JournalProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingJournals) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  );
                }

                if (provider.error != null) {
                  return RefreshIndicator(
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.surfaceVariant,
                    onRefresh: () async {
                      await provider.loadJournals(null, true);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Error loading journals',
                              style: TextStyle(color: AppTheme.textDim),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.error!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.loadJournals(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (provider.journals.isEmpty) {
                  return RefreshIndicator(
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.surfaceVariant,
                    onRefresh: () async {
                      await provider.loadJournals(null, true);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: const Text(
                          'No journals found.',
                          style: TextStyle(color: AppTheme.textDim),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surfaceVariant,
                  onRefresh: () async {
                    await provider.loadJournals(null, true);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.journals.length + (provider.hasMoreJournals ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.journals.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          ),
                        );
                      }

                    final journal = provider.journals[index];
                    final domainInfo = DomainInfo.getById(journal.domain);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 16,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: domainInfo.color.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                domainInfo.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          title: Text(
                            journal.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (journal.publisher?.isNotEmpty == true)
                                  Text(
                                    '🏛 ${journal.publisher}',
                                    style: TextStyle(
                                      color: AppTheme.accentTeal.withOpacity(0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  '${_formatCount(journal.paperCount)} papers',
                                  style: const TextStyle(
                                    color: AppTheme.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: domainInfo.color.withOpacity(0.6),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JournalPapersScreen(
                                  journalId: journal.journalId,
                                  journalName: journal.name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ), // end ListView.builder
              ); // end RefreshIndicator
            }, // end Consumer builder
          ), // end Consumer
          ), // end Expanded
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
