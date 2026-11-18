import 'dart:async';
import 'dart:math';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/speech/voice_command.dart';

enum GiveawayPhase { open, closed, drawn }

class GiveawayEntrant {
  const GiveawayEntrant(
      {required this.platform, required this.authorId, required this.name});
  final Platform platform;
  final String authorId;
  final String name;
  String get identity => '${platform.name}:$authorId';
}

class GiveawayRound {
  const GiveawayRound({
    required this.keyword,
    required this.startedAt,
    required this.endedAt,
    required this.entrantCount,
    required this.winners,
  });

  static const limit = 20;
  final String keyword;
  final DateTime startedAt, endedAt;
  final int entrantCount;
  final List<GiveawayEntrant> winners;

  Map<String, Object?> toJson() => {
        'keyword': keyword,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'entrantCount': entrantCount,
        'winners': [
          for (final winner in winners)
            {'name': winner.name, 'platform': winner.platform.name},
        ],
      };

  static String _text(Object? value, int max) => value is String
      ? String.fromCharCodes(value.trim().runes.take(max)).trim()
      : '';

  static GiveawayRound? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final keyword = _text(raw['keyword'], 250);
    final start = raw['startedAt'], end = raw['endedAt'];
    final count = raw['entrantCount'];
    if (keyword.isEmpty ||
        start is! int ||
        end is! int ||
        start < 0 ||
        end < start ||
        end > 8640000000000000 ||
        count is! int ||
        count < 0 ||
        count > 50000) {
      return null;
    }
    final winners = raw['winners'];
    return GiveawayRound(
      keyword: keyword,
      startedAt: DateTime.fromMillisecondsSinceEpoch(start),
      endedAt: DateTime.fromMillisecondsSinceEpoch(end),
      entrantCount: count,
      winners: List.unmodifiable([
        if (winners is List)
          for (final win in winners.take(count))
            if (win is Map)
              if (Platform.values.asNameMap()[win['platform']]
                  case final platform?)
                if (_text(win['name'], 250) case final name
                    when name.isNotEmpty)
                  GiveawayEntrant(platform: platform, authorId: '', name: name),
      ]),
    );
  }

  static List<GiveawayRound> sanitize(Object? raw) {
    if (raw is! List) return const [];
    final rounds = <GiveawayRound>[];
    for (final item in raw) {
      if (_fromJson(item) case final round?) rounds.add(round);
      if (rounds.length == limit) break;
    }
    return List.unmodifiable(rounds);
  }
}

class ChatGiveaway {
  ChatGiveaway(
      {required this.keyword,
      required this.membersOnly,
      this.phase = GiveawayPhase.open,
      Iterable<GiveawayEntrant> entrants = const [],
      Iterable<GiveawayEntrant> winners = const [],
      this.drawId = 0,
      this.batchDraw = false})
      : entrants = List.unmodifiable(entrants),
        winners = List.unmodifiable(winners);
  final String keyword;
  final bool membersOnly;
  final GiveawayPhase phase;
  final List<GiveawayEntrant> entrants;
  final List<GiveawayEntrant> winners;
  final int drawId;
  final bool batchDraw;
  int get entrantCount => entrants.length;
  GiveawayEntrant? get winner => winners.lastOrNull;
  ChatGiveaway _copy(
          {GiveawayPhase? phase,
          Iterable<GiveawayEntrant>? entrants,
          Iterable<GiveawayEntrant>? winners,
          int? drawId,
          bool? batchDraw}) =>
      ChatGiveaway(
          keyword: keyword,
          membersOnly: membersOnly,
          phase: phase ?? this.phase,
          entrants: entrants ?? this.entrants,
          winners: winners ?? this.winners,
          drawId: drawId ?? this.drawId,
          batchDraw: batchDraw ?? this.batchDraw);
  Map<String, Object?> toOverlayJson() => {
        'keyword': keyword,
        'phase': phase.name,
        'entrantCount': entrantCount,
        'winner': winner == null
            ? null
            : {'name': winner!.name, 'platform': winner!.platform.name},
        'drawId': drawId,
        if (batchDraw) 'batchDraw': true,
      };
}

