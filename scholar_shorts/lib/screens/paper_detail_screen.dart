import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/domain.dart';
import '../models/paper.dart';
import '../services/arxiv_service.dart';
import '../services/ai_paper_service.dart';
import '../theme/app_theme.dart';
import 'pdf_view_screen.dart';

/// Full-screen detail page for a research paper.
class PaperDetailScreen extends StatefulWidget {
  final Paper paper;

  const PaperDetailScreen({super.key, required this.paper});

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  final ArxivService _arxivService = ArxivService();
  final AIPaperService _aiService = AIPaperService();
  String? _fallbackPdfUrl;
  bool _isCheckingArxiv = false;
  bool _isAbstractExpanded = false;

  // AI Insights state
  PaperInsight? _insight;
  bool _isLoadingInsight = true;
  String? _errorMessage; // Store error message if AI fails

  @override
  void initState() {
    super.initState();
    _loadAiInsights();
    if (widget.paper.openAccessPdfUrl == null ||
        widget.paper.openAccessPdfUrl!.isEmpty) {
      _checkArxiv();
    }
  }

  Future<void> _loadAiInsights() async {
    setState(() => _isLoadingInsight = true);
    try {
      final insight = await _aiService.getInsights(
        widget.paper.paperId,
        widget.paper.abstract_,
      );
      if (mounted) {
        setState(() {
          _insight = insight;
          _isLoadingInsight = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInsight = false;
          _errorMessage = 'AI Analysis Failed: ${e.toString().replaceAll('Exception:', '').trim()}';
        });
      }
    }
  }

