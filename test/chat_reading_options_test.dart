import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:airstream/settings/tts_message_policy.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  Platform platform = Platform.twitch,
  TtsRole? role,
  bool membershipEvent = false,
  String? amount,
  List<MessageItem> items = const [MessageItem.text('hello')],
}) =>
    ChatMessage(
      platform: platform,
      id: 'message',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: items,
      timestamp: DateTime.utc(2026),
      isMembership: role == TtsRole.member,
      isMembershipEvent: membershipEvent,
      isModerator: role == TtsRole.moderator,
      isVip: role == TtsRole.vip,
      isOwner: role == TtsRole.owner,
      superChat: amount == null ? null : SuperChat(amount: amount, color: ''),
    );

void main() {
  test('everyone passes, or any of the selected roles must match', () {
    expect(ttsAllows(_message(), const SettingsModel()), isTrue);
    expect(ttsAllows(_message(), const SettingsModel(ttsRoles: {})), isFalse);
    for (final role
        in TtsRole.values.where((role) => role != TtsRole.everyone)) {
      final settings = SettingsModel(ttsRoles: {role});
      expect(ttsAllows(_message(role: role), settings), isTrue,
          reason: role.name);
      expect(ttsAllows(_message(), settings), isFalse, reason: role.name);
    }
    const memberOrVip = SettingsModel(ttsRoles: {TtsRole.member, TtsRole.vip});
    expect(ttsAllows(_message(role: TtsRole.vip), memberOrVip), isTrue);
    expect(ttsAllows(_message(role: TtsRole.moderator), memberOrVip), isFalse);
  });

  test('legacy members only means the isMembership flag', () {
    final settings = SettingsModel.fromJson({'ttsMembersOnly': true});
    expect(settings.ttsRoles, {TtsRole.member});
    expect(ttsAllows(_message(role: TtsRole.member), settings), isTrue);
    expect(ttsAllows(_message(membershipEvent: true), settings), isFalse);
    expect(ttsAllows(_message(role: TtsRole.owner), settings), isFalse);
    expect(SettingsModel.fromJson({'ttsMembersOnly': false}).ttsRoles,
        {TtsRole.everyone});
    expect(
        SettingsModel.fromJson({'ttsMembersOnly': true, 'ttsRoles': []})
            .ttsRoles,
        isEmpty);
  });

  test(
      'platform selection applies across providers, with paid support override',
      () {
    const defaults = SettingsModel();
    for (final platform in Platform.values) {
      final one = defaults.copyWith(ttsPlatforms: {platform});
      for (final candidate in Platform.values) {
        expect(ttsAllows(_message(platform: candidate), defaults), isTrue);
        expect(ttsAllows(_message(platform: candidate), one),
            platform == candidate);
      }
    }
    const blocked = SettingsModel(ttsRoles: {}, ttsPlatforms: {});
    final support = _message(amount: '20 Bits');
    expect(ttsAllows(support, blocked), isFalse);
    final override = blocked.copyWith(ttsAlwaysReadSupport: true);
    expect(ttsAllows(support, override), isTrue);
    expect(ttsAllows(_message(amount: '  '), override), isFalse);
    expect(ttsAllows(_message(membershipEvent: true), override), isFalse);
    expect(ttsAllows(_message(), override), isFalse);
  });

  test('link modes detect URLs and say-link preserves surrounding punctuation',
      () {
    const text = 'See (HTTPS://example.com/a(b)), www.example.org. Then text.';
    final message =
        _message(amount: r'$5', items: const [MessageItem.text(text)]);
    for (final mode in TtsLinks.values) {
      expect(
        ttsAllows(
            message, SettingsModel(ttsLinks: mode, ttsAlwaysReadSupport: true)),
        mode != TtsLinks.skip,
      );
    }
    expect(replaceTtsLinks(text, 'link'), 'See (link), link. Then text.');
    expect(replaceTtsLinks(text, 'enlace'), 'See (enlace), enlace. Then text.');
    expect(replaceTtsLinks('example.com & ordinary text', 'link'),
        'example.com & ordinary text');
    expect(ttsAllows(_message(), const SettingsModel(ttsLinks: TtsLinks.skip)),
        isTrue);
  });

  test('emote-only includes segmented emotes and Unicode emoji sequences', () {
    final emotes = _message(items: const [
      MessageItem.emoji(EmojiItem(url: '', alt: 'Kappa', isCustom: true)),
      MessageItem.text('  👍🏽 🇲🇽 1️⃣ 👩‍💻\n❤️ '),
    ]);
    expect(isTtsEmoteOnly(emotes), isTrue);
    expect(ttsAllows(emotes, const SettingsModel()), isTrue);
    const skip = SettingsModel(ttsSkipEmoteOnly: true);
    expect(ttsAllows(emotes, skip), isFalse);
    for (final text in ['hello 🙂', '123', '#', '  ', '!️⃣a', '🙂!']) {
      expect(isTtsEmoteOnly(_message(items: [MessageItem.text(text)])), isFalse,
          reason: text);
    }
    expect(
        ttsAllows(_message(items: const [MessageItem.text('👋 hola')]), skip),
        isTrue);
  });

  test('settings and profiles persist, sanitize, and migrate reader options',
      () {
    const settings = SettingsModel(
      ttsRoles: {TtsRole.member, TtsRole.vip},
      ttsPlatforms: {},
      ttsLinks: TtsLinks.sayLink,
      ttsAlwaysReadSupport: true,
      ttsSkipEmoteOnly: true,
      highlightSounds: {HighlightKind.firstMessage: 'coin'},
    );
    final profile = SettingsProfiles.capture(settings);
    final applied = SettingsProfiles.apply(const SettingsModel(), profile);
    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    for (final result in [applied, restored]) {
      expect(result.ttsRoles, settings.ttsRoles);
      expect(result.ttsPlatforms, isEmpty);
      expect(result.ttsLinks, TtsLinks.sayLink);
      expect(result.ttsAlwaysReadSupport, isTrue);
      expect(result.ttsSkipEmoteOnly, isTrue);
      expect(result.highlightSounds[HighlightKind.firstMessage], 'coin');
    }
    final legacy = SettingsProfiles.apply(settings, {
      'ttsMembersOnly': true,
      'highlightSound': true,
    });
    expect(legacy.ttsRoles, {TtsRole.member});
    expect(legacy.ttsPlatforms, Platform.values.toSet());
    expect(legacy.ttsLinks, TtsLinks.read);
    expect(legacy.ttsAlwaysReadSupport, isFalse);
    expect(legacy.ttsSkipEmoteOnly, isFalse);
    expect(legacy.highlightSounds, HighlightSounds.legacyEnabled);
    final corrupt = SettingsModel.fromJson({
      'ttsRoles': ['VIP', 1],
      'ttsPlatforms': ['twitch', 'bad', 'twitch'],
      'ttsLinks': false,
      'ttsAlwaysReadSupport': 'true',
      'ttsSkipEmoteOnly': 1,
    });
    expect(corrupt.ttsRoles, {TtsRole.everyone});
    expect(corrupt.ttsPlatforms, {Platform.twitch});
    expect(corrupt.ttsLinks, TtsLinks.read);
    expect(corrupt.ttsAlwaysReadSupport, isFalse);
    expect(corrupt.ttsSkipEmoteOnly, isFalse);
  });
}
