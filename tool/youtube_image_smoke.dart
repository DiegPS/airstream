import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/ui/widgets/chat_network_image.dart';
import 'package:dart_youtube_chat/dart_youtube_chat.dart' as youtube;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final handle = arguments.isEmpty ? '@PastorJerryEze' : arguments.first;
  final chat = youtube.LiveChat(id: youtube.YoutubeId(handle: handle));
  final avatarUrls = <String>{};
  late StreamSubscription<youtube.ChatItem> subscription;
  final enoughAvatars = Completer<void>();
  subscription = chat.messages.listen((message) {
    final url = message.author.thumbnail?.url ?? '';
    if (url.isNotEmpty) avatarUrls.add(url);
    if (avatarUrls.length >= 8 && !enoughAvatars.isCompleted) {
      enoughAvatars.complete();
    }
  });

  try {
    await chat.start();
    await enoughAvatars.future.timeout(const Duration(seconds: 45));
    await subscription.cancel();
    chat.stop();
    final urlsToVerify = avatarUrls.take(8).toList(growable: false);
    final manager = ChatImageCache.instance as ImageCacheManager;
    var validFiles = 0;
    for (final url in urlsToVerify) {
      final response = await manager
          .getImageFile(
            url,
            key: ChatImageCache.key(
              kind: 'smoke-avatar',
              identity: url,
              url: url,
            ),
            maxWidth: 88,
            maxHeight: 88,
          )
          .where((event) => event is FileInfo)
          .cast<FileInfo>()
          .first
          .timeout(const Duration(seconds: 20));
      if (await response.file.exists() && await response.file.length() > 0) {
        validFiles++;
      }
    }
    stdout.writeln(jsonEncode({
      'avatarsRequested': 8,
      'validCachedFiles': validFiles,
      'allValid': validFiles == 8,
    }));
    exitCode = validFiles == 8 ? 0 : 1;
  } catch (error) {
    stderr.writeln('YouTube image smoke test failed: ${error.runtimeType}');
    exitCode = 1;
  } finally {
    chat.stop();
    await subscription.cancel();
    await ChatImageCache.instance.dispose();
    Timer(const Duration(milliseconds: 100), () => exit(exitCode));
  }
}