  Future<void> _checkArxiv() async {
    setState(() => _isCheckingArxiv = true);
    final url = await _arxivService.findPdfUrl(widget.paper.title);
    if (mounted && url != null) {
      setState(() {
        _fallbackPdfUrl = url;
        _isCheckingArxiv = false;
      });
    } else {
      if (mounted) setState(() => _isCheckingArxiv = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showJargonExplanation(String word) async {
    // Show bottom sheet immediately with loading
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _JargonBottomSheet(
        word: word,
        aiService: _aiService,
        abstract_: widget.paper.abstract_,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfUrl = widget.paper.openAccessPdfUrl?.isNotEmpty == true
        ? widget.paper.openAccessPdfUrl
        : _fallbackPdfUrl;

    final domainInfo = DomainInfo.getInfo(widget.paper.domain);

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
                  // Domain badge + Difficulty badge row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: domainInfo.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${domainInfo.icon} ${domainInfo.label}'
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: domainInfo.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Difficulty Badge ──
                      _buildDifficultyBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    widget.paper.title,
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
                      _metaChip('📅', 'Year: ${widget.paper.year ?? '—'}'),
                      _metaChip(
                        '📝',
                        'Citations: ${widget.paper.citationCount}',
                      ),
                      if (widget.paper.fieldsOfStudy.isNotEmpty)
                        _metaChip(
                          '🏷️',
                          widget.paper.fieldsOfStudy.join(', '),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── ELI5 Simple Explanation ───────────
                  _buildEli5Section(),
                  const SizedBox(height: 20),

                  // ─── Key Takeaways ─────────────────────
                  _buildKeyTakeawaysSection(),
                  const SizedBox(height: 20),

                  // Quick Summary section (TL;DR)
                  if (widget.paper.tldr != null ||
                      widget.paper.abstract_ != null) ...[
                    _sectionLabel('Quick Summary'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 16, color: AppTheme.accent),
                              const SizedBox(width: 8),
                              Text(
                                'TL;DR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.paper.tldr ??
                                '${(widget.paper.abstract_?.split('.').take(2).join('.') ?? 'No summary available')}.',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Abstract with Jargon Highlighting ─
                  _sectionLabel('Abstract'),
                  const SizedBox(height: 8),
                  _buildAbstractWithJargon(),
                  const SizedBox(height: 24),

                  // Authors section
                  _sectionLabel('Authors'),
                  const SizedBox(height: 8),
                  if (widget.paper.authors.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.paper.authors
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
                  _buildActionButtons(context, pdfUrl),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // AI-POWERED SECTIONS
  // ═══════════════════════════════════════════

  /// Difficulty badge — shows colored chip next to domain.
  Widget _buildDifficultyBadge() {
    if (_isLoadingInsight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textDim),
        ),
      );
    }

    final level = _insight?.difficultyLevel ?? 'Unknown';
    Color bg;
    Color fg;
    String icon;
    switch (level.toLowerCase()) {
      case 'beginner':
        bg = const Color(0xFF1B3A2D);
        fg = const Color(0xFF4ADE80);
        icon = '🟢';
        break;
      case 'intermediate':
        bg = const Color(0xFF3A351B);
        fg = const Color(0xFFFBBF24);
        icon = '🟡';
        break;
      case 'expert':
        bg = const Color(0xFF3A1B1B);
        fg = const Color(0xFFF87171);
        icon = '🔴';
        break;
      default:
        bg = Colors.white10;
        fg = AppTheme.textDim;
        icon = '⚪';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$icon $level',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// ELI5 section — plain language summary.
  Widget _buildEli5Section() {
    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Simple Explanation'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 13),
                ),
                if (kIsWeb)
                   Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tip: Enable "cors-anywhere" demo mode or test on Android.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Simple Explanation'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, 
          // ... rest of container
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C3AED).withValues(alpha: 0.1),
                const Color(0xFF7C3AED).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFA78BFA)),
                  const SizedBox(width: 8),
                  Text(
                    'ELI5 Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFA78BFA),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingInsight)
                _loadingShimmer()
              else
                Text(
                  _insight?.eli5Summary ?? 'Summary not available.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Key takeaways section — 3 bullet points.
  Widget _buildKeyTakeawaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Key Takeaways'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'What You Need to Know',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF34D399),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingInsight)
                _loadingShimmer()
              else ...[
                if (_insight != null)
                  ...List.generate(
                    _insight!.keyTakeaways.length,
                    (i) {
                      final icons = ['🔍', '💡', '🚀'];
                      final labels = [
                        'What they found',
                        'Why it matters',
                        'What you can do',
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i < icons.length ? icons[i] : '•',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (i < labels.length)
                                    Text(
                                      labels[i],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF34D399),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _insight!.keyTakeaways[i],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Abstract with highlighted jargon words.
  Widget _buildAbstractWithJargon() {
    final abstractText = widget.paper.abstract_ ?? 'No abstract available.';
    final jargonWords = _insight?.jargonWords ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jargon hint
          if (jargonWords.isNotEmpty && !_isLoadingInsight)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 14, color: AppTheme.accent.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Tap highlighted words for definitions',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accent.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Abstract text (expanded/collapsed)
          if (_isAbstractExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildRichAbstract(abstractText, jargonWords),
              ),
            )
          else
            // Collapsed view — plain text (can't easily do RichText with maxLines)
            Text(
              abstractText,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.7,
              ),
            ),
          if ((abstractText.length) > 300)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isAbstractExpanded = !_isAbstractExpanded;
                  });
                },
                child: Text(
                  _isAbstractExpanded ? 'Read less' : 'Read more',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build RichText with tappable jargon words highlighted.
  Widget _buildRichAbstract(String text, List<String> jargonWords) {
    if (jargonWords.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.7,
        ),
      );
    }

    // Build spans by splitting text around jargon words
    final spans = <TextSpan>[];
    String remaining = text;

    while (remaining.isNotEmpty) {
      // Find earliest jargon match
      int earliestIndex = remaining.length;
      String? matchedWord;

      for (final word in jargonWords) {
        final idx = remaining.toLowerCase().indexOf(word.toLowerCase());
        if (idx != -1 && idx < earliestIndex) {
          earliestIndex = idx;
          matchedWord = word;
        }
      }

      if (matchedWord == null) {
        // No more jargon — add rest as plain text
        spans.add(TextSpan(
          text: remaining,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            height: 1.7,
          ),
        ));
        break;
      }

      // Add text before the jargon word
      if (earliestIndex > 0) {
        spans.add(TextSpan(
          text: remaining.substring(0, earliestIndex),
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            height: 1.7,
          ),
        ));
      }

      // Add the jargon word with highlight + tap
      final actualWord = remaining.substring(
          earliestIndex, earliestIndex + matchedWord.length);
      spans.add(TextSpan(
        text: actualWord,
        style: TextStyle(
          fontSize: 14,
          color: const Color(0xFFA78BFA),
          height: 1.7,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFA78BFA).withValues(alpha: 0.4),
          decorationStyle: TextDecorationStyle.dotted,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _showJargonExplanation(actualWord),
      ));

      remaining = remaining.substring(earliestIndex + matchedWord.length);
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Loading shimmer placeholder.
  Widget _loadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 14,
            width: i == 2 ? 150 : double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // EXISTING HELPER WIDGETS
  // ═══════════════════════════════════════════

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

  Widget _buildActionButtons(BuildContext context, String? pdfUrl) {
    final buttons = <Widget>[];

    if (pdfUrl != null) {
      buttons.add(
        _actionButton(
          label: _fallbackPdfUrl != null ? '📄 Read (arXiv)' : '📄 Read Paper',
          gradient: true,
          onTap: () => _openPdf(context, pdfUrl),
        ),
      );
    } else if (_isCheckingArxiv) {
      buttons.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.textDim),
              ),
              SizedBox(width: 8),
              Text(
                'Checking arXiv...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDim,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.paper.url != null) {
      buttons.add(
        _actionButton(
          label: 'View on Semantic Scholar ↗',
          gradient: false,
          onTap: () => _launchUrl(widget.paper.url!),
        ),
      );
    }

    if (widget.paper.doi != null) {
      buttons.add(
        _actionButton(
          label: '🔗 DOI',
          gradient: false,
          onTap: () => _launchUrl('https://doi.org/${widget.paper.doi}'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }

  void _openPdf(BuildContext context, String url) async {
    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open PDF URL')),
          );
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewScreen(
            pdfUrl: url,
            title: widget.paper.title,
          ),
        ),
      );
    }
  }

  Widget _actionButton({
    required String label,
    required bool gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient ? AppTheme.accentGradient : null,
          color: gradient ? null : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(30),
          border: gradient
              ? null
              : Border.all(color: AppTheme.glassBorder),
          boxShadow: gradient
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: gradient ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// JARGON BOTTOM SHEET (stateful for loading)
// ═══════════════════════════════════════════

class _JargonBottomSheet extends StatefulWidget {
  final String word;
  final AIPaperService aiService;
  final String? abstract_;

  const _JargonBottomSheet({
    required this.word,
    required this.aiService,
    this.abstract_,
  });

  @override
  State<_JargonBottomSheet> createState() => _JargonBottomSheetState();
}

class _JargonBottomSheetState extends State<_JargonBottomSheet> {
  String? _definition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDefinition();
  }

  Future<void> _loadDefinition() async {
    final def = await widget.aiService.explainJargon(
      widget.word,
      widget.abstract_,
    );
    if (mounted) {
      setState(() {
        _definition = def;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Word title
          Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                widget.word,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA78BFA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Definition
          if (_loading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Looking up definition...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textDim,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Text(
              _definition ?? 'Definition not available.',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
