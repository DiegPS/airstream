import 'chat_poll.dart';
import 'chat_queue.dart';

/// A named poll setup, including editor fields hidden by the selected mode.
class SavedPoll {
  const SavedPoll({
    required this.name,
    required this.question,
    required this.options,
    required this.mode,
    required this.minutes,
    required this.allowed,
    required this.hideResults,
    required this.allowChange,
    required this.command,
  });

  static const limit = 20;
  static const durations = [1, 2, 5];
  final String name, question, command;
  final List<String> options;
  final PollMode mode;
  final int? minutes;
  final QueueRole allowed;
  final bool hideResults, allowChange;

  Map<String, Object?> toJson() => {
        'name': name,
        'question': question,
        'options': options,
        'mode': mode.name,
        'minutes': minutes,
        'allowed': allowed.name,
        'hideResults': hideResults,
        'allowChange': allowChange,
        'command': command,
      };

  static String cleanName(String name) => _text(name, 60);

  static String _text(Object? raw, int max) => raw is String
      ? String.fromCharCodes(raw.trim().runes.take(max)).trim()
      : '';

  static SavedPoll? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = _text(raw['name'], 60);
    final question = _text(raw['question'], 500);
    final rawOptions = raw['options'];
    final options = [
      if (rawOptions is List)
        for (final option in rawOptions.take(ChatPoll.maxOptions))
          _text(option, 500),
    ];
    final mode = PollMode.values.asNameMap()[raw['mode']] ?? PollMode.numbered;
    final command = raw['command'] is String
        ? _text(raw['command'], 60).toLowerCase()
        : ChatPoll.defaultCommand;
    if (name.isEmpty) return null;
    try {
      ChatPollController.validateSetup(question, options, mode, command);
    } on ArgumentError {
      return null;
    }
    final minutes = raw['minutes'];
    return SavedPoll(
      name: name,
      question: question,
      options: List.unmodifiable(options),
      mode: mode,
      minutes: minutes is int && durations.contains(minutes) ? minutes : null,
      allowed:
          QueueRole.values.asNameMap()[raw['allowed']] ?? QueueRole.everyone,
      hideResults: raw['hideResults'] == true,
      allowChange: raw['allowChange'] != false,
      command: command,
    );
  }

  static List<SavedPoll> sanitize(Object? raw) {
    if (raw is! List) return const [];
    final names = <String>{};
    final saved = <SavedPoll>[];
    for (final item in raw) {
      if (fromJson(item) case final setup?) {
        if (names.add(setup.name.toLowerCase())) saved.add(setup);
      }
      if (saved.length == limit) break;
    }
    return List.unmodifiable(saved);
  }
}
