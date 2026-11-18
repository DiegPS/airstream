import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const youtubeSettings = SettingsModel(youtubeHandle: '@channel');
  const multiPlatformSettings = SettingsModel(
    youtubeHandle: '@channel',
    twitchChannel: 'streamer',
  );

  test('is idle when the user has not requested chat', () {
    expect(
      resolveChatSessionPhase(
        requested: false,
        settings: youtubeSettings,
        statuses: const {
          'youtube': (ServiceStatus.connected, null),
        },
      ),
      ChatSessionPhase.idle,
    );
  });

  test('is failed when every configured platform failed', () {
    expect(
      resolveChatSessionPhase(
        requested: true,
        settings: multiPlatformSettings,
        statuses: const {
          'youtube': (ServiceStatus.error, 'not found'),
          'twitch': (ServiceStatus.error, 'unavailable'),
        },
      ),
      ChatSessionPhase.failed,
    );
  });

  test('reports a partial connection when one platform fails', () {
    expect(
      resolveChatSessionPhase(
        requested: true,
        settings: multiPlatformSettings,
        statuses: const {
          'youtube': (ServiceStatus.error, 'not found'),
          'twitch': (ServiceStatus.connected, null),
        },
      ),
      ChatSessionPhase.partiallyConnected,
    );
  });

  test('YouTube ending resolves the session without masking a live platform',
      () {
    const ended = (ServiceStatus.ended, null);
    const connected = (ServiceStatus.connected, null);
    expect(
        resolveChatSessionPhase(
          requested: true,
          settings: youtubeSettings,
          statuses: {'youtube': ended},
        ),
        ChatSessionPhase.ended);
    expect(
        resolveChatSessionPhase(
          requested: true,
          settings: multiPlatformSettings,
          statuses: {'youtube': ended, 'twitch': connected},
        ),
        ChatSessionPhase.connected);
    expect(combineYoutubeChatStatuses(ended, ended), ended);
    expect(combineYoutubeChatStatuses(ended, connected), connected);
  });

  test('a dual YouTube chat with one failed stream is partly connected', () {
    const connected = (ServiceStatus.connected, null);
    const failed = (ServiceStatus.error, 'Video not found');
    // Not "connecting" forever: connected, carrying the failure detail.
    expect(combineYoutubeChatStatuses(connected, failed),
        (ServiceStatus.connected, 'Video not found'));
    expect(combineYoutubeChatStatuses((ServiceStatus.error, null), connected),
        (ServiceStatus.connected, youtubePartialStatus));
    expect(combineYoutubeChatStatuses(connected, connected), connected);
  });

  test('starts as connecting before the first status event arrives', () {
    expect(
      resolveChatSessionPhase(
        requested: true,
        settings: youtubeSettings,
        statuses: const {},
      ),
      ChatSessionPhase.connecting,
    );
  });

  test('rejects a stale idle event while a configured chat is requested', () {
    expect(
      shouldAcceptServiceStatus(
        chatRequested: true,
        platformConfigured: true,
        status: ServiceStatus.idle,
      ),
      isFalse,
    );
    expect(
      shouldAcceptServiceStatus(
        chatRequested: false,
        platformConfigured: true,
        status: ServiceStatus.idle,
      ),
      isTrue,
    );
    expect(
      shouldAcceptServiceStatus(
        chatRequested: false,
        platformConfigured: true,
        status: ServiceStatus.error,
      ),
      isFalse,
    );
  });

  test('ignores disabled platforms when resolving the session', () {
    const settings = SettingsModel(
      youtubeHandle: '@offline',
      youtubeEnabled: false,
      twitchChannel: 'online',
    );
    expect(
      resolveChatSessionPhase(
        requested: true,
        settings: settings,
        statuses: const {
          'youtube': (ServiceStatus.error, 'not found'),
          'twitch': (ServiceStatus.connected, null),
        },
      ),
      ChatSessionPhase.connected,
    );
  });

  test('invalid and duplicate dual YouTube URLs are not configured', () {
    for (final vertical in [
      'https://example.com/video',
      'https://youtu.be/dQw4w9WgXcQ',
    ]) {
      final settings = SettingsModel(
        youtubeDualStreamEnabled: true,
        youtubeHorizontalUrl: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        youtubeVerticalUrl: vertical,
      );
      expect(
        (
          hasStartableChat(settings),
          resolveChatSessionPhase(
            requested: true,
            settings: settings,
            statuses: const {'youtubeHorizontal': (ServiceStatus.idle, null)},
          )
        ),
        (false, ChatSessionPhase.idle),
        reason: vertical,
      );
    }
  });

  test('tracks horizontal and vertical YouTube streams independently', () {
    const settings = SettingsModel(
      youtubeDualStreamEnabled: true,
      youtubeHorizontalUrl: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
      youtubeVerticalUrl: 'https://youtu.be/aqz-KE-bpKQ',
    );

    expect(
      resolveChatSessionPhase(
        requested: true,
        settings: settings,
        statuses: const {
          'youtubeHorizontal': (ServiceStatus.connected, null),
          'youtubeVertical': (ServiceStatus.error, 'not found'),
        },
      ),
      ChatSessionPhase.partiallyConnected,
    );
  });
}
