const alertModerationScript = r'''
function matchesAlertModeration(alert, event) {
  if (!alert || alert.platform !== event.platform ||
      (alert.youtubeStreamOrientation ?? null) !== (event.youtubeStreamOrientation ?? null)) {
    return false;
  }
  if (event.scope === 'platform') return true;
  if (event.scope === 'message') return !!event.messageId && alert.id === event.messageId;
  return event.scope === 'author' &&
    ((event.authorChannelId && alert.authorChannelId === event.authorChannelId) ||
     (event.authorName && String(alert.author || '').toLowerCase() === event.authorName.toLowerCase()));
}

function alertBlockMatcher({users, words}) {
  // Use the same identity and whole-phrase normalization as ChatFilter.
  const blockedUsers = new Set(users);
  const phrases = words.map(word => ' ' + word + ' ');
  const userKey = value => String(value || '').trim().toLowerCase()
    .replace(/^@+/, '').replace(/\s+/g, '');
  return {
    blocksAuthor: alert => blockedUsers.has(userKey(alert.author)) ||
      blockedUsers.has(userKey(alert.authorChannelId)),
    blocksText: alert => {
      const text = ' ' + String(alert.message || '').toLowerCase()
        .replace(/[^\p{L}\p{M}\p{N}]+/gu, ' ').trim() + ' ';
      return phrases.some(phrase => text.includes(phrase));
    },
  };
}
''';
