import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/paper.dart';
import '../theme/app_theme.dart';

/// A card widget displaying a research paper summary.
class PaperCard extends StatelessWidget {
  final Paper paper;
  final VoidCallback onTap;

  const PaperCard({super.key, required this.paper, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final domainInfo = DomainInfo.getInfo(paper.domain);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: domainInfo.badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${domainInfo.icon} ${domainInfo.label}'.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: domainInfo.color,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              paper.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // Abstract
            Text(
              paper.abstract_ ?? 'No abstract available.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textDim,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),

            // Meta info
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _metaItem('📅', '${paper.year ?? '—'}'),
                _metaItem('📝', '${paper.citationCount} cites'),
                if (paper.authors.isNotEmpty)
                  _metaItem(
                    '👤',
                    paper.authors.length > 3
                        ? '${paper.authors.take(3).join(', ')} et al.'
                        : paper.authors.join(', '),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppTheme.textDim),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
