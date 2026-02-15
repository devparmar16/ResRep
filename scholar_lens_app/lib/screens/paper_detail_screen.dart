import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/domain.dart';
import '../models/paper.dart';
import '../theme/app_theme.dart';

/// Full-screen detail page for a research paper.
class PaperDetailScreen extends StatelessWidget {
  final Paper paper;

  const PaperDetailScreen({super.key, required this.paper});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainInfo = DomainInfo.getInfo(paper.domain);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ─────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Paper Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            centerTitle: true,
          ),

          // ─── Content ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Domain badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: domainInfo.badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${domainInfo.icon} ${domainInfo.label}'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: domainInfo.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    paper.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meta row
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _metaChip('📅', 'Year: ${paper.year ?? '—'}'),
                      _metaChip(
                        '📝',
                        'Citations: ${paper.citationCount}',
                      ),
                      if (paper.fieldsOfStudy.isNotEmpty)
                        _metaChip(
                          '🏷️',
                          paper.fieldsOfStudy.join(', '),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Abstract section
                  _sectionLabel('Abstract'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: Text(
                      paper.abstract_ ??
                          'No abstract available for this paper.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Authors section
                  _sectionLabel('Authors'),
                  const SizedBox(height: 8),
                  if (paper.authors.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: paper.authors
                          .map((author) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.glassBorder),
                                ),
                                child: Text(
                                  author,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textDim,
                                  ),
                                ),
                              ))
                          .toList(),
                    )
                  else
                    const Text(
                      'Authors not listed.',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textDim),
                    ),
                  const SizedBox(height: 32),

                  // Action buttons
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppTheme.textDim,
      ),
    );
  }

  Widget _metaChip(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textDim),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    if (paper.url != null) {
      buttons.add(
        _actionButton(
          label: 'View on Semantic Scholar ↗',
          gradient: true,
          onTap: () => _launchUrl(paper.url!),
        ),
      );
    }

    if (paper.openAccessPdfUrl != null) {
      buttons.add(
        _actionButton(
          label: '📄 Open PDF',
          gradient: false,
          onTap: () => _launchUrl(paper.openAccessPdfUrl!),
        ),
      );
    }

    if (paper.doi != null) {
      buttons.add(
        _actionButton(
          label: '🔗 DOI',
          gradient: false,
          onTap: () => _launchUrl('https://doi.org/${paper.doi}'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  Widget _actionButton({
    required String label,
    required bool gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          gradient: gradient ? AppTheme.accentGradient : null,
          color: gradient ? null : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(30),
          border: gradient
              ? null
              : Border.all(color: AppTheme.glassBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: gradient ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
