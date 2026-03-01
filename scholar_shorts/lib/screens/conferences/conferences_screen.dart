import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/conference_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/conference_card.dart';

class ConferencesScreen extends StatefulWidget {
  const ConferencesScreen({super.key});

  @override
  State<ConferencesScreen> createState() => _ConferencesScreenState();
}

class _ConferencesScreenState extends State<ConferencesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _citySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ConferenceProvider>();
      if (!provider.hasContent && !provider.isLoading) {
        provider.loadConferences();
      }
    });
  }

  /// Trigger loadMore at 70% scroll position for smooth prefetch.
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.7) {
      context.read<ConferenceProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _citySearchController.dispose();
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
              'Conferences',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -1,
              ),
            ),
          ),

          // ── Filter Chips ──
          _buildFilterBar(context),

          const SizedBox(height: 8),

          // ── Conference List ──
          Expanded(
            child: Consumer<ConferenceProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.conferences.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentTeal),
                  );
                }

                if (provider.error != null && provider.conferences.isEmpty) {
                  return RefreshIndicator(
                    color: AppTheme.accentTeal,
                    backgroundColor: AppTheme.surfaceVariant,
                    onRefresh: () => provider.refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.textDim, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load conferences',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.error!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => provider.refresh(),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentTeal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (provider.conferences.isEmpty) {
                  return RefreshIndicator(
                    color: AppTheme.accentTeal,
                    backgroundColor: AppTheme.surfaceVariant,
                    onRefresh: () => provider.refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy,
                                color: AppTheme.textDim, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No conferences found',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your filters or pull to refresh',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textDim, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.accentTeal,
                  backgroundColor: AppTheme.surfaceVariant,
                  onRefresh: () => provider.refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.conferences.length +
                        (provider.isLoadingMore ? 1 : 0) +
                        (!provider.hasMore && provider.conferences.isNotEmpty
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      // Loading indicator at bottom
                      if (provider.isLoadingMore &&
                          index == provider.conferences.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                                color: AppTheme.accentTeal),
                          ),
                        );
                      }

                      // "End of list" indicator
                      if (!provider.hasMore &&
                          index == provider.conferences.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'All conferences loaded',
                              style: GoogleFonts.inter(
                                color: AppTheme.textDim,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }

                      return ConferenceCard(
                          conference: provider.conferences[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ──────────────────────────────────────────
  Widget _buildFilterBar(BuildContext context) {
    return Consumer<ConferenceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Mode filter
                _buildDropdownChip(
                  label: provider.modeFilter ?? 'Mode',
                  icon: Icons.wifi,
                  options: ['online', 'offline', 'hybrid'],
                  isSelected: provider.modeFilter != null,
                  color: Colors.blueAccent,
                  onSelected: (val) => provider
                      .setModeFilter(val == provider.modeFilter ? null : val),
                ),
                const SizedBox(width: 8),

                // Country filter
                _buildDropdownChip(
                  label: provider.countryFilter ?? 'Country',
                  icon: Icons.flag,
                  options: ['US', 'GB', 'CA', 'IN', 'DE', 'FR', 'AU', 'JP'],
                  isSelected: provider.countryFilter != null,
                  color: Colors.greenAccent,
                  onSelected: (val) => provider.setCountryFilter(
                      val == provider.countryFilter ? null : val),
                ),
                const SizedBox(width: 8),

                // City filter (text input)
                _buildCityChip(context, provider),
                const SizedBox(width: 8),

                // Domain filter
                _buildDropdownChip(
                  label: provider.domainFilter ?? 'Domain',
                  icon: Icons.category,
                  options: [
                    'AI',
                    'Machine Learning',
                    'Computer Science',
                    'Medicine',
                    'Physics',
                    'Biology',
                    'Engineering',
                  ],
                  isSelected: provider.domainFilter != null,
                  color: Colors.purpleAccent,
                  onSelected: (val) => provider.setDomainFilter(
                      val == provider.domainFilter ? null : val),
                ),

                // Clear all filters button
                if (provider.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.clear_all,
                        size: 16, color: Colors.redAccent),
                    label: const Text('Clear'),
                    labelStyle: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                    backgroundColor: AppTheme.surfaceVariant,
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () => provider.clearFilters(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required IconData icon,
    required List<String> options,
    required bool isSelected,
    required Color color,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.surface,
      itemBuilder: (context) {
        return options.map((opt) {
          return PopupMenuItem<String>(
            value: opt,
            child: Text(opt,
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontSize: 14)),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withAlpha(40)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.glassBorder,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : AppTheme.textDim),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppTheme.textDim,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 16, color: isSelected ? color : AppTheme.textDim),
          ],
        ),
      ),
    );
  }

  Widget _buildCityChip(BuildContext context, ConferenceProvider provider) {
    final isSelected = provider.cityFilter != null;
    return GestureDetector(
      onTap: () => _showCityDialog(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orangeAccent.withAlpha(40)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orangeAccent : AppTheme.glassBorder,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city,
                size: 14,
                color: isSelected ? Colors.orangeAccent : AppTheme.textDim),
            const SizedBox(width: 6),
            Text(
              provider.cityFilter ?? 'City',
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppTheme.textDim,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => provider.setCityFilter(null),
                child: const Icon(Icons.close,
                    size: 14, color: Colors.orangeAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCityDialog(BuildContext context, ConferenceProvider provider) {
    _citySearchController.text = provider.cityFilter ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Filter by City',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: _citySearchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. London, New York, Tokyo...',
              hintStyle: const TextStyle(color: AppTheme.textDim),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textDim, size: 20),
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
            onSubmitted: (val) {
              final trimmed = val.trim();
              provider.setCityFilter(trimmed.isEmpty ? null : trimmed);
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                provider.setCityFilter(null);
                Navigator.pop(ctx);
              },
              child: const Text('Clear',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () {
                final trimmed = _citySearchController.text.trim();
                provider.setCityFilter(trimmed.isEmpty ? null : trimmed);
                Navigator.pop(ctx);
              },
              child:
                  const Text('Apply', style: TextStyle(color: AppTheme.accentTeal)),
            ),
          ],
        );
      },
    );
  }
}
