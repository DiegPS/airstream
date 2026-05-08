import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ],
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
