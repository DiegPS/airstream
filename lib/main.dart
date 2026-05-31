import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:airchat_flutter/ui/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await Window
        .initialize(); // flutter_acrylic — debe ir después de windowManager
    await Window.setEffect(
      effect: WindowEffect.transparent,
      color: const Color(0x00000000),
      dark: true,
    );
    await windowManager.setResizable(true);
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
  }

  runApp(const ProviderScope(child: AirChatApp()));
}

class AirChatApp extends StatelessWidget {
  const AirChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF53FC18),
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
