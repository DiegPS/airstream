import 'chat_message.dart';
import 'chat_provider_event.dart';

String? messageAlertKind(ChatMessage message) => message.superChat != null
    ? (message.platform == Platform.twitch ? 'bits' : 'superchat')
    : message.isMembershipEvent
        ? 'membership'
        : null;

String? providerAlertKind(ChatProviderEvent event) =>
    switch ((event.platform, event.kind)) {
      (Platform.twitch, ChatProviderEventKind.raid) => 'raid',
      (Platform.kick, ChatProviderEventKind.host) => 'host',
      (Platform.kick, ChatProviderEventKind.support) => 'kicks',
      _ => null,
    };

String? supportAlertType(
  String kind,
  Platform platform,
  MembershipEventKind? membershipKind,
) =>
    switch (kind) {
      'superchat' || 'bits' || 'kicks' => kind,
      'raid' || 'host' => 'raid',
      'membership' when membershipKind == MembershipEventKind.gift => 'gift',
      'membership' when platform == Platform.youtube => 'membership',
      'membership'
          when membershipKind == MembershipEventKind.subscription ||
              membershipKind == MembershipEventKind.resubscription =>
        'subscription',
      _ => null,
    };
