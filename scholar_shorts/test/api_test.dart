import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_shorts/services/backend_api_service.dart';

void main() {
  test('fetch feed', () async {
    final api = BackendApiService();
    try {
      final feed = await api.fetchFeed(userId: 'test', interests: ['cs']);
      print('Feed length: ${feed.length}');
      
      final trending = await api.fetchSocialTrending(domain: 'cs');
      print('Trending length: ${trending.length}');
    } catch (e, st) {
      print('ERROR PARSING:');
      print(e);
      print(st);
      rethrow;
    }
  });
}
