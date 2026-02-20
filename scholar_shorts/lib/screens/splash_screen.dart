import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Splash screen — checks session and routes accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();

    if (!mounted) return;

    // Wait for animation to finish
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    if (!auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else if (auth.needsProfileCompletion) {
      Navigator.of(context).pushReplacementNamed('/complete-profile');
    } else if (auth.needsOnboarding) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Color(0xFF0b0e17),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, Color(0xFFE052A0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 28),
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFFE052A0)],
                ).createShader(bounds),
                child: const Text(
                  'ScholarLens',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms),
              const SizedBox(height: 8),
              const Text(
                'Research Paper Explorer',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDim,
                  letterSpacing: 2,
                ),
              )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 500.ms),
              const SizedBox(height: 48),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: AppTheme.accent.withValues(alpha: 0.6),
                  strokeWidth: 2.5,
                ),
              ).animate(delay: 900.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
