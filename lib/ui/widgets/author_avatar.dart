import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/ui/widgets/platform_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.name,
    required this.platform,
    this.url,
    this.color,
    this.showPlatformBadge = false,
  });

  final String name;
  final Platform platform;
  final String? url;
  final String? color;
  final bool showPlatformBadge;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _nameToColor(name, color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF), width: 2),
          ),
          child: ClipOval(
            child: url != null && url!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initials(backgroundColor),
                  )
                : _initials(backgroundColor),
          ),
        ),
        if (showPlatformBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: PlatformBadge(
              platform: platform,
              mode: PlatformBadgeMode.overlay,
            ),
          ),
      ],
    );
  }

  Widget _initials(Color backgroundColor) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  static Color _nameToColor(String name, String? hex) {
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      try {
        return Color(int.parse('FF${hex.substring(1)}', radix: 16));
      } catch (_) {}
    }

    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final hue = hash.abs() % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.4).toColor();
  }
}
