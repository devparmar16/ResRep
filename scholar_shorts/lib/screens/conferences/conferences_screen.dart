import 'package:flutter/material.dart';
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ConferenceProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Conferences',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: Consumer<ConferenceProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.conferences.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal));
                }

                if (provider.error != null && provider.conferences.isEmpty) {
                  return Center(
                    child: Text(
                      'Failed to load conferences.\n${provider.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (provider.conferences.isEmpty) {
                  return Center(
                    child: Text(
                      'No conferences found.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.accentTeal,
                  backgroundColor: AppTheme.surfaceVariant,
                  onRefresh: () => provider.refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.conferences.length +
                        (provider.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.conferences.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: AppTheme.accentTeal),
                          ),
                        );
                      }
                      return ConferenceCard(conference: provider.conferences[index]);
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

  Widget _buildFilterBar(BuildContext context) {
    final provider = context.watch<ConferenceProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppTheme.surfaceVariant.withOpacity(0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context: context,
              label: provider.modeFilter ?? 'Mode',
              options: ['online', 'offline', 'hybrid'],
              onSelected: (val) => provider.setModeFilter(val == provider.modeFilter ? null : val),
              isSelected: provider.modeFilter != null,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: provider.countryFilter ?? 'Country',
              options: ['US', 'GB', 'CA', 'IN', 'DE', 'FR'], // Preset popular options for simplicity
              onSelected: (val) => provider.setCountryFilter(val == provider.countryFilter ? null : val),
              isSelected: provider.countryFilter != null,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: provider.domainFilter ?? 'Domain',
              options: ['AI', 'Medicine', 'Computer Science', 'Physics', 'Biology'],
              onSelected: (val) => provider.setDomainFilter(val == provider.domainFilter ? null : val),
              isSelected: provider.domainFilter != null,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: provider.publisherFilter ?? 'Publisher',
              options: ['IEEE', 'ACM', 'Springer', 'Elsevier'],
              onSelected: (val) => provider.setPublisherFilter(val == provider.publisherFilter ? null : val),
              isSelected: provider.publisherFilter != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required List<String> options,
    required Function(String) onSelected,
    required bool isSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) {
        return options.map((opt) {
          return PopupMenuItem<String>(
            value: opt,
            child: Text(opt),
          );
        }).toList();
      },
      child: Chip(
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isSelected ? AppTheme.background : AppTheme.textPrimary,
          ),
        ),
        backgroundColor: isSelected ? AppTheme.accentTeal : AppTheme.surfaceVariant,
        side: BorderSide.none,
      ),
    );
  }
}
