import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../theme/app_theme.dart';

/// Horizontally scrollable domain filter chips.
class DomainFilterChips extends StatelessWidget {
  final PaperDomain? activeDomain;
  final Map<PaperDomain?, int> counts;
  final ValueChanged<PaperDomain?> onDomainSelected;

  const DomainFilterChips({
    super.key,
    required this.activeDomain,
    required this.counts,
    required this.onDomainSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip(
            label: '📚 All',
            count: counts[null] ?? 0,
            isActive: activeDomain == null,
            onTap: () => onDomainSelected(null),
          ),
          ...DomainInfo.allDomains.map((d) => _buildChip(
                label: '${d.icon} ${d.label}',
                count: counts[d.domain] ?? 0,
                isActive: activeDomain == d.domain,
                onTap: () => onDomainSelected(d.domain),
                activeColor: d.color,
              )),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required int count,
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
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.accentGradient : null,
            color: isActive ? null : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? Colors.transparent : AppTheme.glassBorder,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : AppTheme.textDim,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
