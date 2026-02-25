import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/journal_provider.dart';
import '../../models/domain.dart';
import '../../theme/app_theme.dart';
import 'journal_papers_screen.dart';
import '../../widgets/glass_card.dart';

/// Lists journals for a selected domain, with domain filter chips.
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
        provider.loadJournals(provider.selectedDomain);
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

          // ── Domain Filter Chips ──
          SizedBox(
            height: 48,
            child: Consumer<JournalProvider>(
              builder: (context, provider, _) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: DomainInfo.selectableDomains.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final domain = DomainInfo.selectableDomains[index];
                    final isSelected = domain.id == provider.selectedDomain;
                    return ChoiceChip(
                      label: Text('${domain.icon} ${domain.label}'),
                      selected: isSelected,
                      onSelected: (_) {
                        _searchController.clear();
                        provider.searchJournals('');
                        provider.selectDomain(domain.id);
                      },
                      selectedColor: domain.color.withOpacity(0.3),
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

          const SizedBox(height: 12),
          
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
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
                          onPressed: () =>
                              provider.loadJournals(provider.selectedDomain),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.journals.isEmpty) {
                  return const Center(
                    child: Text(
                      'No journals found for this domain.',
                      style: TextStyle(color: AppTheme.textDim),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
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
                    final domainInfo = DomainInfo.getById(provider.selectedDomain);

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
                            child: Text(
                              '${_formatCount(journal.paperCount)} papers',
                              style: const TextStyle(
                                color: AppTheme.textDim,
                                fontSize: 12,
                              ),
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
                );
              },
            ),
          ),
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
