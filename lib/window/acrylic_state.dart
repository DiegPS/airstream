import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Available effects ─────────────────────────────────────────────────────────

/// Effects that make sense for an overlay/chat app on Windows.
/// Ordered from "most transparent" to "least".
enum AcrylicEffectOption {
  disabled(label: 'Disabled',     effect: WindowEffect.disabled,     icon: Icons.block),
  transparent(label: 'Transparent', effect: WindowEffect.transparent,  icon: Icons.lens_blur),
  aero(label: 'Aero Blur',        effect: WindowEffect.aero,          icon: Icons.blur_on),
  acrylic(label: 'Acrylic',       effect: WindowEffect.acrylic,       icon: Icons.blur_circular),
  mica(label: 'Mica (Win 11)',     effect: WindowEffect.mica,          icon: Icons.water),
  tabbed(label: 'Tabbed (Win 11)', effect: WindowEffect.tabbed,        icon: Icons.tab);

  const AcrylicEffectOption({
    required this.label,
    required this.effect,
    required this.icon,
  });

  final String      label;
  final WindowEffect effect;
  final IconData    icon;
}

// ── State ─────────────────────────────────────────────────────────────────────

class AcrylicState {
  final AcrylicEffectOption effect;
  final Color               tintColor;
  final bool                dark;

  const AcrylicState({
    this.effect    = AcrylicEffectOption.transparent,
    this.tintColor = const Color(0x00000000), // fully transparent tint
    this.dark      = true,
  });

  AcrylicState copyWith({
    AcrylicEffectOption? effect,
    Color?              tintColor,
    bool?               dark,
  }) =>
      AcrylicState(
        effect:    effect    ?? this.effect,
        tintColor: tintColor ?? this.tintColor,
        dark:      dark      ?? this.dark,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AcrylicNotifier extends StateNotifier<AcrylicState> {
  AcrylicNotifier() : super(const AcrylicState());

  Future<void> setEffect(AcrylicEffectOption opt) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    state = state.copyWith(effect: opt);
    await Window.setEffect(
      effect:    opt.effect,
      color:     state.tintColor,
      dark:      state.dark,
    );
  }

  Future<void> setTintColor(Color color) async {
    state = state.copyWith(tintColor: color);
    // Re-apply current effect with the new color
    await setEffect(state.effect);
  }

  Future<void> setDark(bool dark) async {
    state = state.copyWith(dark: dark);
    await setEffect(state.effect);
  }

  Future<void> disable() => setEffect(AcrylicEffectOption.disabled);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final acrylicProvider =
    StateNotifierProvider<AcrylicNotifier, AcrylicState>(
  (ref) => AcrylicNotifier(),
);
