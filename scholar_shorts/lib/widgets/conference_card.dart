import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/conference.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class ConferenceCard extends StatelessWidget {
  final Conference conference;

  const ConferenceCard({super.key, required this.conference});

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _showDetailSheet(context),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _modeColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Icon(_modeIcon, color: _modeColor, size: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      conference.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Date ──
              if (conference.startDate != null || conference.endDate != null)
                _buildInfoRow(Icons.calendar_today, _dateString, AppTheme.accentTeal),

              // ── Location ──
              if (conference.locationString.isNotEmpty)
                _buildInfoRow(Icons.location_on, conference.locationString, Colors.orangeAccent),

              const SizedBox(height: 10),

              // ── Bottom row: mode badge + register ──
              Row(
                children: [
                  _buildModeBadge(),
                  const Spacer(),
                  if (conference.url != null && conference.url!.isNotEmpty)
                    _buildRegisterButton()
                  else
                    Text('Tap for details',
                        style: GoogleFonts.inter(color: AppTheme.textDim, fontSize: 11)),
                ],
              ),

              // ── Labels ──
              if (conference.labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: conference.labels.take(4).map((label) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent.withAlpha(40)),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withAlpha(180)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: AppTheme.textDim, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _modeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _modeColor.withAlpha(80)),
      ),
      child: Text(
        conference.mode.toUpperCase(),
        style: GoogleFonts.inter(
          color: _modeColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: () => _launchUrl(conference.url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accentTeal, AppTheme.accentTeal.withAlpha(180)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text('Register',
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Color get _modeColor {
    switch (conference.mode.toLowerCase()) {
      case 'online':
      case 'virtual':
        return Colors.blueAccent;
      case 'hybrid':
        return Colors.orangeAccent;
      default:
        return AppTheme.accentTeal;
    }
  }

  IconData get _modeIcon {
    switch (conference.mode.toLowerCase()) {
      case 'online':
      case 'virtual':
        return Icons.videocam;
      case 'hybrid':
        return Icons.swap_horiz;
      default:
        return Icons.location_on;
    }
  }

  String get _dateString {
    final df = DateFormat('MMM d, yyyy');
    final s = conference.startDate;
    final e = conference.endDate;
    if (s != null && e != null) {
      if (s.year == e.year && s.month == e.month && s.day == e.day) {
        return df.format(s);
      }
      return '${df.format(s)} – ${df.format(e)}';
    }
    if (s != null) return df.format(s);
    if (e != null) return 'Ends ${df.format(e)}';
    return '';
  }

  // ── Detail Bottom Sheet ────────────────────────────────
  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textDim.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    conference.title,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mode badge
                  _buildModeBadge(),
                  const SizedBox(height: 16),

                  // ── Date ──
                  if (_dateString.isNotEmpty)
                    _detailRow(Icons.calendar_today, 'Date', _dateString, AppTheme.accentTeal),

                  // ── Venue ──
                  if (conference.venueName != null && conference.venueName!.isNotEmpty)
                    _detailRow(Icons.business, 'Venue', conference.venueName!, Colors.purpleAccent),

                  // ── Location ──
                  if (conference.locationString.isNotEmpty)
                    _detailRow(Icons.location_on, 'Location', conference.locationString, Colors.orangeAccent),

                  // ── Description ──
                  if (conference.description != null && conference.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'About',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      conference.description!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textDim,
                        height: 1.5,
                      ),
                    ),
                  ],

                  // ── Labels / Tags ──
                  if (conference.labels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tags',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: conference.labels.map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.accent.withAlpha(50)),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Action buttons ──
                  Row(
                    children: [
                      // Map button
                      if (conference.mapsUrl != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchUrl(conference.mapsUrl),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('View on Map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              side: const BorderSide(color: Colors.orangeAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (conference.mapsUrl != null && conference.url != null)
                        const SizedBox(width: 12),
                      // Register button
                      if (conference.url != null && conference.url!.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchUrl(conference.url),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Register / Visit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, size: 16, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: AppTheme.textDim, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
