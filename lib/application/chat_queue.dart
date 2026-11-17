import 'dart:async';
import 'dart:math';

import 'package:airstream/models/chat_message.dart';

const _leaveCommands = {'!salir', '!leave'};
const _moderatorCommands = {
  '!siguiente',
  '!next',
  '!abrir',
  '!open',
  '!cerrar',
  '!close',
  '!pausar',
  '!pause',
  '!quitar',
  '!remove',
};

enum QueueStatus { closed, open, paused }

enum QueueRole { everyone, member, vip, moderator }

class QueueOptions {
  const QueueOptions({
    this.command = '',
    this.max = 50,
    this.role = QueueRole.everyone,
    this.priority = false,
    this.rejoin = true,
    this.moderatorCommands = false,
    this.nextCount = 1,
  });

  static final _commandPattern =
      RegExp(r'^![a-z0-9áéíóúñü_-]{1,24}$', caseSensitive: false);

  static bool validCommand(String value) =>
      _commandPattern.stringMatch(value) == value;

  static bool reservedCommand(String value) {
    final lower = value.toLowerCase();
    return _leaveCommands.contains(lower) || _moderatorCommands.contains(lower);
  }

  final String command;
  final int max, nextCount;
  final QueueRole role;
  final bool priority, rejoin, moderatorCommands;

  String commandFor(String language) =>
      validCommand(command) && !reservedCommand(command)
          ? command
          : (language == 'es' ? '!unirme' : '!join');

  QueueOptions copyWith({
    String? command,
    int? max,
    QueueRole? role,
    bool? priority,
    bool? rejoin,
    bool? moderatorCommands,
    int? nextCount,
  }) =>
      QueueOptions(
        command: command ?? this.command,
        max: max ?? this.max,
        role: role ?? this.role,
        priority: priority ?? this.priority,
        rejoin: rejoin ?? this.rejoin,
        moderatorCommands: moderatorCommands ?? this.moderatorCommands,
        nextCount: nextCount ?? this.nextCount,
      );

  factory QueueOptions.fromJson(Object? raw) {
    final map = raw is Map ? raw : const {};
    final command = map['command'];
    final max = map['max'];
    final nextCount = map['nextCount'];
    return QueueOptions(
      command: command is String &&
              validCommand(command.trim()) &&
              !reservedCommand(command.trim())
          ? command.trim().toLowerCase()
          : '',
      max: max is int ? max.clamp(5, 100) : 50,
      role: QueueRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => QueueRole.everyone,
      ),
      priority: map['priority'] == true,
      rejoin: map['rejoin'] != false,
      moderatorCommands: map['moderatorCommands'] == true,
      nextCount: nextCount is int ? nextCount.clamp(1, 10) : 1,
    );
  }

  Map<String, Object?> toJson() => {
        'command': command,
        'max': max,
        'role': role.name,
        'priority': priority,
        'rejoin': rejoin,
        'moderatorCommands': moderatorCommands,
        'nextCount': nextCount,
      };
}

final _controls = RegExp(r'[\x00-\x1f\x7f-\x9f]');

String _cleanNote(String text) =>
    String.fromCharCodes(text.replaceAll(_controls, '').trim().runes.take(30))
        .trimRight();

class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.platform,
    required this.name,
    required this.identity,
    required this.note,
    required this.priority,
    required this.joinedAt,
    this.roles = const [],
  });

  final String id, name, identity, note;
  final Platform platform;
  final bool priority;
  final DateTime joinedAt;
  final List<String> roles;

  QueueEntry withNote(String note) => QueueEntry(
        id: id,
        platform: platform,
        name: name,
        identity: identity,
        note: note,
        priority: priority,
        joinedAt: joinedAt,
        roles: roles,
      );

  Map<String, Object?> toOverlayJson() => {
        'id': id,
        'platform': platform.name,
        'name': name,
        'note': note,
        'priority': priority,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> toJson() =>
      {...toOverlayJson(), 'identity': identity, 'roles': roles};

  static QueueEntry? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'], identity = raw['identity'];
    final platform =
        Platform.values.where((p) => p.name == raw['platform']).firstOrNull;
    final timestamp = raw['joinedAt'];
    final joinedAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (id is! String ||
        !_idPattern.hasMatch(id) ||
        name is! String ||
        identity is! String ||
        platform == null ||
        !identity.startsWith('${platform.name}:') ||
        joinedAt == null) {
      return null;
    }
    final roles = raw['roles'];
    return QueueEntry(
      id: id,
      platform: platform,
      name: name,
      identity: identity,
      note: _cleanNote(raw['note'] is String ? raw['note'] as String : ''),
      priority: raw['priority'] == true,
      joinedAt: joinedAt,
      roles: List.unmodifiable(roles is List
          ? roles.whereType<String>().where(_roleNames.contains).toSet()
          : const <String>[]),
    );
  }

  static final _idPattern = RegExp(r'^q-?\d+-\d+$');
  static const _roleNames = {'owner', 'moderator', 'member', 'vip'};
}

