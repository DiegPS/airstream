import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:airchat_flutter/window/window_state.dart';

/// Quick-access icon buttons for the AppBar that toggle native window behaviour.
///
/// Designed to stay visible even when click-through is active — the user MUST
/// be able to reach this bar to turn click-through back off.
class WindowControlBar extends ConsumerWidget {
  const WindowControlBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(windowStateProvider);
    final notifier = ref.read(windowStateProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Frameless ────────────────────────────────────────────────────────
        _WindowToggleButton(
          tooltip: state.frameless
              ? 'Desactivar Frameless'
              : 'Frameless (sin chrome, sin sombra)',
          icon:   state.frameless
              ? Icons.crop_free
              : Icons.web_asset,
          active: state.frameless,
          onTap:  notifier.toggleFrameless,
        ),

        // ── Always-on-top ────────────────────────────────────────────────────
        _WindowToggleButton(
          tooltip: state.alwaysOnTop
              ? 'Desactivar Always on Top'
              : 'Always on Top',
          icon:    Icons.push_pin,
          active:  state.alwaysOnTop,
          onTap:   notifier.toggleAlwaysOnTop,
        ),

        // ── Click-through ────────────────────────────────────────────────────
        _WindowToggleButton(
          tooltip: state.clickThrough
              ? '⚠ Click-Through ACTIVO — toca para desactivar'
              : 'Activar Click-Through',
          icon:   state.clickThrough ? Icons.mouse_outlined : Icons.mouse,
          active: state.clickThrough,
          // Orange when active so the user notices the window is "ghosted"
          activeColor: const Color(0xFFFF6B35),
          onTap: notifier.toggleClickThrough,
        ),
        // ── Frameless (window_manager) ─────────────────────────────────
        // Botón de A/B test: usa window_manager.setAsFrameless() + setHasShadow(false)
        // en lugar de nuestro GWL_STYLE/DWMNCRP_DISABLED.
        // Morado para distinguirlo del nuestro (verde).
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
          _WmFramelessButton(),

      ],
    );
  }
}

// ── A/B Test: window_manager frameless ────────────────────────────────────────
// Botón morado — usa window_manager.setAsFrameless() + setHasShadow(false).
// Comparar visualmente con nuestro botón verde (GWL_STYLE + DWMNCRP_DISABLED).

class _WmFramelessButton extends StatefulWidget {
  @override
  State<_WmFramelessButton> createState() => _WmFramelessButtonState();
}

class _WmFramelessButtonState extends State<_WmFramelessButton> {
  bool _active = false;

  Future<void> _toggle() async {
    final next = !_active;
    if (next) {
      // setResizable(true) must happen before setAsFrameless() so the
      // plugin's FRAMECHANGED refresh sees WS_THICKFRAME already applied.
      await windowManager.setResizable(true);
      // window_manager frameless: usa WM_NCCALCSIZE → 0 + setHasShadow(false)
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
    } else {
      // No hay "undo" directo de setAsFrameless en window_manager,
      // así que restauramos el estilo estándar manualmente.
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setResizable(true);
      await windowManager.setHasShadow(true);
    }
    setState(() => _active = next);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _active
          ? '[WM] Desactivar Frameless (window_manager)'
          : '[WM] Frameless — window_manager (WM_NCCALCSIZE)',
      child: IconButton(
        icon: Icon(
          _active ? Icons.picture_in_picture : Icons.picture_in_picture_alt,
          // Morado para distinguir del nuestro (verde)
          color: _active ? const Color(0xFFB39DDB) : Colors.white38,
          size: 20,
        ),
        onPressed: _toggle,
      ),
    );
  }
}
// ── Private helper ────────────────────────────────────────────────────────────

class _WindowToggleButton extends StatelessWidget {
  const _WindowToggleButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = const Color(0xFF53FC18),
  });

  final String   tooltip;
  final IconData icon;
  final bool     active;
  final Color    activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          color: active ? activeColor : Colors.white38,
          size:  20,
        ),
        onPressed: onTap,
      ),
    );
  }
}
