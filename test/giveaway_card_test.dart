import 'dart:async';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/giveaway_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/coordinator_fakes.dart';
import 'chat_giveaway_test.dart' show message;

void main() {
  testWidgets('Redraw stays enabled after blocking a winner until none remain',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final twitch = FakeChannelChatClient();
    final app = AppController(
      chatCoordinator: ChatCoordinator(
        youtube: FakeYouTubeChatClient(),
        youtubeHorizontal: FakeYouTubeChatClient(),
        youtubeVertical: FakeYouTubeChatClient(),
        kick: FakeChannelChatClient(),
        twitch: twitch,
      ),
      audioCoordinator: AudioCoordinator(
          tts: FakeTtsClient(), captions: FakeCaptionsClient()),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
      overlayCoordinator: OverlayCoordinator(overlay: FakeOverlayClient()),
    );
    const settings = SettingsModel(overlayEnabled: false);
    app.applySettings(settings, connectChats: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWithValue(app),
          settingsProvider.overrideWith((ref) => SettingsNotifier()),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(body: SingleChildScrollView(child: GiveawayCard())),
        ),
      ),
    );
    app.startGiveaway(keyword: 'go', membersOnly: false);
    twitch.messageController.add(message('Ana', 'go'));
    twitch.messageController.add(message('Beto', 'go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final first = app.drawGiveaway()!;
    await tester.pump();
    app.applySettings(
      settings.copyWith(blockedUsers: [first.authorId]),
      connectChats: true,
    );
    await tester.pump();

    final redraw = find.byKey(const Key('giveaway-redraw'));
    try {
      expect(tester.widget<ElevatedButton>(redraw).onPressed, isNotNull);
      await tester.ensureVisible(redraw);
      await tester.tap(redraw);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('giveaway-winner'))).data,
          first.name == 'Ana' ? 'Beto' : 'Ana');
      expect(tester.widget<ElevatedButton>(redraw).onPressed, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(app.dispose());
      await tester.pump();
    }
  });
}
