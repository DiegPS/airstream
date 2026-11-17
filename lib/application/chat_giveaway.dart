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

class ChatGiveaway {
  ChatGiveaway(
      {required this.keyword,
      required this.membersOnly,
      this.phase = GiveawayPhase.open,
      Iterable<GiveawayEntrant> entrants = const [],
      Iterable<GiveawayEntrant> winners = const [],
      this.drawId = 0})
      : entrants = List.unmodifiable(entrants),
        winners = List.unmodifiable(winners);
  final String keyword;
  final bool membersOnly;
  final GiveawayPhase phase;
  final List<GiveawayEntrant> entrants;
  final List<GiveawayEntrant> winners;
  final int drawId;
  int get entrantCount => entrants.length;
  GiveawayEntrant? get winner => winners.lastOrNull;
  ChatGiveaway _copy(
          {GiveawayPhase? phase,
          Iterable<GiveawayEntrant>? entrants,
          Iterable<GiveawayEntrant>? winners,
          int? drawId}) =>
      ChatGiveaway(
          keyword: keyword,
          membersOnly: membersOnly,
          phase: phase ?? this.phase,
          entrants: entrants ?? this.entrants,
          winners: winners ?? this.winners,
          drawId: drawId ?? this.drawId);
  Map<String, Object?> toOverlayJson() => {
        'keyword': keyword,
        'phase': phase.name,
        'entrantCount': entrantCount,
        'winner': winner == null
            ? null
            : {'name': winner!.name, 'platform': winner!.platform.name},
        'drawId': drawId,
      };
}

class ChatGiveawayController {
  ChatGiveawayController(
      {this.publishInterval = const Duration(milliseconds: 250)});
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

  void close() {
    final state = current;
    if (state == null || state.phase != GiveawayPhase.open) return;
    _current = state._copy(phase: GiveawayPhase.closed);
    _publishNow();
  }

  GiveawayEntrant? draw() {
    final state = current;
    if (state == null) return null;
    final won = state.winners.map((e) => e.identity).toSet();
    final eligible =
        state.entrants.where((e) => !won.contains(e.identity)).toList();
    if (eligible.isEmpty) return null;
    final winner = eligible[_random.nextInt(eligible.length)];
    _current = state._copy(
        phase: GiveawayPhase.drawn,
        winners: [...state.winners, winner],
        drawId: ++_drawSequence);
    _publishNow();
    return winner;
  }

  void clear() {
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
