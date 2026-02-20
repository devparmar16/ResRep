/// App-wide constants.
class AppConstants {
  // Pagination
  static const int papersPerPage = 10;
  static const int pagesPerBatch = 1;

  // API
  static const int apiDelayMs = 300; // rate-limit guard

  // Defaults
  static const List<String> defaultDomainIds = ['ai-ml', 'software-eng'];
}
