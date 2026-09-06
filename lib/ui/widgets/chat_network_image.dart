import 'dart:convert';

import 'package:airstream/models/chat_media.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

abstract final class ChatImageCache {
  static final BaseCacheManager instance = _ChatCacheManager(
    Config(
      'airstreamChatImagesV2',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 2000,
    ),
  );

  static String key({
    required String kind,
    required String identity,
    required String url,
  }) {
    final digest = sha1.convert(utf8.encode(normalizeChatImageUrl(url)));
    return '$kind:${identity.trim().toLowerCase()}:$digest';
  }
}

class _ChatCacheManager extends CacheManager with ImageCacheManager {
  _ChatCacheManager(super.config);
}

class ChatNetworkImage extends StatelessWidget {
  const ChatNetworkImage({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.cacheManager,
  });

  final String imageUrl;
  final String cacheKey;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeChatImageUrl(imageUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget ?? placeholder,
      );
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (width * ratio).ceil();
    final decodeHeight = (height * ratio).ceil();
    return CachedNetworkImage(
      cacheManager: cacheManager ?? ChatImageCache.instance,
      imageUrl: normalized,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      memCacheWidth: decodeWidth,
      memCacheHeight: decodeHeight,
      maxWidthDiskCache: decodeWidth,
      maxHeightDiskCache: decodeHeight,
      placeholder: placeholder == null ? null : (_, __) => placeholder!,
      errorWidget: (_, __, ___) =>
          errorWidget ?? placeholder ?? const SizedBox(),
    );
  }
}
