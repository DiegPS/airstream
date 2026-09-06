import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:flutter/material.dart';

class YoutubeLiveStats extends StatelessWidget {
  const YoutubeLiveStats({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final YoutubeLiveMetadataSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalViewerCount;
    if (total == null) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    if (compact) {
      return Tooltip(
        message: _tooltip(l, context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_rounded,
              key: Key('youtube-viewers-icon'),
              size: 11,
              color: Color(0xFFAAAAAA),
            ),
            const SizedBox(width: 3),
            Text(
              _compactNumber(context, total),
              key: const Key('youtube-total-viewers'),
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final streams = summary.streams.toList(growable: false);
    return Container(
      key: const Key('youtube-live-stats'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_rounded,
                size: 14,
                color: Color(0xFFFF5A5F),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.youtubeLiveAudience,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l.youtubeTotalViewers(_formatNumber(context, total)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < streams.length; index++) ...[
            if (index > 0) const SizedBox(height: 7),
            _streamRow(context, l, streams[index]),
          ],
        ],
      ),
    );
  }

  Widget _streamRow(
    BuildContext context,
    AppLocalizations l,
    YoutubeLiveMetadata metadata,
  ) {
    final label = switch (metadata.streamOrientation) {
      YoutubeStreamOrientation.horizontal => l.youtubeHorizontal,
      YoutubeStreamOrientation.vertical => l.youtubeVertical,
      null => 'YouTube',
    };
    final count = metadata.viewerCount;
    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 66),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
        Expanded(
          child: Text(
            metadata.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count == null ? '—' : _formatNumber(context, count),
          key: Key(
              'youtube-viewers-${metadata.streamOrientation?.name ?? 'primary'}'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _tooltip(AppLocalizations l, BuildContext context) {
    final lines = summary.streams.map((metadata) {
      final label = switch (metadata.streamOrientation) {
        YoutubeStreamOrientation.horizontal => l.youtubeHorizontal,
        YoutubeStreamOrientation.vertical => l.youtubeVertical,
        null => 'YouTube',
      };
      final count = metadata.viewerCount;
      final audience = count == null
          ? l.youtubeAudienceUnavailable
          : l.youtubeViewers(_formatNumber(context, count));
      final title = metadata.title.trim();
      return title.isEmpty ? '$label: $audience' : '$label: $audience\n$title';
    }).toList(growable: true);
    final total = summary.totalViewerCount;
    if (lines.length > 1 && total != null) {
      lines.add(l.youtubeTotalViewers(_formatNumber(context, total)));
    }
    return lines.join('\n');
  }

  static String _formatNumber(BuildContext context, int value) {
    final separator =
        Localizations.localeOf(context).languageCode == 'es' ? '.' : ',';
    final digits = value.toString();
    final result = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        result.write(separator);
      }
      result.write(digits[index]);
    }
    return result.toString();
  }

  static String _compactNumber(BuildContext context, int value) {
    if (value < 1000) return value.toString();
    final divisor = value >= 1000000 ? 1000000 : 1000;
    final suffix = value >= 1000000 ? 'M' : 'K';
    final scaled = value / divisor;
    final fraction = scaled >= 100 || scaled == scaled.roundToDouble() ? 0 : 1;
    var text = scaled.toStringAsFixed(fraction);
    if (Localizations.localeOf(context).languageCode == 'es') {
      text = text.replaceFirst('.', ',');
    }
    return '$text$suffix';
  }
}
