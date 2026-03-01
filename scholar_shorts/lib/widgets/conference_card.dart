import 'package:flutter/material.dart';
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
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    conference.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: AppTheme.textDim,
                  ),
                  onPressed: () {
                    // Placeholder for future bookmark implementation
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (conference.startDate != null || conference.endDate != null)
              _buildDateRow(context),
            if (conference.city != null || conference.country != null)
              _buildLocationRow(context),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildModeBadge(context),
                if (conference.url != null && conference.url!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(conference.url),
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Register / Site'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: AppTheme.background,
                      textStyle: Theme.of(context).textTheme.labelMedium,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Text('No Link Available', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final start = conference.startDate;
    final end = conference.endDate;
    final dateFormat = DateFormat('MMM d, yyyy');
    String dateStr = '';
    
    if (start != null && end != null) {
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        dateStr = dateFormat.format(start);
      } else {
        dateStr = '${dateFormat.format(start)} - ${dateFormat.format(end)}';
      }
    } else if (start != null) {
      dateStr = dateFormat.format(start);
    } else if (end != null) {
      dateStr = 'Ends ${dateFormat.format(end)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 14, color: AppTheme.textDim),
          const SizedBox(width: 6),
          Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    final parts = [conference.city, conference.country].where((p) => p != null && p.isNotEmpty).toList();
    final locStr = parts.join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: AppTheme.textDim),
          const SizedBox(width: 6),
          Expanded(child: Text(locStr, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildModeBadge(BuildContext context) {
    Color badgeColor;
    switch (conference.mode.toLowerCase()) {
      case 'online':
      case 'virtual':
        badgeColor = Colors.blueAccent;
        break;
      case 'hybrid':
        badgeColor = Colors.orangeAccent;
        break;
      default:
        badgeColor = AppTheme.textDim;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        conference.mode.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
