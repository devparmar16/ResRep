import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'services/huggingface_embedding_service.dart';
import 'providers/feed_provider.dart';
import 'providers/search_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/trending_provider.dart';
import 'providers/bookmark_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/profile_completion_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/domain_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize embeddings service (local/remote)
  await HuggingFaceEmbeddingService.init();

  runApp(const ScholarShortsApp());
}

class ScholarShortsApp extends StatelessWidget {
  const ScholarShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => TrendingProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
      ],
      child: MaterialApp(
        title: 'Scholar Shorts',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme, // Force dark theme or customize
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/complete-profile': (context) => const ProfileCompletionScreen(),
          '/onboarding': (context) => const DomainSelectionScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
