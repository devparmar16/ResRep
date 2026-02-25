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

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final domainInfo = DomainInfo.getInfo(paper.domain);
    final color = domainInfo.color;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Aurora Background
          _buildAuroraBackground(color),
          
          // 2. Main Content Overlay (Bottom Anchored)
          _buildBottomDetails(paper, domainInfo),

          // 3. Side Action Sidebar
          _buildActionSidebar(paper),

          // 4. Subtle Navigation Hints
          _buildNavigationHints(),
        ],
      ),
    );
  }

  Widget _buildAuroraBackground(Color domainColor) {
    return Stack(
      children: [
        Container(color: AppTheme.background),
        // Layered blobs with parallax-like animation
        Positioned(
          top: -150,
          left: -100,
          child: _AuroraBlob(
            color: domainColor.withValues(alpha: 0.15),
            size: 400,
            duration: 8.seconds,
          ),
        ),
        Positioned(
          bottom: 100,
          right: -150,
          child: _AuroraBlob(
            color: AppTheme.accentViolet.withValues(alpha: 0.1),
            size: 500,
            duration: 12.seconds,
          ),
        ),
        Positioned(
          top: 300,
          right: 50,
          child: _AuroraBlob(
            color: AppTheme.accentTeal.withValues(alpha: 0.08),
            size: 300,
            duration: 10.seconds,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomDetails(Paper paper, DomainInfo domain) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 60, 80, 40), // More space on right for sidebar
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppTheme.background.withValues(alpha: 0.95),
              AppTheme.background.withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: domain.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: domain.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(domain.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    domain.label.toUpperCase(),
                    style: TextStyle(
                      color: domain.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

            const SizedBox(height: 12),

            // Title
            Text(
              paper.title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.25,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 10,
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: 0.1),

            const SizedBox(height: 12),

            // TL;DR / Summary Box
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    paper.tldr ?? "No summary available for this paper.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textPrimary.withValues(alpha: 0.9),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scaleXY(begin: 0.95),

            const SizedBox(height: 12),

            // Authors
            Text(
              'By ${paper.authors.take(2).join(", ")}${paper.authors.length > 2 ? " et al." : ""}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textDim.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSidebar(Paper paper) {
    return Positioned(
      right: 12,
      bottom: 120,
      child: Column(
        children: [
          _SidebarAction(
            icon: Icons.favorite_rounded,
            label: '1.2k',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 24),
          _SidebarAction(
            icon: Icons.bookmark_rounded,
            label: 'Save',
            color: AppTheme.accentTeal,
          ),
          const SizedBox(height: 24),
          _SidebarAction(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppTheme.accentSapphire,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.auroraGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentSapphire.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2.seconds, color: Colors.white38),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.5);
  }

  Widget _buildNavigationHints() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Icon(
          Icons.keyboard_arrow_up_rounded,
          color: AppTheme.textDim.withValues(alpha: 0.3),
          size: 24,
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -8, duration: 1.seconds),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _AuroraBlob({
    required this.color,
    required this.size,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .moveY(begin: -20, end: 20, duration: duration, curve: Curves.easeInOutSine)
     .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: duration, curve: Curves.easeInOutSine);
  }
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
