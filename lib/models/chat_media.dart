String normalizeChatImageUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      uri.scheme == 'http' &&
      (uri.host.endsWith('googleusercontent.com') ||
          uri.host.endsWith('ggpht.com') ||
          uri.host.endsWith('ytimg.com'))) {
    return uri.replace(scheme: 'https').toString();
  }
  return trimmed;
}
