import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: domainInfo.color.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle background glow
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: domainInfo.color.withValues(alpha: 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: domainInfo.color.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Domain Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: domainInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: domainInfo.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(domainInfo.icon, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Text(
                                domainInfo.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: domainInfo.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Year
                        if (paper.year != null)
                          Text(
                            '${paper.year}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDim.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
        
                    // Title
                    Text(
                      paper.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
        
                    // Abstract Snippet
                    Text(
                      paper.abstract_ ?? 'No abstract available.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textDim.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
        
                    // Meta items footer
                    Row(
                      children: [
                        _metaItem(Icons.format_quote_rounded, '${paper.citationCount}'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            paper.authors.isNotEmpty 
                                ? 'By ${paper.authors.first}${paper.authors.length > 1 ? " et al." : ""}'
                                : 'Unknown Author',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDim.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.accentTeal.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