class QueueState {
  const QueueState({
    this.status = QueueStatus.closed,
    this.entries = const [],
    this.playing = const [],
    this.played = const {},
    this.sequence = 0,
  });

  final QueueStatus status;
  final List<QueueEntry> entries, playing;
  final Set<String> played;
  final int sequence;

  factory QueueState.fromJson(Object? raw) {
    if (raw is! Map) return const QueueState();
    final ids = <String>{}, identities = <String>{};
    var sequence = raw['sequence'] is int ? raw['sequence'] as int : 0;
    List<QueueEntry> entries(Object? list, int limit) {
      if (list is! List) return const [];
      final result = <QueueEntry>[];
      for (final item in list.take(limit)) {
        final entry = QueueEntry._fromJson(item);
        if (entry == null ||
            ids.contains(entry.id) ||
            !identities.add(entry.identity)) {
          continue;
        }
        ids.add(entry.id);
        result.add(entry);
      }
      return List.unmodifiable(result);
    }

    final playing = entries(raw['playing'], 10);
    final waiting = entries(raw['entries'], 100);
    for (final entry in [...playing, ...waiting]) {
      sequence = max(sequence, int.tryParse(entry.id.split('-').last) ?? 0);
    }
    final played = raw['played'];
    return QueueState(
      status: QueueStatus.values.firstWhere(
        (status) => status.name == raw['status'],
        orElse: () => QueueStatus.closed,
      ),
      entries: waiting,
      playing: playing,
      played: Set.unmodifiable({
        if (played is List) ...played.whereType<String>(),
        for (final entry in playing) entry.identity,
      }),
      sequence: max(0, sequence),
    );
  }

  Map<String, Object?> toJson() => {
        'status': status.name,
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'playing': playing.map((entry) => entry.toJson()).toList(),
        'played': played.toList(),
        'sequence': sequence,
      };

  Map<String, Object?> toOverlayJson(int max, String command) => {
        'status': status.name,
        'entries': entries.map((entry) => entry.toOverlayJson()).toList(),
        'playing': playing.map((entry) => entry.toOverlayJson()).toList(),
        'max': max,
        'command': command,
      };
}

