import 'dart:async';

import 'package:airstream/models/chat_message.dart';

/// A poll viewers answer from any chat by typing `!1`, `!2`…
class ChatPoll {
  const ChatPoll({
    required this.question,
    required this.options,
    this.votes = const {},
    this.endsAt,
    this.closed = false,
  });

  static const minOptions = 2;
  static const maxOptions = 5;

  final String question;
  final List<String> options;

  /// Each voter's choice (an index into [options]), by platform and author.
  final Map<String, int> votes;

  /// When the poll closes on its own; null for a poll without a time limit.
  final DateTime? endsAt;
  final bool closed;

  List<int> get counts {
    final counts = List<int>.filled(options.length, 0);
    for (final choice in votes.values) {
      counts[choice]++;
    }
    return counts;
  }

  int get total => votes.length;

  ChatPoll _copyWith({Map<String, int>? votes, bool? closed}) => ChatPoll(
        question: question,
        options: options,
        votes: votes ?? this.votes,
        endsAt: endsAt,
        closed: closed ?? this.closed,
      );

  /// What the poll overlay draws.
  Map<String, Object?> toOverlayJson() {
    final counts = this.counts;
    return {
      'question': question,
      'options': [
        for (var i = 0; i < options.length; i++)
          {
            'label': options[i],
            'votes': counts[i],
            'percent': total == 0 ? 0 : (counts[i] * 100 / total).round(),
          },
      ],
      'total': total,
      'closed': closed,
      'endsAt': endsAt?.millisecondsSinceEpoch,
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

  /// Votes are published at most this often: a busy chat votes many times a
  /// second, and the app and the overlay only need a few updates.
  final Duration publishInterval;

  final _states = StreamController<ChatPoll?>.broadcast();
  ChatPoll? _poll;
  Timer? _endTimer;
  Timer? _publishTimer;
  bool _disposed = false;

  ChatPoll? get current => _poll;

  Stream<ChatPoll?> get states async* {
    yield _poll;
    yield* _states.stream;
  }

  void start({
    required String question,
    required List<String> options,
    Duration? duration,
  }) {
    final cleanOptions = [
      for (final option in options)
        if (option.trim().isNotEmpty) option.trim(),
    ];
    if (question.trim().isEmpty ||
        cleanOptions.length < ChatPoll.minOptions ||
        cleanOptions.length > ChatPoll.maxOptions) {
      throw ArgumentError('A poll needs a question and 2 to 5 options.');
    }
    _endTimer?.cancel();
    _poll = ChatPoll(
      question: question.trim(),
      options: cleanOptions,
      endsAt: duration == null ? null : _clock().add(duration),
    );
    if (duration != null) _endTimer = Timer(duration, end);
    _publishNow();
  }

  void end() {
    final poll = _poll;
    if (poll == null || poll.closed) return;
    _endTimer?.cancel();
    _poll = poll._copyWith(closed: true);
    _publishNow();
  }

  void clear() {
    _endTimer?.cancel();
    _poll = null;
    _publishNow();
  }

  void handleMessage(ChatMessage message) {
    final poll = _poll;
    if (poll == null || poll.closed) return;
    final endsAt = poll.endsAt;
    if (endsAt != null && !_clock().isBefore(endsAt)) {
      end();
      return;
    }
    final choice = parseVote(message.plainText, poll.options.length);
    if (choice == null) return;
    final author = message.author.channelId.trim().isNotEmpty
        ? message.author.channelId
        : message.author.name;
    final voter = '${message.platform.name}:${author.trim().toLowerCase()}';
    if (poll.votes[voter] == choice) return;
    // A viewer who changes their mind keeps only the last vote.
    _poll = poll._copyWith(votes: {...poll.votes, voter: choice});
    _schedulePublish();
  }

  /// The option index a chat message votes for, or null: `!2` or `!2 text`
  /// votes for the second option.
  static int? parseVote(String text, int optionCount) {
    final match = RegExp(r'^\s*!([1-9])(?:\s|$)').firstMatch(text);
    if (match == null) return null;
    final index = int.parse(match.group(1)!) - 1;
    return index < optionCount ? index : null;
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
  }
}
