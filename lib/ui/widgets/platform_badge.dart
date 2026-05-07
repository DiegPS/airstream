import 'package:flutter/material.dart';
import 'package:airchat_flutter/models/chat_message.dart';

class PlatformBadge extends StatelessWidget {
  final Platform platform;

  const PlatformBadge({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    final (label, color, textColor) = switch (platform) {
      Platform.youtube => ('YT', const Color(0xFFFF0000), Colors.white),
      Platform.twitch => ('TW', const Color(0xFF9147FF), Colors.white),
      Platform.kick => ('KK', const Color(0xFF53FC18), Colors.black),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