class ChatQueueController {
  ChatQueueController({
    DateTime Function()? clock,
    Random? random,
    this.publishInterval = const Duration(milliseconds: 250),
    this.onJoined,
    this.onNext,
    this.onPersist,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  final DateTime Function() _clock;
  final Random _random;
  final Duration publishInterval;
  final void Function(QueueEntry, int position)? onJoined;
  final void Function(List<QueueEntry>, int depth)? onNext;
  final void Function(QueueState)? onPersist;

  final _states = StreamController<QueueState>.broadcast();
  final _entries = <QueueEntry>[];
  final _playing = <QueueEntry>[];
  final _played = <String>{};
  var _options = const QueueOptions();
  var _command = '!join';
  var _status = QueueStatus.closed;
  var _dirty = false;
  var _sequence = 0;
  Timer? _timer;

  Stream<QueueState> get states => _states.stream;
  QueueStatus get status => _status;
  bool get hasEntries => _entries.isNotEmpty;

  QueueState get current => QueueState(
        status: _status,
        entries: List.unmodifiable(_entries),
        playing: List.unmodifiable(_playing),
        played: Set.unmodifiable(_played),
        sequence: _sequence,
      );

  void restore(QueueState state) {
    final visibleChange = state.status != _status ||
        state.entries.isNotEmpty ||
        _entries.isNotEmpty ||
        state.playing.isNotEmpty ||
        _playing.isNotEmpty ||
        state.played.isNotEmpty ||
        _played.isNotEmpty;
    _status = state.status;
    _entries
      ..clear()
      ..addAll(state.entries);
    _playing
      ..clear()
      ..addAll(state.playing);
    _played
      ..clear()
      ..addAll(state.played);
    _sequence = state.sequence;
    if (visibleChange) _schedule();
  }

  void configure(QueueOptions options, String language) {
    final command = options.commandFor(language).toLowerCase();
    if (command != _command || options.max != _options.max) _schedule();
    _options = options;
    _command = command;
  }

  Map<String, Object?> overlayState([QueueState? state]) =>
      (state ?? current).toOverlayJson(_options.max, _command);

  void setStatus(QueueStatus status) {
    if (status == _status) return;
    _status = status;
    _changed();
  }

  static final _word = RegExp(r'^\S+');

  // Cheap gate for every chat message: a closed queue with no moderator
  // commands only listens while someone is still in it (to let them leave).
  var _disposed = false;

  bool get _acceptCommands =>
      !_disposed &&
      (_status != QueueStatus.closed ||
          _options.moderatorCommands ||
          _entries.isNotEmpty);

  void handleMessage(ChatMessage message) {
    if (!_acceptCommands) return;
    // Check the first visible character before assembling/parsing plainText.
    for (final item in message.items) {
      final text = item.emoji?.alt ?? item.text;
      if (text.isEmpty) continue;
      if (text.codeUnitAt(0) == 33) _handleCommand(message);
      return;
    }
  }

  void _handleCommand(ChatMessage message) {
    final text = message.plainText;
    final word = _word.stringMatch(text)!;
    final command = word.toLowerCase();
    if (_leaveCommands.contains(command)) {
      final identity = _identity(message);
      _remove(_entries, (entry) => entry.identity == identity);
      return;
    }
    if (_moderatorCommands.contains(command) &&
        _options.moderatorCommands &&
        (message.isOwner || message.isModerator)) {
      _handleModerator(command, text.substring(word.length).trim());
      return;
    }
    if (_status != QueueStatus.open ||
        command != _command ||
        !(_allows(message) || message.isOwner)) {
      return;
    }
    final identity = _identity(message);
    final index = _entries.indexWhere((entry) => entry.identity == identity);
    if (index >= 0) {
      final note = _cleanNote(text.substring(word.length));
      if (note != _entries[index].note) {
        _entries[index] = _entries[index].withNote(note);
        _changed();
      }
      return;
    }
    if (_entries.length >= _options.max ||
        (!_options.rejoin && _played.contains(identity)) ||
        _playing.any((entry) => entry.identity == identity)) {
      return;
    }
    final now = _clock();
    final entry = QueueEntry(
      id: 'q${now.millisecondsSinceEpoch}-${++_sequence}',
      platform: message.platform,
      name: message.author.name,
      identity: identity,
      note: _cleanNote(text.substring(word.length)),
      priority: _options.priority && message.isMembership,
      joinedAt: now,
      roles: List.unmodifiable([
        if (message.isOwner) 'owner',
        if (message.isModerator || message.isOwner) 'moderator',
        if (message.isMembership) 'member',
        if (message.isVip) 'vip',
      ]),
    );
    final position = entry.priority
        ? _entries.lastIndexWhere((entry) => entry.priority) + 1
        : _entries.length;
    _entries.insert(position, entry);
    _changed();
    onJoined?.call(entry, position + 1);
  }

  bool _allows(ChatMessage message) => switch (_options.role) {
        QueueRole.everyone => true,
        QueueRole.member => message.isMembership,
        QueueRole.vip => message.isVip,
        QueueRole.moderator => message.isModerator,
      };

  static String _identity(ChatMessage message) {
    final id = message.author.channelId.trim();
    final key = id.isEmpty ? message.author.name.trim().toLowerCase() : id;
    return '${message.platform.name}:$key';
  }

  void _handleModerator(String command, String args) {
    switch (command) {
      case '!siguiente' || '!next':
        final count = args.isEmpty ? _options.nextCount : int.tryParse(args);
        if (count != null && count >= 1 && count <= 10) next(count);
      case '!abrir' || '!open':
        setStatus(QueueStatus.open);
      case '!cerrar' || '!close':
        setStatus(QueueStatus.closed);
      case '!pausar' || '!pause':
        setStatus(QueueStatus.paused);
      case '!quitar' || '!remove':
        if (args.isEmpty) return;
        final name = args.toLowerCase();
        _remove(_entries, (entry) => entry.name.trim().toLowerCase() == name);
    }
  }

  List<QueueEntry> next(int count, {bool random = false, int depth = 0}) {
    if (_entries.isEmpty) return const [];
    final picked = List<QueueEntry>.generate(
      min(count.clamp(1, 10), _entries.length),
      (_) => _entries.removeAt(random ? _random.nextInt(_entries.length) : 0),
    );
    _played.addAll(picked.map((entry) => entry.identity));
    _playing.addAll(picked);
    if (_playing.length > 10) _playing.removeRange(0, _playing.length - 10);
    _changed();
    final result = List<QueueEntry>.unmodifiable(picked);
    onNext?.call(result, depth);
    return result;
  }

  void done(String id) => _remove(_playing, (entry) => entry.id == id);
  void remove(String id) => _remove(_entries, (entry) => entry.id == id);

  void _remove(List<QueueEntry> list, bool Function(QueueEntry) matches) {
    final index = list.indexWhere(matches);
    if (index == -1) return;
    list.removeAt(index);
    _changed();
  }

  void clear() {
    if (_entries.isEmpty && _playing.isEmpty && _played.isEmpty) return;
    _entries.clear();
    _playing.clear();
    _played.clear();
    _changed();
  }

  void _changed() {
    _dirty = true;
    _schedule();
  }

  void _schedule() {
    if (_states.isClosed) return;
    _timer ??= Timer(publishInterval, () {
      _timer = null;
      final state = current;
      _states.add(state);
      _persist(state);
    });
  }

  void _persist(QueueState state) {
    if (!_dirty) return;
    _dirty = false;
    onPersist?.call(state);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    if (_dirty) _persist(current);
    await _states.close();
  }
}
