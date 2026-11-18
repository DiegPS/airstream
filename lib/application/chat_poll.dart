import 'dart:async';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:flutter/widgets.dart' show Locale, StringCharacters;

import 'chat_queue.dart';
import 'poll_text.dart';

enum PollMode { numbered, word, yesNo, rating, freeAnswer }

enum PollInputError { invalid, ambiguousOptions, optionTooLong, invalidCommand }

typedef PollAnswer = ({String text, int votes});
typedef _FreeVote = ({String normalized, String original});

/// A poll viewers can answer from any connected chat.
class ChatPoll {
  const ChatPoll({
    required this.question,
    this.options = const [],
    this.votes = const {},
    this.freeVotes = const {},
    this.mode = PollMode.numbered,
    this.hideResults = false,
    this.allowed = QueueRole.everyone,
    this.allowChange = true,
    this.command = defaultCommand,
    this.endsAt,
    this.closed = false,
  });

  static const minOptions = 2;
  static const maxOptions = 5;
  static const maxTextLength = 40;
  static const defaultCommand = '!r';

  final String question;
  final List<String> options;

  /// Each voter's option or rating bucket (both zero-based).
  final Map<String, int> votes;
  final Map<String, ({String normalized, String original})> freeVotes;
  final PollMode mode;
  final bool hideResults, allowChange;
  final QueueRole allowed;
  final String command;

  /// When the poll closes on its own; null for a poll without a time limit.
  final DateTime? endsAt;
  final bool closed;

  List<int> get counts {
    final counts =
        List<int>.filled(mode == PollMode.rating ? 10 : options.length, 0);
    for (final choice in votes.values) {
      counts[choice]++;
    }
    return counts;
  }

  int get total => votes.length + freeVotes.length;

  double? get average => mode != PollMode.rating || total == 0
      ? null
      : votes.values.fold(0, (sum, choice) => sum + choice + 1) / total;

  ({List<PollAnswer> top, int distinct}) get answers {
    final groups = <String, Map<String, int>>{};
    for (final vote in freeVotes.values) {
      final spellings = groups.putIfAbsent(vote.normalized, () => {});
      spellings.update(vote.original, (count) => count + 1, ifAbsent: () => 1);
    }
    final ranked = <PollAnswer>[];
    for (final spellings in groups.values) {
      var text = '';
      var best = 0;
      var votes = 0;
      for (final spelling in spellings.entries) {
        votes += spelling.value;
        // On a tie the spelling seen first wins (map insertion order).
        if (spelling.value > best) {
          text = spelling.key;
          best = spelling.value;
        }
      }
      ranked.add((text: text, votes: votes));
    }
    ranked.sort((a, b) {
      final byVotes = b.votes.compareTo(a.votes);
      return byVotes == 0 ? a.text.compareTo(b.text) : byVotes;
    });
    return (top: ranked.take(10).toList(), distinct: groups.length);
  }

  String get winner {
    if (total == 0) return '';
    if (mode == PollMode.rating) return average!.toStringAsFixed(1);
    if (mode == PollMode.freeAnswer) return answers.top.first.text;
    final results = counts;
    var winner = 0;
    for (var i = 1; i < results.length; i++) {
      if (results[i] > results[winner]) winner = i;
    }
    return options[winner];
  }

  ChatPoll _copyWith({
    Map<String, int>? votes,
    Map<String, _FreeVote>? freeVotes,
    bool? closed,
  }) =>
      ChatPoll(
        question: question,
        options: options,
        votes: votes ?? this.votes,
        freeVotes: freeVotes ?? this.freeVotes,
        mode: mode,
        hideResults: hideResults,
        allowed: allowed,
        allowChange: allowChange,
        command: command,
        endsAt: endsAt,
        closed: closed ?? this.closed,
      );

