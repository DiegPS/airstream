class LogSanitizer {
  LogSanitizer._();

  static final Set<String> _registeredSecrets = <String>{};
  static final List<RegExp> _patterns = <RegExp>[
    RegExp(r'(Bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    RegExp(
      r'((?:password|passwd|token|access_token|refresh_token|api[_-]?key|authorization)\s*[=:]\s*)([^\s,;&]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'([?&](?:password|token|access_token|refresh_token|api[_-]?key)=)([^&\s]+)',
      caseSensitive: false,
    ),
  ];

  static void registerSecret(String value) {
    final secret = value.trim();
    if (secret.length >= 4) _registeredSecrets.add(secret);
  }

  static void forgetSecret(String value) =>
      _registeredSecrets.remove(value.trim());

  static String sanitize(Object? value) {
    var result = value?.toString() ?? '';
    for (final secret in _registeredSecrets) {
      result = result.replaceAll(secret, '<redacted>');
    }
    for (final pattern in _patterns) {
      result = result.replaceAllMapped(pattern, (match) {
        final prefix = match.group(1) ?? '';
        return '$prefix<redacted>';
      });
    }
    return result;
  }
}
