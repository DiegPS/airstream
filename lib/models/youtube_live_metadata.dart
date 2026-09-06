import 'package:airstream/models/chat_message.dart';

/// User-facing state derived from YouTube's incremental live metadata updates.
class YoutubeLiveMetadata {
  const YoutubeLiveMetadata({
    required this.liveId,
    this.streamOrientation,
    this.viewerCount,
    this.viewerCountText = '',
    this.isLive,
    this.title = '',
    this.dateText = '',
    this.description = '',
    this.updatedAt,
  });

  final String liveId;
  final YoutubeStreamOrientation? streamOrientation;
  final int? viewerCount;
  final String viewerCountText;
  final bool? isLive;
  final String title;
  final String dateText;
  final String description;
  final DateTime? updatedAt;

  YoutubeLiveMetadata merge({
    int? viewerCount,
    String? viewerCountText,
    bool? isLive,
    String? title,
    String? dateText,
    String? description,
    DateTime? updatedAt,
  }) {
    return YoutubeLiveMetadata(
      liveId: liveId,
      streamOrientation: streamOrientation,
      viewerCount: viewerCount ?? this.viewerCount,
      viewerCountText: _nonEmptyOrPrevious(
        viewerCountText,
        this.viewerCountText,
      ),
      isLive: isLive ?? this.isLive,
      title: _nonEmptyOrPrevious(title, this.title),
      dateText: _nonEmptyOrPrevious(dateText, this.dateText),
      description: _nonEmptyOrPrevious(description, this.description),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _nonEmptyOrPrevious(String? next, String previous) {
    final normalized = next?.trim() ?? '';
    return normalized.isEmpty ? previous : normalized;
  }
}

class YoutubeLiveMetadataSummary {
  const YoutubeLiveMetadataSummary({
    this.primary,
    this.horizontal,
    this.vertical,
  });

  final YoutubeLiveMetadata? primary;
  final YoutubeLiveMetadata? horizontal;
  final YoutubeLiveMetadata? vertical;

  Iterable<YoutubeLiveMetadata> get streams sync* {
    if (primary != null) yield primary!;
    if (horizontal != null) yield horizontal!;
    if (vertical != null) yield vertical!;
  }

  int? get totalViewerCount {
    final counts = streams
        .map((metadata) => metadata.viewerCount)
        .whereType<int>()
        .toList(growable: false);
    return counts.isEmpty ? null : counts.reduce((sum, count) => sum + count);
  }

  bool get hasData => streams.isNotEmpty;
}
