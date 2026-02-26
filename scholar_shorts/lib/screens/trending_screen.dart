import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/domain.dart';
import '../providers/trending_provider.dart';
import '../services/backend_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'paper_detail_screen.dart';

/// Full-screen socially trending papers feed.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrendingProvider>();
      if (!provider.hasContent && !provider.isLoading) {
        provider.loadTrending();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildDomainChips(),
            const SizedBox(height: 8),
            Expanded(child: _buildPapersList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.auroraGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentTeal.withAlpha(50),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Socially Trending',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Papers buzzing across 8 platforms',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05);
  }

  Widget _buildDomainChips() {
    return Consumer<TrendingProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(
                label: '🌐 All',
                isActive: provider.selectedDomain == null,
                onTap: () => provider.filterByDomain(null),
              ),
              ...DomainInfo.allDomains.map((d) => _chip(
                    label: '${d.icon} ${d.label}',
                    isActive: provider.selectedDomain == d.id,
                    onTap: () => provider.filterByDomain(d.id),
                    activeColor: d.color,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.auroraGradient : null,
            color: isActive ? null : Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? Colors.transparent : AppTheme.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : AppTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPapersList() {
    return Consumer<TrendingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasContent) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentTeal),
          );
        }

        if (provider.error != null && !provider.hasContent) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppTheme.textDim, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load trending papers',
                  style: GoogleFonts.inter(color: AppTheme.textDim, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => provider.refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal.withAlpha(30),
                    foregroundColor: AppTheme.accentTeal,
                  ),
                ),
              ],
            ),
          );
        }

        if (!provider.hasContent) {
          return Center(
            child: Text(
              'No trending papers found.\nCheck back later!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textDim, fontSize: 14),
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.accentTeal,
          backgroundColor: AppTheme.surfaceVariant,
          onRefresh: () => provider.refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: provider.papers.length,
            itemBuilder: (context, index) {
              final trending = provider.papers[index];
              return _TrendingPaperCard(
                trending: trending,
                index: index,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaperDetailScreen(paper: trending.paper),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// Trending Paper Card
// ═════════════════════════════════════════════════════════════════════════

class _TrendingPaperCard extends StatelessWidget {
  final TrendingPaper trending;
  final int index;
  final VoidCallback onTap;

  const _TrendingPaperCard({
    required this.trending,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final paper = trending.paper;
    final domainInfo = DomainInfo.getInfo(paper.domain);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Platform badges
              if (trending.trendingSources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: trending.trendingSources.map((source) {
                      return _platformBadge(source);
                    }).toList(),
                  ),
                ),

              // Domain badge + rank
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: domainInfo.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: domainInfo.color.withAlpha(80)),
                    ),
                    child: Text(
                      '${domainInfo.icon} ${domainInfo.label}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: domainInfo.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Score indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.auroraGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Title
              Text(
                paper.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Summary / Abstract snippet
              if (paper.tldr != null || paper.abstract_ != null) ...[
                const SizedBox(height: 8),
                Text(
                  paper.tldr ?? (paper.abstract_ ?? '').substring(0, (paper.abstract_!.length).clamp(0, 150)),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textDim,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // Bottom row: authors + citations
              Row(
                children: [
                  if (paper.authors.isNotEmpty) ...[
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textDim),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        paper.authors.take(2).join(', '),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (paper.citationCount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.format_quote_rounded, size: 14, color: AppTheme.accentTeal.withAlpha(180)),
                    const SizedBox(width: 3),
                    Text(
                      '${paper.citationCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentTeal.withAlpha(180),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate()
        .fadeIn(duration: 300.ms, delay: ((index * 50).clamp(0, 500)).ms)
        .slideY(begin: 0.05);
  }

  Widget _platformBadge(String source) {
    final info = _platformInfo(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: info.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  _PlatformInfo _platformInfo(String source) {
    switch (source) {
      case 'reddit':
        return _PlatformInfo('🔥', 'Reddit', const Color(0xFFFF4500));
      case 'hn':
        return _PlatformInfo('⚡', 'Hacker News', const Color(0xFFFF6600));
      case 'arxiv':
        return _PlatformInfo('📄', 'arXiv', const Color(0xFFB31B1B));
      case 'paperswithcode':
        return _PlatformInfo('🏆', 'PapersWithCode', const Color(0xFF21B573));
      case 'semantic_scholar':
        return _PlatformInfo('🧠', 'Semantic Scholar', const Color(0xFF1857B6));
      case 'crossref':
        return _PlatformInfo('🔗', 'CrossRef', const Color(0xFF2E86AB));
      case 'pubmed':
        return _PlatformInfo('🏥', 'PubMed', const Color(0xFF326599));
      case 'altmetric':
        return _PlatformInfo('📊', 'Altmetric', const Color(0xFFEC5E24));
      default:
        return _PlatformInfo('🌐', source, AppTheme.textDim);
    }
  }
}

class _PlatformInfo {
  final String emoji;
  final String label;
  final Color color;
  const _PlatformInfo(this.emoji, this.label, this.color);
}
