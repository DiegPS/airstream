import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/window/window_state.dart';

/// Compact desktop controls styled like a native title bar cluster.
class WindowControlBar extends ConsumerWidget {
  const WindowControlBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(windowStateProvider);
    final notifier = ref.read(windowStateProvider.notifier);
    final l = AppLocalizations.of(context);

    final alwaysOnTopTooltip = l != null
        ? (state.alwaysOnTop
            ? l.alwaysOnTopActiveTooltip
            : l.alwaysOnTopInactiveTooltip)
        : (state.alwaysOnTop
            ? 'Desactivar Siempre visible (Ctrl+Shift+P)'
            : 'Siempre visible (Ctrl+Shift+P)');

    final clickThroughTooltip = l != null
        ? (state.clickThrough
            ? l.clickThroughActiveTooltip
            : l.clickThroughInactiveTooltip)
        : (state.clickThrough
            ? 'Click-Through activo. Desactivar (Ctrl+Shift+C)'
            : 'Activar Click-Through (Ctrl+Shift+C)');

    final antiCaptureTooltip = l != null
        ? (state.excludeFromCapture
            ? l.antiCaptureActiveTooltip
            : l.antiCaptureInactiveTooltip)
        : (state.excludeFromCapture
            ? 'Modo privacidad activo — ventana oculta de capturas/OBS'
            : 'Ocultar de capturas / screen share');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowToggleButton(
          tooltip: alwaysOnTopTooltip,
          icon: Icons.push_pin_outlined,
          active: state.alwaysOnTop,
          onTap: notifier.toggleAlwaysOnTop,
        ),
        _WindowToggleButton(
          tooltip: clickThroughTooltip,
          icon: state.clickThrough
              ? Icons.ads_click_outlined
              : Icons.mouse_outlined,
          active: state.clickThrough,
          activeColor: const Color(0xFFFFB15C),
          onTap: notifier.toggleClickThrough,
        ),
        _WindowToggleButton(
          tooltip: antiCaptureTooltip,
          icon: state.excludeFromCapture ? Icons.shield : Icons.shield_outlined,
          active: state.excludeFromCapture,
          activeColor: const Color(0xFFBB86FC),
          onTap: notifier.toggleExcludeFromCapture,
        ),
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFF333333),
          ),
          const SizedBox(width: 4),
          const _WindowManagerButtons(),
        ],
      ],
    );
  }
}

class _WindowManagerButtons extends StatefulWidget {
  const _WindowManagerButtons();

  @override
  State<_WindowManagerButtons> createState() => _WindowManagerButtonsState();
}

class _WindowManagerButtonsState extends State<_WindowManagerButtons>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => _setMaximized(true);

  @override
  void onWindowUnmaximize() => _setMaximized(false);

  Future<void> _syncWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    _setMaximized(isMaximized);
  }

  void _setMaximized(bool value) {
    if (!mounted || _isMaximized == value) return;
    setState(() => _isMaximized = value);
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _minimize() async {
    await windowManager.minimize();
  }

  Future<void> _close() async {
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final minimizeLabel = l?.minimize ?? 'Minimizar';
    final maximizeLabel = l?.maximize ?? 'Maximizar';
    final restoreLabel = l?.restore ?? 'Restaurar';
    final closeLabel = l?.close ?? 'Cerrar';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowCommandButton(
          tooltip: minimizeLabel,
          icon: Icons.remove,
          onTap: _minimize,
        ),
        _WindowCommandButton(
          tooltip: _isMaximized ? restoreLabel : maximizeLabel,
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onTap: _toggleMaximize,
        ),
        _WindowCommandButton(
          tooltip: closeLabel,
          icon: Icons.close,
          onTap: _close,
          hoverColor: const Color(0xFFC42B1C),
          hoverForeground: Colors.white,
        ),
      ],
    );
  }
}

class _WindowToggleButton extends StatelessWidget {
  const _WindowToggleButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = const Color(0xFF5B9CFF),
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        active ? activeColor.withValues(alpha: 0.18) : Colors.transparent;
    final foregroundColor = active ? activeColor : const Color(0xFFB8B8B8);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, color: foregroundColor, size: 15),
          ),
        ),
      ),
    );
  }
}

class _WindowCommandButton extends StatefulWidget {
  const _WindowCommandButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.hoverColor = const Color(0xFF2A2A2A),
    this.hoverForeground = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onTap;
  final Color hoverColor;
  final Color hoverForeground;

  @override
  State<_WindowCommandButton> createState() => _WindowCommandButtonState();
}

class _WindowCommandButtonState extends State<_WindowCommandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              width: 32,
              height: 28,
              child: Icon(
                widget.icon,
                size: 14,
                color: _isHovered
                    ? widget.hoverForeground
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
