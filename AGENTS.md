# Repository Guidelines

## Project Structure & Module Organization
`lib/` contains application code: `ui/` for screens and widgets, `services/` for chat, OBS, TTS, and window integration, `pipeline/` for message flow, `settings/` for persisted app settings, `models/` for shared data types, and `window/` for desktop window state. Tests live in `test/` and follow the same feature split where practical. Static assets belong in `assets/`. Platform runners are in `android/`, `ios/`, `linux/`, `macos/`, `web/`, and `windows/`.

This app also depends on local packages declared in [pubspec.yaml](/abs/path/C:/Users/dpahu/Desktop/airchat-port/airchat_flutter/pubspec.yaml): `../dart_youtube_chat` and `../dart_kick_chat`. Keep those available when resolving dependencies.

## Build, Test, and Development Commands
Run these from the repository root:

- `flutter pub get` installs Dart and Flutter dependencies.
- `flutter run -d windows` launches the desktop app locally. Use another device id as needed.
- `flutter analyze` runs static analysis with `flutter_lints`.
- `flutter test` runs the full test suite under `test/`.
- `dart format lib test` formats the main source and test directories.
- `flutter build windows` or `flutter build web` produces release artifacts for the target platform.

## Coding Style & Naming Conventions
Use standard Dart formatting: 2-space indentation, trailing commas where they improve formatting, and `dart format` before submitting. Follow Flutter naming conventions: `snake_case.dart` for files, `UpperCamelCase` for types, `lowerCamelCase` for members, and descriptive widget/service names such as `ChatScreen` or `ObsService`. Prefer small, focused services and keep UI concerns under `lib/ui/`.

Avoid editing generated files under platform `flutter/` subdirectories unless regeneration requires it.

## Testing Guidelines
Tests use `flutter_test`. Name test files `*_test.dart` and keep test names behavior-focused, for example `deduplicates repeated messages...`. Add or update tests when changing pipeline, settings, or service behavior. No coverage gate is configured, so rely on targeted assertions around new logic and regressions.

## Commit & Pull Request Guidelines
Recent history uses Conventional Commit prefixes with imperative summaries, for example `feat: implement MessagePipeline for stream filtering`. Keep commit subjects concise and scoped.

Pull requests should include a short description, impacted platforms, test notes (`flutter analyze`, `flutter test`), and screenshots or recordings for visible UI changes. Link the related issue when one exists.
