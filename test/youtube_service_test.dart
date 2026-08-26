import 'package:airstream/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YouTube dual-stream URL validation', () {
    test('extracts IDs from supported direct video URLs', () {
      expect(
        YouTubeService.videoIdFromUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.videoIdFromUrl(
          'https://youtu.be/dQw4w9WgXcQ?t=10',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeService.videoIdFromUrl(
          'https://youtube.com/live/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects handles, channel URLs, raw IDs and foreign hosts', () {
      expect(YouTubeService.videoIdFromUrl('@channel'), isNull);
      expect(YouTubeService.videoIdFromUrl('dQw4w9WgXcQ'), isNull);
      expect(
        YouTubeService.videoIdFromUrl('https://youtube.com/@channel/live'),
        isNull,
      );
      expect(
        YouTubeService.videoIdFromUrl(
          'https://example.com/watch?v=dQw4w9WgXcQ',
        ),
        isNull,
      );
    });
  });
}
