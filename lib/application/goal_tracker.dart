import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';

class GoalTracker {
  final _seen = <String>{};
  bool _repeat(String id) {
    if (!_seen.add(id)) return true;
    if (_seen.length > 2000) _seen.remove(_seen.first);
    return false;
  }

  Map<String, int> message(ChatMessage message) {
    if (_repeat('message:${message.dedupeKey}')) return const {};
    final result = <String, int>{};
    if (message.membershipEventKind != null ||
        (message.platform == Platform.youtube && message.isMembershipEvent)) {
      result['subs'] = message.membershipEventKind == MembershipEventKind.gift
          ? (message.membershipGiftCount ?? 1).clamp(0, 10000000)
          : 1;
    }
    if (message.platform == Platform.twitch && message.superChat != null) {
      final match =
          RegExp(r'^(\d+) Bits$').firstMatch(message.superChat!.amount);
      if (match != null) result['bits'] = int.tryParse(match[1]!) ?? 0;
    }
    return result;
  }

  Map<String, int> event(ChatProviderEvent event) {
    if (_repeat('event:${event.platform.name}:${event.id}')) return const {};
    return event.platform == Platform.kick &&
            event.kind == ChatProviderEventKind.support
        ? {'kicks': (event.count ?? 0).clamp(0, 10000000)}
        : const {};
  }
}
