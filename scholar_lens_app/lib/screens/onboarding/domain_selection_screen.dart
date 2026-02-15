import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/domain.dart';
import '../../providers/auth_provider.dart';
import '../../providers/domain_selection_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

/// Domain selection onboarding screen.
class DomainSelectionScreen extends StatelessWidget {
  const DomainSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DomainSelectionProvider(),
      child: const _DomainSelectionBody(),
    );
  }
}

class _DomainSelectionBody extends StatelessWidget {
  const _DomainSelectionBody();

  Future<void> _handleContinue(BuildContext context) async {
    final selector = context.read<DomainSelectionProvider>();
    final auth = context.read<AuthProvider>();

    selector.setSaving(true);

    try {
      final domains = selector.getFinalSelection();
      await auth.updateDomains(domains);

      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    } finally {
      selector.setSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domains = DomainInfo.selectableDomains;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0b0e17),
              Color(0xFF151929),
              Color(0xFF0d1120),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Header
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.accent, Color(0xFFE052A0)],
                  ).createShader(bounds),
                  child: const Text(
                    'Pick Your Interests',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
                const Text(
                  'Select domains to personalize your research feed.\nYou can change these later.',
                  style: TextStyle(
                    color: AppTheme.textDim,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 28),

                // Domain grid
                Expanded(
                  child: Consumer<DomainSelectionProvider>(
                    builder: (context, selector, _) {
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: domains.length,
                        itemBuilder: (context, index) {
                          final domain = domains[index];
                          final isSelected = selector.isSelected(domain.id);

                          return GestureDetector(
                            onTap: () => selector.toggle(domain.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? domain.color.withValues(alpha: 0.15)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? domain.color.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              domain.color.withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        domain.icon,
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? domain.color
                                              : Colors.white
                                                  .withValues(alpha: 0.08),
                                          border: Border.all(
                                            color: isSelected
                                                ? domain.color
                                                : Colors.white
                                                    .withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    domain.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? domain.color
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Text(
                                      domain.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textDim,
                                        height: 1.4,
                                        overflow: TextOverflow.fade,
                                      ),
                                      maxLines: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate(delay: (100 + index * 80).ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                duration: 300.ms,
                              );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Continue button
                Consumer<DomainSelectionProvider>(
                  builder: (context, selector, _) {
                    return Column(
                      children: [
                        Text(
                          selector.selectedCount > 0
                              ? '${selector.selectedCount} domain${selector.selectedCount > 1 ? 's' : ''} selected'
                              : 'Skip to use defaults',
                          style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GradientButton(
                          onPressed: selector.isSaving
                              ? null
                              : () => _handleContinue(context),
                          isLoading: selector.isSaving,
                          label: selector.selectedCount > 0
                              ? 'Continue'
                              : 'Skip & Continue',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
