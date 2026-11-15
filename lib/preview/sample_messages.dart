import 'package:airstream/models/chat_message.dart';

/// Prefix shared by every sample message, so they are never mistaken for chat.
const previewMessagePrefix = 'airstream-preview-';

/// Sample chat used to try styles before going live.
///
/// Covers each kind of message the chat can show: roles, a Super Chat, a
/// membership, a reply and a long message on every platform.
List<ChatMessage> sampleChatMessages(String languageCode) {
  final es = languageCode == 'es';
  final now = DateTime.now().toUtc();
  var index = 0;
  ChatMessage sample(
    Platform platform,
    String name,
    String text, {
    String? color,
    bool owner = false,
    bool moderator = false,
    bool member = false,
    bool vip = false,
    SuperChat? superChat,
    bool membershipEvent = false,
    ChatReplyContext? reply,
  }) {
    index++;
    return ChatMessage(
      platform: platform,
      id: '$previewMessagePrefix$index',
      author: ChatAuthor(name: name, channelId: '$previewMessagePrefix$name'),
      items: text.isEmpty ? const [] : [MessageItem.text(text)],
      isOwner: owner,
      isModerator: moderator,
      isMembership: member,
      isVip: vip,
      superChat: superChat,
      isMembershipEvent: membershipEvent,
      membershipEventKind:
          membershipEvent ? MembershipEventKind.subscription : null,
      reply: reply,
      timestamp: now.add(Duration(milliseconds: index)),
    );
  }

  return [
    sample(
      Platform.youtube,
      es ? 'TuCanal' : 'YourChannel',
      es ? '¡Bienvenidos al directo!' : 'Welcome to the stream!',
      owner: true,
    ),
    sample(
      Platform.twitch,
      'ModeradorAmable',
      es
          ? 'Recuerden respetar las reglas del chat'
          : 'Please follow the chat rules',
      color: '#1E90FF',
      moderator: true,
    ),
    sample(
      Platform.kick,
      'kick_viewer',
      es ? 'Saludos desde Kick' : 'Hello from Kick',
      color: '#53FC18',
    ),
    sample(
      Platform.youtube,
      'Donador',
      es ? '¡Gracias por el contenido!' : 'Thanks for the content!',
      superChat: const SuperChat(amount: r'$5.00', color: '#1DE9B6'),
    ),
    sample(Platform.youtube, 'NuevoMiembro', '',
        member: true, membershipEvent: true),
    sample(
      Platform.twitch,
      'FanDeSiempre',
      es ? 'Llevo un año viendo el canal' : 'Been watching for a year now',
      color: '#FF69B4',
      member: true,
    ),
    sample(
      Platform.twitch,
      'CompaVIP',
      es ? 'Buen juego' : 'Nice play',
      vip: true,
    ),
    sample(
      Platform.kick,
      'Respondon',
      es ? 'jajaja tal cual' : 'haha exactly',
      reply: ChatReplyContext(
        messageId: '${previewMessagePrefix}3',
        authorId: '${previewMessagePrefix}kick_viewer',
        authorName: 'kick_viewer',
        text: es ? 'Saludos desde Kick' : 'Hello from Kick',
      ),
    ),
    sample(
      Platform.youtube,
      'EspectadorConNombreLargo',
      es
          ? 'Este es un mensaje largo para ver cómo se ajusta el texto cuando '
              'ocupa varias líneas en la burbuja del chat.'
          : 'This is a long message to see how the text wraps when it takes '
              'several lines in a chat bubble.',
      color: '#FFA500',
    ),
  ];
}
