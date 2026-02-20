import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../models/domain.dart';
import '../theme/app_theme.dart';
import '../services/huggingface_embedding_service.dart';
import 'onboarding/domain_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final profile = auth.profile;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.accent, Color(0xFFE052A0)],
                  ).createShader(bounds),
                  child: const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      // ... (Avatar/Name logic) ...
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, Color(0xFFE052A0)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (profile?.fullName ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName ?? 'User',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.email ?? '',
                        style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 14,
                        ),
                      ),
                      if (profile?.collegeName.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile!.collegeName,
                          style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Selected domains
                      if (profile?.selectedDomains.isNotEmpty ?? false)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile!.selectedDomains.map((id) {
                            final d = DomainInfo.getById(id);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: d.badgeBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${d.icon} ${d.label}',
                                style: TextStyle(
                                  color: d.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DomainSelectionScreen(isEditMode: true),
                            ),
                          ).then((_) {
                            // Refresh feed on return
                            final feed = context.read<FeedProvider>();
                            final auth = context.read<AuthProvider>();
                            if (auth.profile != null) {
                               feed.refresh(auth.profile!.selectedDomains);
                            }
                          });
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.accent),
                        label: const Text('Edit Interests', style: TextStyle(color: AppTheme.accent)),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 40),

                // Server Settings (for mobile testing)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showServerSettingsDialog(context),
                    icon: const Icon(Icons.settings_ethernet_rounded,
                        size: 20, color: AppTheme.textDim),
                    label: const Text(
                      'Server Settings',
                      style: TextStyle(color: AppTheme.textDim),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await auth.signOut();
                      if (!context.mounted) return;
                      // Navigate to login, remove all routes
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF43F5E),
                      side: BorderSide(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final controller =
        TextEditingController(text: HuggingFaceEmbeddingService.customBaseUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Server Settings', 
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text(
              'Set the Ollama server URL.',
              style: TextStyle(color: AppTheme.textDim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Ollama Base URL',
                labelStyle: TextStyle(color: AppTheme.accent),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textDim)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textDim)),
          ),
          TextButton(
            onPressed: () {
              HuggingFaceEmbeddingService.updateUrl(controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Server URL updated')),
              );
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}
