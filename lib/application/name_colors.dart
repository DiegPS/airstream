import 'dart:convert';
import 'dart:math' as math;

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/name_color_mode.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter/painting.dart';

const nameColorPalette = [
  Color(0xFFFF8A80),
  Color(0xFFFFB074),
  Color(0xFFFFD166),
  Color(0xFFE6EE9C),
  Color(0xFFB7FF8D),
  Color(0xFF80E58D),
  Color(0xFF65DFC0),
  Color(0xFF7DE7EF),
  Color(0xFF7AD1FF),
  Color(0xFF96B7FF),
  Color(0xFFAF84FF),
  Color(0xFFCDA4FF),
  Color(0xFFFF9FEE),
  Color(0xFFFF8ABB),
  Color(0xFFF9B5AD),
  Color(0xFFD6C49E),
];

final _rgbPattern = RegExp(r'^#?([0-9a-fA-F]{6})$');

Color? _rgb(String? value) {
  if (value == null) return null;
  final match = _rgbPattern.firstMatch(value);
  return match == null
      ? null
      : Color(0xFF000000 | int.parse(match[1]!, radix: 16));
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
const _membershipGreen = Color(0xFF0F9D58);

Color chatBubbleBackground(ChatMessage message, SettingsModel settings) {
  if (!settings.showBubble) return const Color(0x00000000);
  final superChat = message.superChat;
  final base = message.isMembershipEvent
      ? _membershipGreen
      : superChat != null
          ? Color.alphaBlend(
              (_rgb(superChat.color) ?? _white).withValues(alpha: 0.3),
              const Color(0xFF111111),
            )
          : switch (message.platform) {
              Platform.youtube => const Color(0xFF111111),
              Platform.twitch => const Color(0xFF17111F),
              Platform.kick => const Color(0xFF10160D),
            };
  return base.withAlpha((255 * settings.messageOpacity).round().clamp(0, 255));
}

Color _pageBackground(ChatMessage message, SettingsModel settings) {
  // A transparent OBS source can be over any scene, and a chroma background
  // is keyed out by OBS, so it is never what viewers see behind the name.
  // Estimate both over black.
  const backdrop = _black;
  if (message.isMembershipEvent) return _membershipGreen;
  if (!settings.overlayShowBubble) return backdrop;
  final bubble = switch (message.platform) {
    Platform.twitch when settings.overlayTwitchBubbleAccent =>
      const Color(0xFF6119D2),
    Platform.kick when settings.overlayKickBubbleAccent =>
      const Color(0xFF1E5A0A),
    _ => _black,
  };
  return Color.alphaBlend(
      bubble.withValues(alpha: settings.overlayMessageOpacity.clamp(0, 1)),
      backdrop);
}

Color _generatedColor(ChatMessage message) {
  final author = message.author;
  final identity =
      author.channelId.isEmpty ? author.name.toLowerCase() : author.channelId;
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode('${message.platform.name}:$identity')) {
    final value = hash ^ byte;
    // Split the FNV-1a prime so the multiplication stays exact on the web.
    hash = (value * 0x193 + (value & 0xff) * 0x1000000) % 0x100000000;
  }
  return nameColorPalette[(hash ^ (hash >>> 16)) & 15];
}

Color resolveNameColor(ChatMessage message, SettingsModel settings) {
  if (settings.nameRoleColors) {
    if (message.isOwner) return const Color(0xFFFFD700);
    if (message.isModerator) return const Color(0xFF7EA4FF);
    if (message.isVip) return const Color(0xFFFF69D4);
  }

  final supplied = _rgb(message.author.color);
  final color = switch (settings.nameColorMode) {
    NameColorMode.platform => supplied ??
        switch (message.platform) {
          Platform.twitch => const Color(0xFFAF84FF),
          Platform.kick => const Color(0xFFB7FF8D),
          Platform.youtube => _white,
        },
    NameColorMode.platformThenGenerated => supplied ?? _generatedColor(message),
    NameColorMode.generated => _generatedColor(message),
    NameColorMode.single => _rgb(settings.nameColorSingle) ?? _white,
    NameColorMode.brand => switch (message.platform) {
        Platform.youtube => const Color(0xFFFF4E45),
        Platform.twitch => const Color(0xFFA970FF),
        Platform.kick => const Color(0xFF53FC18),
      },
  };
  if (!settings.nameReadability) return color;

  // Estimate the app canvas over black, using the base bubble (before the
  // transient mention highlight). Use both backgrounds for one shared color.
  final appBackdrop = Color.alphaBlend(
      const Color(0xFF0D0D0D).withValues(alpha: settings.bgOpacity.clamp(0, 1)),
      _black);
  final appLuminance =
      Color.alphaBlend(chatBubbleBackground(message, settings), appBackdrop)
          .computeLuminance();
  final pageLuminance = _pageBackground(message, settings).computeLuminance();
  double contrast(Color candidate) {
    final luminance = candidate.computeLuminance();
    double ratio(double background) =>
        (math.max(luminance, background) + 0.05) /
        (math.min(luminance, background) + 0.05);
    return math.min(ratio(appLuminance), ratio(pageLuminance));
  }

  var best = color;
  var bestContrast = contrast(color);
  if (bestContrast >= 3) return color;
  final hsl = HSLColor.fromColor(color);
  for (var step = 1; step <= 255; step++) {
    final lightness = hsl.lightness + (1 - hsl.lightness) * step / 255;
    final candidate = hsl.withLightness(lightness).toColor();
    final ratio = contrast(candidate);
    if (ratio >= 3) return candidate;
    if (ratio > bestContrast) {
      best = candidate;
      bestContrast = ratio;
    }
  }
  // Some opposing backdrops have no common 3:1 solution on this HSL ramp.
  return best;
}

String nameColorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
