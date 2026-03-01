import 'dart:io';
import 'package:scholar_shorts/services/backend_api_service.dart';

void main() async {
  try {
    print('Testing feed...');
    final api = BackendApiService();
    final feed = await api.fetchFeed(userId: 'test', interests: ['cs']);
    print('Feed length: ${feed.length}');

    print('Testing trending...');
    final trending = await api.fetchSocialTrending(domain: 'cs');
    print('Trending length: ${trending.length}');
    
    exit(0);
  } catch (e, st) {
    print('Error: $e');
    print(st);
    exit(1);
  }
}
