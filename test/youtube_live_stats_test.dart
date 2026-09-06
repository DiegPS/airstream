import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/ui/widgets/youtube_live_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const summary = YoutubeLiveMetadataSummary(
    horizontal: YoutubeLiveMetadata(
      liveId: 'horizontal',
      streamOrientation: YoutubeStreamOrientation.horizontal,
      viewerCount: 1200,
      title: 'Noticias horizontal',
    ),
    vertical: YoutubeLiveMetadata(
      liveId: 'vertical',
      streamOrientation: YoutubeStreamOrientation.vertical,
      viewerCount: 550,
      title: 'Noticias vertical',
    ),
  );

  test('incremental metadata retains static fields and updates viewers', () {
    const initial = YoutubeLiveMetadata(
      liveId: 'live',
      viewerCount: 100,
      title: 'Original title',
      description: 'Description',
    );

    final updated = initial.merge(
      viewerCount: 125,
      title: '',
      description: null,
    );

    expect(updated.viewerCount, 125);
    expect(updated.title, 'Original title');
    expect(updated.description, 'Description');
  });

  test('total ignores streams whose audience is not available yet', () {
    const partial = YoutubeLiveMetadataSummary(
      horizontal: YoutubeLiveMetadata(liveId: 'horizontal', viewerCount: 42),
      vertical: YoutubeLiveMetadata(liveId: 'vertical'),
    );

    expect(partial.totalViewerCount, 42);
  });

  testWidgets('shows each YouTube audience and their total', (tester) async {
    await tester.pumpWidget(_app(
      locale: const Locale('es'),
      child: const YoutubeLiveStats(summary: summary),
    ));

    expect(find.byKey(const Key('youtube-live-stats')), findsOneWidget);
    expect(find.text('Horizontal'), findsOneWidget);
    expect(find.text('Vertical'), findsOneWidget);
    expect(find.text('Noticias horizontal'), findsOneWidget);
    expect(find.text('Noticias vertical'), findsOneWidget);
    expect(find.text('1.200'), findsOneWidget);
    expect(find.text('550'), findsOneWidget);
    expect(find.text('1.750 en total'), findsOneWidget);
  });

  testWidgets('shows a compact combined audience in the title bar',
      (tester) async {
    await tester.pumpWidget(_app(
      locale: const Locale('en'),
      child: const YoutubeLiveStats(summary: summary, compact: true),
    ));

    expect(find.byKey(const Key('youtube-viewers-icon')), findsOneWidget);
    expect(find.byKey(const Key('youtube-total-viewers')), findsOneWidget);
    expect(find.text('1.8K'), findsOneWidget);
  });

  testWidgets('renders nothing until a viewer count is available',
      (tester) async {
    await tester.pumpWidget(_app(
      locale: const Locale('en'),
      child: const YoutubeLiveStats(
        summary: YoutubeLiveMetadataSummary(
          primary: YoutubeLiveMetadata(liveId: 'live'),
        ),
      ),
    ));

    expect(find.byKey(const Key('youtube-live-stats')), findsNothing);
    expect(find.byKey(const Key('youtube-total-viewers')), findsNothing);
  });
}

Widget _app({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
