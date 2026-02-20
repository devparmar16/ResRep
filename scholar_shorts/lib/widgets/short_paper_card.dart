import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/paper.dart';
import '../models/domain.dart';
import '../theme/app_theme.dart';

class ShortPaperCard extends StatefulWidget {
  final Paper paper;
  final VoidCallback onTap;

  const ShortPaperCard({
    super.key,
    required this.paper,
    required this.onTap,
  });

  @override
  State<ShortPaperCard> createState() => _ShortPaperCardState();
}

class _ShortPaperCardState extends State<ShortPaperCard> {
  bool _isAbstractExpanded = false;

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final domainInfo = DomainInfo.getInfo(paper.domain);
    final color = domainInfo.color;

    // Use TLDR if available, otherwise heuristic summary (first sentence)
    final String summaryText = paper.tldr ?? 
        (paper.abstract_?.split('.').take(2).join('.') ?? 'No summary available.');
    
    // Clean up summary (remove trailing period if join added one, or ensure one)
    final cleanSummary = summaryText.endsWith('.') ? summaryText : '$summaryText.';

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.15),
                  AppTheme.background,
                  AppTheme.background,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          
          // Decorative blurry blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Top Bar: Domain Badge + Date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: domainInfo.badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(domainInfo.icon,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              domainInfo.label.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (paper.year != null)
                        Text(
                          '${paper.year}',
                          style: TextStyle(
                            color: AppTheme.textDim.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                  const Spacer(flex: 1),

                  // Image or Icon
                  Center(
                    child: Icon(
                      domainInfo.icon == '💻' ? Icons.computer : Icons.science,
                      size: 60,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

                  const Spacer(flex: 2),

                  // Title
                  Text(
                    paper.title,
                    style: GoogleFonts.outfit(
                      fontSize: 24, // Slightly smaller to fit more content
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.1),

                  const SizedBox(height: 12),

                  // Authors
                  if (paper.authors.isNotEmpty)
                    Text(
                      'By ${paper.authors.take(2).join(", ")}${paper.authors.length > 2 ? " et al." : ""}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textDim,
                        fontStyle: FontStyle.italic,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 20),

                  // SUMMARY SECTION (New)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.accent),
                            const SizedBox(width: 8),
                            Text(
                              'QUICK SUMMARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent.withValues(alpha: 0.8),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cleanSummary,
                          style: GoogleFonts.inter(
                            fontSize: 14, // Readable
                            height: 1.5,
                            color: AppTheme.textPrimary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                  const SizedBox(height: 16),

                  // Abstract (Expandable)
                  Expanded(
                    flex: _isAbstractExpanded ? 10 : 0, // Flexible when expanded
                    child: SingleChildScrollView(
                       physics: _isAbstractExpanded ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text(
                            'ABSTRACT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDim.withValues(alpha: 0.5),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAbstractExpanded = !_isAbstractExpanded;
                              });
                            },
                            child: AnimatedCrossFade(
                              duration: const Duration(milliseconds: 300),
                              crossFadeState: _isAbstractExpanded 
                                  ? CrossFadeState.showSecond 
                                  : CrossFadeState.showFirst,
                              firstChild: Text(
                                paper.abstract_ ?? "No abstract.",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppTheme.textDim,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondChild: Text(
                                paper.abstract_ ?? "No abstract.",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppTheme.textDim,
                                ),
                              ),
                            ),
                          ),
                          if (!_isAbstractExpanded && (paper.abstract_?.length ?? 0) > 200)
                             GestureDetector(
                               onTap: () => setState(() => _isAbstractExpanded = true),
                               child: Padding(
                                 padding: const EdgeInsets.only(top: 4),
                                 child: Text(
                                   'Read more...',
                                   style: TextStyle(
                                     color: AppTheme.accent,
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                   ),
                                 ),
                               ),
                             ),
                         ],
                       ),
                    ),
                  ),

                  if (!_isAbstractExpanded) const Spacer(flex: 1), // Push bottom up if not expanded

                  // Bottom Action
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Tap card to open full paper',
                          style: TextStyle(
                            color: AppTheme.textDim.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppTheme.textDim.withValues(alpha: 0.5),
                        )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .moveY(begin: 0, end: -5, duration: 1000.ms, curve: Curves.easeInOut),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1000.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