  /// Public snapshot shared by built-in pages and SDK v1 templates.
  Map<String, Object?> toOverlayJson() {
    final hidden = hideResults && !closed;
    final classic = mode == PollMode.numbered &&
        !hideResults &&
        allowed == QueueRole.everyone &&
        allowChange;
    final counts = hidden ? null : this.counts;
    final average = hidden ? null : this.average;
    final answers =
        !hidden && mode == PollMode.freeAnswer ? this.answers : null;
    return {
      'question': question,
      'options': [
        for (var i = 0; i < options.length; i++)
          {
            'label': options[i],
            if (counts != null) ...{
              'votes': counts[i],
              'percent': total == 0 ? 0 : (counts[i] * 100 / total).round(),
            },
          },
      ],
      'total': total,
      'closed': closed,
      'endsAt': endsAt?.millisecondsSinceEpoch,
      if (!classic) ...{
        'mode': mode.name,
        'hidden': hidden,
        'allowed': allowed.name,
      },
      if (!hidden && mode == PollMode.rating) ...{
        'average':
            average == null ? null : double.parse(average.toStringAsFixed(1)),
        'distribution': counts,
      },
      if (mode == PollMode.freeAnswer) 'command': command,
      if (answers != null) ...{
        'answers': [
          for (final answer in answers.top)
            {'text': answer.text, 'votes': answer.votes},
        ],
        'distinct': answers.distinct,
      },
    };
  }
}

