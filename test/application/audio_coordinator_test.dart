import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';

void main() {
  late FakeTtsClient tts;
  late FakeCaptionsClient captions;
  late AudioCoordinator coordinator;

  setUp(() {
    tts = FakeTtsClient();
    captions = FakeCaptionsClient();
    coordinator = AudioCoordinator(tts: tts, captions: captions);
  });

  tearDown(() => coordinator.dispose());

  test('applies settings and never speaks a duplicate message', () async {
    const settings = SettingsModel(
      ttsEnabled: true,
      twitchEnabled: true,
      twitchChannel: 'channel',
    );
    coordinator.applySettings(settings, connectChats: true);
    await settleCoordinatorTasks();
    expect(tts.updateCount, 1);
    expect(captions.updateCount, 1);

    final message = ChatMessage(
      platform: Platform.twitch,
      id: 'message-1',
      author: const ChatAuthor(name: 'Streamer', channelId: 'streamer'),
      items: const [MessageItem.text('hola')],
      timestamp: DateTime.now().toUtc(),
    );
    coordinator.handleChatMessage(message);
    coordinator.handleChatMessage(message);
    expect(tts.spoken, ['Streamer says: hola']);

    coordinator.applySettings(
      settings.copyWith(ttsSpeed: 1.2),
      connectChats: true,
    );
    await settleCoordinatorTasks();
    expect(tts.updateCount, 2);
  });

  test('forwards playback errors, captions, and voice commands', () async {
    coordinator.applySettings(
      const SettingsModel(
        liveCaptionsOverlayEnabled: true,
        voiceCommandsEnabled: true,
      ),
      connectChats: false,
    );
    final notice = coordinator.notices.first;
    final caption = coordinator.finalizedCaptions.first;
    final command = coordinator.voiceCommands.first;

    tts.errorController.add(StateError('speaker unavailable'));
    captions.stateController.add(
      const LiveCaptionsState(
        caption: 'airstream inicia grabación',
        captionFinal: true,
      ),
    );

    expect((await notice).code, AppNoticeCode.ttsPlaybackFailed);
    expect(await caption, 'airstream inicia grabación');
    expect((await command).argument, isEmpty);
  });

  test('disposes TTS and captions only once', () async {
    await coordinator.dispose();
    await coordinator.dispose();
    expect(tts.disposed, isTrue);
    expect(captions.disposed, isTrue);
  });

  test('a moderated message is never read aloud', () async {
    coordinator.applySettings(
      const SettingsModel(
        ttsEnabled: true,
        twitchEnabled: true,
        twitchChannel: 'channel',
      ),
      connectChats: true,
    );
    await settleCoordinatorTasks();
    ChatMessage message(String id, String author) => ChatMessage(
          platform: Platform.twitch,
          id: id,
          author: ChatAuthor(name: author, channelId: author),
          items: const [MessageItem.text('hola')],
          timestamp: DateTime.now().toUtc(),
        );
    coordinator.handleChatMessage(message('1', 'troll'));
    coordinator.handleChatMessage(message('2', 'viewer'));
    coordinator.handleChatMessage(message('3', 'troll'));

    coordinator.handleModeration(const ChatModerationEvent.message(
      platform: Platform.twitch,
      messageId: '1',
    ));
    expect(tts.spoken, ['viewer says: hola', 'troll says: hola']);

    coordinator.handleModeration(const ChatModerationEvent.author(
      platform: Platform.twitch,
      authorChannelId: 'troll',
    ));
    expect(tts.spoken, ['viewer says: hola']);

    await coordinator.silenceTts();
    expect(tts.silenceCount, 1);
  });
}
