import 'package:airchat_flutter/models/chat_message.dart';
import 'package:flutter/material.dart';

enum PlatformBadgeMode { overlay, inline }

class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.platform,
    this.mode = PlatformBadgeMode.inline,
  });

  final Platform platform;
  final PlatformBadgeMode mode;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(platform);
    final size = switch (mode) {
      PlatformBadgeMode.overlay => 14.0,
      PlatformBadgeMode.inline => 12.0,
    };

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(mode == PlatformBadgeMode.overlay ? 4 : 3),
          border: mode == PlatformBadgeMode.overlay
              ? Border.all(color: const Color(0xCC0F0F0F), width: 1)
              : null,
          boxShadow: mode == PlatformBadgeMode.overlay
              ? const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            spec.icon,
            size: mode == PlatformBadgeMode.overlay ? 9 : 8,
            color: spec.foreground,
          ),
        ),
      ),
    );
  }

  static _PlatformSpec _specFor(Platform platform) {
    return switch (platform) {
      Platform.youtube => const _PlatformSpec(
          background: Color(0xFFFF0000),
          foreground: Colors.white,
          icon: Icons.play_arrow_rounded,
        ),
      Platform.twitch => const _PlatformSpec(
          background: Color(0xFF9146FF),
          foreground: Colors.white,
          icon: Icons.chat_bubble_rounded,
        ),
      Platform.kick => const _PlatformSpec(
          background: Color(0xFF53FC18),
          foreground: Color(0xFF101010),
          icon: Icons.bolt_rounded,
        ),
    };
  }
}

class _PlatformSpec {
  const _PlatformSpec({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