class ChatGiveawayController {
  ChatGiveawayController({
    this.publishInterval = const Duration(milliseconds: 250),
    DateTime Function()? clock,
    this.onHistoryChanged,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final void Function(List<GiveawayRound>)? onHistoryChanged;
  List<GiveawayRound> _history = const [];
  List<GiveawayRound> get history => _history;
  DateTime? _startedAt, _endedAt;
  GiveawayRound? _record;

  void restoreHistory(List<GiveawayRound> history) {
    if (identical(history, _history)) return;
    _history = history;
    _record = null;
  }

  void clearHistory() {
    restoreHistory(const []);
    onHistoryChanged?.call(_history);
  }

  void _recordRound(ChatGiveaway state) {
    final started = _startedAt!;
    final now = _clock();
    final round = GiveawayRound(
      keyword: state.keyword,
      startedAt: started,
      endedAt: _endedAt ??= now.isBefore(started) ? started : now,
      entrantCount: state.entrantCount,
      winners: state.winners,
    );
    // The same round may come back as a new object after a settings reload,
    // so it is matched by its start time too (stored in milliseconds).
    bool sameRound(GiveawayRound item) =>
        identical(item, _record) ||
        (item.keyword == round.keyword &&
            item.startedAt.millisecondsSinceEpoch ==
                started.millisecondsSinceEpoch);
    _history = List.unmodifiable([
      round,
      ..._history
          .where((item) => !sameRound(item))
          .take(GiveawayRound.limit - 1),
    ]);
    _record = round;
    onHistoryChanged?.call(_history);
  }

  final Duration publishInterval;
  final _random = Random.secure();
  final _states = StreamController<ChatGiveaway?>.broadcast();
  final _identities = <String>{};
  // Batch immutable snapshots rather than copying up to 50,000 entries for
  // every arriving message. Published states never share this mutable list.
  final _entrants = <GiveawayEntrant>[];
  bool _dirty = false;
  String _keyword = '';
  ChatGiveaway? _current;
  Timer? _publishTimer;
  int _drawSequence = 0;
  bool _disposed = false;
  ChatGiveaway? get current {
    if (_dirty) {
      _current = _current!._copy(entrants: _entrants);
      _dirty = false;
    }
    return _current;
  }

  Stream<ChatGiveaway?> get states async* {
    yield current;
    yield* _states.stream;
  }

  void start({required String keyword, required bool membersOnly}) {
    if (normalizeVoiceText(keyword).isEmpty) {
      throw ArgumentError('A giveaway needs a keyword.');
    }
    _close(publish: false);
    _startedAt = _clock();
    _endedAt = null;
    _record = null;
    _identities.clear();
    _entrants.clear();
    _dirty = false;
    _keyword = normalizeVoiceText(keyword);
    _current = ChatGiveaway(keyword: keyword.trim(), membersOnly: membersOnly);
    _publishNow();
  }

  void handleMessage(ChatMessage message) {
    final state = _current;
    if (state == null ||
        state.phase != GiveawayPhase.open ||
        _entrants.length >= 50000 ||
        message.isMembershipEvent ||
        message.membershipEventKind != null ||
        message.superChat != null ||
        (state.membersOnly && !message.isMembership)) {
      return;
    }
    final text = normalizeVoiceText(message.plainText);
    if (text != _keyword && !text.startsWith('$_keyword ')) return;
    final entrant = GiveawayEntrant(
        platform: message.platform,
        authorId: message.author.channelId.trim().isNotEmpty
            ? message.author.channelId.trim()
            : message.author.name.trim().toLowerCase(),
        name: message.author.name);
    if (!_identities.add(entrant.identity)) return;
    _entrants.add(entrant);
    _dirty = true;
    _publishTimer ??= Timer(publishInterval, _publishNow);
  }

  void close() => _close(publish: true);

  void _close({required bool publish}) {
    final state = current;
    if (state == null || state.phase != GiveawayPhase.open) return;
    _current = state._copy(phase: GiveawayPhase.closed);
    _recordRound(_current!);
    if (publish) _publishNow();
  }

  GiveawayEntrant? draw() => drawMany(1).firstOrNull;

  List<GiveawayEntrant> drawMany(int count,
      {void Function(GiveawayEntrant, int)? onDraw}) {
    final state = current;
    if (state == null) return const [];
    final won = state.winners.map((e) => e.identity).toSet();
    final eligible =
        state.entrants.where((e) => !won.contains(e.identity)).toList();
    final total = min(count.clamp(1, 10), eligible.length);
    final draws = <(GiveawayEntrant, int)>[];
    for (var i = 0; i < total; i++) {
      final index = _random.nextInt(eligible.length);
      final winner = eligible[index];
      // Swap with the tail for a uniform draw without replacement.
      eligible[index] = eligible.last;
      eligible.removeLast();
      final drawId = ++_drawSequence;
      draws.add((winner, drawId));
      _current = _current!._copy(
          phase: GiveawayPhase.drawn,
          winners: [..._current!.winners, winner],
          drawId: drawId,
          batchDraw: total > 1);
      _publishNow();
    }
    if (draws.isNotEmpty) _recordRound(_current!);
    for (final (winner, id) in draws) {
      onDraw?.call(winner, id);
    }
    return List.unmodifiable(draws.map((draw) => draw.$1));
  }

  void clear() {
    _close(publish: false);
    _current = null;
    _identities.clear();
    _entrants.clear();
    _dirty = false;
    _publishNow();
  }

  void _publishNow() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!_disposed) _states.add(current);
  }

  Future<void> dispose() async {
    _disposed = true;
    _publishTimer?.cancel();
    await _states.close();
  }
}
