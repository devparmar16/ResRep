import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';

/// Dynamic screen that asks for missing profile fields after Google login.
/// Detects which fields are empty and only shows those.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Controllers keyed by DB column name (e.g., 'college_name').
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    // Create controllers for each missing field
    final auth = context.read<AuthProvider>();
    for (final entry in auth.missingFields.entries) {
      _controllers[entry.value] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    // Build map of DB column key -> user input value
    final fieldValues = <String, String>{};
    for (final entry in _controllers.entries) {
      fieldValues[entry.key] = entry.value.text.trim();
    }

    final success = await auth.completeProfile(fieldValues);

    if (!mounted) return;

    if (success) {
      // Check next step: domains or home
      if (auth.needsOnboarding) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  IconData _iconForField(String dbKey) {
    switch (dbKey) {
      case 'full_name':
        return Icons.person_outline;
      case 'college_name':
        return Icons.school_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final missing = auth.missingFields; // {label: dbKey}

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, Color(0xFFE052A0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ).animate().scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                  const SizedBox(height: 20),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.accent, Color(0xFFE052A0)],
                    ).createShader(bounds),
                    child: const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 6),
                  const Text(
                    'Just a few more details to get started',
                    style: TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 14,
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 32),

                  // Error
                  if (auth.error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFF43F5E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              const Color(0xFFF43F5E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          color: Color(0xFFF43F5E),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn().shake(duration: 400.ms),

                  // Dynamic form
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Build one field per missing entry
                          ...missing.entries.map((entry) {
                            final label = entry.key; // e.g. "College Name"
                            final dbKey = entry.value; // e.g. "college_name"
                            final controller = _controllers[dbKey]!;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextFormField(
                                controller: controller,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return '$label is required';
                                  }
                                  return null;
                                },
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: label,
                                  labelStyle: const TextStyle(
                                    color: AppTheme.textDim,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    _iconForField(dbKey),
                                    color: AppTheme.textDim,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppTheme.accent,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFF43F5E),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          GradientButton(
                            onPressed:
                                auth.isLoading ? null : _handleSubmit,
                            isLoading: auth.isLoading,
                            label: 'Continue',
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
