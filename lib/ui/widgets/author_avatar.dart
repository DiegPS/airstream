import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AuthorAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final String? color; // hex #RRGGBB

  const AuthorAvatar({super.key, required this.name, this.url, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = _nameToColor(name, color);

    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initials(bg),
        ),
      );
    }
    return _initials(bg);
  }

  Widget _initials(Color bg) => CircleAvatar(
        radius: 12,
        backgroundColor: bg,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  static Color _nameToColor(String name, String? hex) {
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      try {
        return Color(int.parse('FF${hex.substring(1)}', radix: 16));
      } catch (_) {}
    }
    // Deterministic hue from username hash
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = hash.abs() % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.45).toColor();
  }
}
