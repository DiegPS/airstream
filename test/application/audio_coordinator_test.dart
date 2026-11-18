import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
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

  test('with translated captions, commands are read from the translated text',
      () async {
    coordinator.applySettings(
      const SettingsModel(
        liveCaptionsEnabled: true,
        liveCaptionsOverlayEnabled: true,
        voiceCommandsEnabled: true,
        liveCaptionsSourceLanguage: 'es',
        liveCaptionsTargetLanguage: 'en',
      ),
      connectChats: false,
    );
    final commands = <VoiceCommand>[];
    final subscription = coordinator.voiceCommands.listen(commands.add);
    addTearDown(subscription.cancel);

    // "airstream inicia grabación", as the recognizer translates it.
    captions.stateController.add(const LiveCaptionsState(
      caption: 'Airstream, start recording.',
      captionFinal: true,
    ));
    // "airstream cambia a escena juego": the scene name comes translated.
    captions.stateController.add(const LiveCaptionsState(
      caption: 'Airstream, switch to scene game.',
      captionFinal: true,
    ));
    await settleCoordinatorTasks();

    expect(commands.map((c) => c.type), [
      VoiceCommandType.startRecording,
      VoiceCommandType.switchScene,
    ]);
    expect(commands.last.argument, 'game');
  });

  test('speech without the wake word and chat text never become commands',
      () async {
    coordinator.applySettings(
      const SettingsModel(
        liveCaptionsEnabled: true,
        voiceCommandsEnabled: true,
      ),
      connectChats: false,
    );
    final commands = <VoiceCommand>[];
    final subscription = coordinator.voiceCommands.listen(commands.add);
    addTearDown(subscription.cancel);

    captions.stateController.add(const LiveCaptionsState(
      caption: 'inicia grabación',
      captionFinal: true,
    ));
    captions.stateController.add(const LiveCaptionsState(
      caption: 'airstream inicia grabación',
      captionFinal: false,
    ));
    coordinator.handleChatMessage(ChatMessage(
      platform: Platform.twitch,
      id: 'not-a-microphone',
      author: const ChatAuthor(name: 'viewer', channelId: 'viewer'),
      items: const [MessageItem.text('airstream inicia grabación')],
      timestamp: DateTime.now(),
    ));
    await settleCoordinatorTasks();

    expect(commands, isEmpty);
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

  test('appearance changes do not reconfigure TTS or captions', () async {
    const settings = SettingsModel(ttsEnabled: true);
    coordinator.applySettings(settings, connectChats: false);
    await settleCoordinatorTasks();
    expect(tts.updateCount, 1);
    expect(captions.updateCount, 1);

    for (var i = 0; i < 10; i++) {
      coordinator.applySettings(
        settings.copyWith(fontSize: 14.0 + i),
        connectChats: false,
      );
    }
    await settleCoordinatorTasks();
    expect(tts.updateCount, 1);
    expect(captions.updateCount, 1);

    coordinator.applySettings(
      settings.copyWith(ttsVoice: 'F1'),
      connectChats: false,
    );
    coordinator.applySettings(
      settings.copyWith(ttsVoice: 'F1', liveCaptionsEnabled: true),
      connectChats: false,
    );
    await settleCoordinatorTasks();
    expect(tts.updateCount, 2);
    expect(captions.updateCount, 2);
  });

  test('a highlighted message plays the alert tone, at most every 3 s',
      () async {
    final alert = FakeAlertSound();
    var now = DateTime.utc(2026, 11, 15, 12);
    final audio = AudioCoordinator(
      tts: tts,
      captions: captions,
      alertSound: alert,
      clock: () => now,
    );
    addTearDown(audio.dispose);
    audio.applySettings(
      const SettingsModel(
        twitchChannel: 'xqc',
        highlightSounds: {
          HighlightKind.mention: 'coin',
          HighlightKind.word: '1234567890abcdef',
          HighlightKind.firstMessage: 'fanfare',
        },
        highlightWords: ['pregunta'],
      ),
      connectChats: false,
    );
    ChatMessage message(String id, String text, {bool first = false}) =>
        ChatMessage(
          isFirstInSession: first,
          platform: Platform.twitch,
          id: id,
          author: const ChatAuthor(name: 'viewer', channelId: 'viewer'),
          items: [MessageItem.text(text)],
          timestamp: DateTime.now().toUtc(),
        );

    audio.handleChatMessage(message('1', 'hola a todos'));
    expect(alert.plays, 0);
    audio.handleChatMessage(message('2', '@xqc una pregunta', first: true));
    expect(alert.plays, 1);
    now = now.add(const Duration(seconds: 1));
    audio.handleChatMessage(message('3', 'otra pregunta'));
    expect(alert.plays, 1, reason: 'too soon after the last tone');
    now = now.add(const Duration(seconds: 3));
    tts.busy = true;
    audio.handleChatMessage(message('4', 'pregunta mientras habla'));
    expect(alert.plays, 1, reason: 'the tone would cut the voice reader');
    tts.busy = false;
    audio.handleChatMessage(message('5', 'última pregunta'));
    expect(alert.sources, ['coin', '1234567890abcdef']);
    now = now.add(const Duration(seconds: 3));
    audio.handleChatMessage(message('first', 'hola', first: true));
    expect(alert.sources, ['coin', '1234567890abcdef', 'fanfare']);

    audio.applySettings(
      const SettingsModel(highlightWords: ['pregunta']),
      connectChats: false,
    );
    now = now.add(const Duration(seconds: 10));
    audio.handleChatMessage(message('6', 'pregunta sin sonido'));
    expect(alert.plays, 3, reason: 'the sound is off');
  });

  test('paid Kick events opt in and use the same speech checks', () {
    const settings = SettingsModel(
      ttsEnabled: true,
      ttsRoles: {},
      ttsPlatforms: {},
      ttsLinks: TtsLinks.sayLink,
      appLanguageCode: 'es',
      ttsIgnoredUsers: ['ignored-id'],
      ttsMaxCharacters: 40,
      ttsUserCooldownSeconds: 60,
    );
    ChatProviderEvent event(String id,
            {String name = 'Ana', String channel = 'ana'}) =>
        ChatProviderEvent(
          platform: Platform.kick,
          kind: ChatProviderEventKind.support,
          id: id,
          timestamp: DateTime.now(),
          authorName: name,
          authorChannelId: channel,
          count: 10,
          text:
              'hola https://example.com/long-path ${List.filled(60, 'x').join()}',
        );
    coordinator.applySettings(settings, connectChats: false);
    coordinator.handleProviderEvent(event('off'));
    expect(tts.spoken, isEmpty);

    coordinator.applySettings(
      settings.copyWith(ttsAlwaysReadSupport: true),
      connectChats: false,
    );
    coordinator.handleProviderEvent(event('ignored', channel: 'ignored-id'));
    coordinator.handleProviderEvent(event('yes'));
    coordinator.handleProviderEvent(event('cooldown'));
    expect(
        tts.spoken, ['Ana dice: hola enlace ${List.filled(28, 'x').join()}…']);
  });

  test(
      'the voice reader skips ignored users, waits per viewer and cuts '
      'long messages', () async {
    var now = DateTime.utc(2026, 11, 15, 12);
    final audio = AudioCoordinator(
      tts: tts,
      captions: captions,
      alertSound: FakeAlertSound(),
      clock: () => now,
    );
    addTearDown(audio.dispose);
    audio.applySettings(
      const SettingsModel(
        ttsEnabled: true,
        ttsSeparatorText: 'dice',
        ttsIgnoredUsers: ['nightbot'],
        ttsUserCooldownSeconds: 10,
        ttsMaxCharacters: 40,
      ),
      connectChats: false,
    );
    var next = 0;
    ChatMessage message(String author, String text) => ChatMessage(
          platform: Platform.twitch,
          id: 'm${next++}',
          author: ChatAuthor(name: author, channelId: author.toLowerCase()),
          items: [MessageItem.text(text)],
          timestamp: DateTime.now().toUtc(),
        );

    audio.handleChatMessage(message('Nightbot', 'sigue al canal'));
    audio.handleChatMessage(message('Ana', 'hola'));
    now = now.add(const Duration(seconds: 3));
    audio.handleChatMessage(message('Ana', 'otra vez'));
    audio.handleChatMessage(message('Beto', List.filled(60, 'b').join()));
    now = now.add(const Duration(seconds: 10));
    audio.handleChatMessage(message('Ana', 'ya puedo'));

    expect(tts.spoken, [
      'Ana dice: hola',
      'Beto dice: ${List.filled(40, 'b').join()}…',
      'Ana dice: ya puedo',
    ]);
  });
}