/// Runs one poll at a time and counts the votes that arrive in the chat.
class ChatPollController {
  ChatPollController({
    DateTime Function()? clock,
    this.publishInterval = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Votes are published at most this often.
  final Duration publishInterval;

  final _states = StreamController<ChatPoll?>.broadcast();
  final _ended = StreamController<ChatPoll>.broadcast();
  ChatPoll? _poll;
  ChatPoll? _openPoll;
  Map<String, int> _wordOptions = const {};
  final _privateVoteIds = <String>{};
  Timer? _endTimer;
  Timer? _publishTimer;
  bool _disposed = false;

  ChatPoll? get current => _poll;
  bool get hasOpenPoll => _openPoll != null;
  Stream<ChatPoll> get ended => _ended.stream;
  bool isPrivateVote(ChatMessage message) =>
      _privateVoteIds.contains(message.dedupeKey);

  Stream<ChatPoll?> get states async* {
    yield _poll;
    yield* _states.stream;
  }

  static final _numberedVote = RegExp(r'^\s*!([1-9])(?:\s|$)');
  static final _ratingVote = RegExp(r'^!?(10|[1-9])$');
  static final _commandWord = RegExp(r'^\S+');

  void start({
    required String question,
    List<String> options = const [],
    Duration? duration,
    PollMode mode = PollMode.numbered,
    bool hideResults = false,
    QueueRole allowed = QueueRole.everyone,
    bool allowChange = true,
    String command = ChatPoll.defaultCommand,
    String language = 'en',
  }) {
    final (cleanOptions, keys, cleanCommand) =
        validateSetup(question, options, mode, command);
    _wordOptions = keys;
    _privateVoteIds.clear();
    _endTimer?.cancel();
    _poll = _openPoll = ChatPoll(
      question: question.trim(),
      options: List.unmodifiable(
          mode == PollMode.yesNo ? _yesNoOptions(language) : cleanOptions),
      mode: mode,
      hideResults: hideResults,
      allowed: allowed,
      allowChange: allowChange,
      command: cleanCommand,
      endsAt: duration == null ? null : _clock().add(duration),
    );
    if (duration != null) _endTimer = Timer(duration, end);
    _publishNow();
  }

  static (List<String>, Map<String, int>, String) validateSetup(
      String question, List<String> options, PollMode mode, String command) {
    final cleanOptions = switch (mode) {
      PollMode.numbered || PollMode.word => [
          for (final option in options)
            if (option.trim().isNotEmpty) option.trim(),
        ],
      PollMode.yesNo => <String>[],
      PollMode.rating || PollMode.freeAnswer => <String>[],
    };
    if (question.trim().isEmpty ||
        ((mode == PollMode.numbered || mode == PollMode.word) &&
            (cleanOptions.length < ChatPoll.minOptions ||
                cleanOptions.length > ChatPoll.maxOptions))) {
      throw ArgumentError.value(PollInputError.invalid);
    }
    final keys = <String, int>{};
    if (mode == PollMode.word) {
      for (final (index, option) in cleanOptions.indexed) {
        if (option.characters.length > ChatPoll.maxTextLength) {
          throw ArgumentError.value(PollInputError.optionTooLong);
        }
        final key = normalizePollText(option);
        if (key.isEmpty) {
          throw ArgumentError.value(PollInputError.ambiguousOptions);
        }
        for (final spelling in [key, '!$key', '! $key']) {
          if (keys.containsKey(spelling)) {
            throw ArgumentError.value(PollInputError.ambiguousOptions);
          }
          keys[spelling] = index;
        }
      }
    }
    final cleanCommand = command.trim().toLowerCase();
    if (mode == PollMode.freeAnswer &&
        (!QueueOptions.validCommand(cleanCommand) ||
            QueueOptions.reservedCommand(cleanCommand))) {
      throw ArgumentError.value(PollInputError.invalidCommand);
    }
    return (cleanOptions, keys, cleanCommand);
  }

  static List<String> _yesNoOptions(String language) {
    final l = lookupAppLocalizations(Locale(language == 'es' ? 'es' : 'en'));
    return [l.pollYes, l.pollNo];
  }

  void end() {
    final poll = _openPoll;
    if (poll == null) return;
    _endTimer?.cancel();
    _openPoll = null;
    _privateVoteIds.clear();
    final closed = _poll = poll._copyWith(closed: true);
    _publishNow();
    if (!_disposed) _ended.add(closed);
  }

  void clear() {
    _endTimer?.cancel();
    _poll = _openPoll = null;
    _privateVoteIds.clear();
    _publishNow();
  }

  /// Returns true for a hidden submission so public chat and template actions
  /// cannot disclose the vote in a separate event.
  bool handleMessage(ChatMessage message) {
    final poll = _openPoll;
    if (poll == null) return false;
    final endsAt = poll.endsAt;
    if (endsAt != null && !_clock().isBefore(endsAt)) {
      end();
      return false;
    }
    if (!poll.allowed.allows(message)) return false;
    final text = message.plainText;
    final choice = switch (poll.mode) {
      PollMode.numbered => parseVote(text, poll.options.length),
      PollMode.word => _wordOptions[normalizePollText(text)],
      PollMode.yesNo => switch (text.trim().toLowerCase()) {
          'sí' || 'si\u0301' || 'si' || 'yes' || 'y' || '1' || '!1' => 0,
          'no' || 'n' || '2' || '!2' => 1,
          _ => null,
        },
      PollMode.rating => switch (
            _ratingVote.firstMatch(text.trim())?.group(1)) {
          final String value => int.parse(value) - 1,
          null => null,
        },
      PollMode.freeAnswer => null,
    };
    final answer = poll.mode == PollMode.freeAnswer
        ? _parseAnswer(text, poll.command)
        : null;
    if (choice == null && answer == null) return false;
    final private = poll.hideResults;
    if (private) _privateVoteIds.add(message.dedupeKey);
    final author = message.author.channelId.trim().isNotEmpty
        ? message.author.channelId
        : message.author.name;
    final voter = '${message.platform.name}:${author.trim().toLowerCase()}';
    if (choice != null) {
      final previous = poll.votes[voter];
      if (previous == choice || (!poll.allowChange && previous != null)) {
        return private;
      }
      _poll = _openPoll = poll._copyWith(
          votes: Map.unmodifiable({...poll.votes, voter: choice}));
    } else if (answer != null) {
      final previous = poll.freeVotes[voter];
      if (previous == answer || (!poll.allowChange && previous != null)) {
        return private;
      }
      _poll = _openPoll = poll._copyWith(
          freeVotes: Map.unmodifiable({...poll.freeVotes, voter: answer}));
    }
    _schedulePublish();
    return private;
  }

  /// The option index in a classic vote, which allows trailing chat text.
  static int? parseVote(String text, int optionCount) {
    final match = _numberedVote.firstMatch(text);
    if (match == null) return null;
    final index = int.parse(match.group(1)!) - 1;
    return index < optionCount ? index : null;
  }

  static _FreeVote? _parseAnswer(String text, String command) {
    final trimmed = text.trim();
    final word = _commandWord.stringMatch(trimmed);
    if (word == null || word.toLowerCase() != command) return null;
    final answer = trimmed.substring(word.length).trim();
    if (answer.isEmpty || answer.characters.length > ChatPoll.maxTextLength) {
      return null;
    }
    final normalized = normalizePollText(answer);
    return normalized.isEmpty
        ? null
        : (normalized: normalized, original: answer);
  }

  void _schedulePublish() {
    if (_publishTimer != null) return;
    _publishTimer = Timer(publishInterval, _publishNow);
  }

  void _publishNow() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!_disposed) _states.add(_poll);
  }

  Future<void> dispose() async {
    _disposed = true;
    _endTimer?.cancel();
    _publishTimer?.cancel();
    await _states.close();
    await _ended.close();
  }
}
