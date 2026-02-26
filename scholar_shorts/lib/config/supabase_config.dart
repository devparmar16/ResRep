/// Supabase project configuration.
/// Replace these with your actual Supabase project credentials.
class SupabaseConfig {
  // TODO: Replace with your Supabase project URL
  static const String url = 'https://asubydaidzfaqanrzzsc.supabase.co';

  // TODO: Replace with your Supabase anon (public) key
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzdWJ5ZGFpZHpmYXFhbnJ6enNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0OTU3MTMsImV4cCI6MjA4NTA3MTcxM30.OWfWWUr_F_xycGXAJES-6yAScACeI7tlwAp1vQVif-Q';

  // Table names
  static const String loginTable = 'login';
  static const String collectionsTable = 'collections';
  static const String savedPapersTable = 'saved_papers';
}
