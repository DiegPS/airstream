import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';

void main() {
  test('forwards moderation and provider events to the overlay facade',
      () async {
    final youtube = FakeYouTubeChatClient();
    final horizontal = FakeYouTubeChatClient();
    final vertical = FakeYouTubeChatClient();
    final kick = FakeChannelChatClient();
    final twitch = FakeChannelChatClient();
    final overlay = FakeOverlayClient();
    final controller = AppController(
      chatCoordinator: ChatCoordinator(
        youtube: youtube,
        youtubeHorizontal: horizontal,
        youtubeVertical: vertical,
        kick: kick,
        twitch: twitch,
      ),
      audioCoordinator: AudioCoordinator(
        tts: FakeTtsClient(),
        captions: FakeCaptionsClient(),
      ),
      overlayCoordinator: OverlayCoordinator(overlay: overlay),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
    );
    addTearDown(controller.dispose);

    twitch.moderationController.add(const ChatModerationEvent.message(
      platform: Platform.twitch,
      messageId: 'deleted',
    ));
    kick.eventController.add(ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.poll,
      id: 'poll',
      timestamp: DateTime.utc(2026, 9, 7),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(overlay.moderationCount, 1);
    expect(overlay.providerEventCount, 1);
  });
}
