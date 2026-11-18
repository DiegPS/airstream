abstract final class ChatFonts {
  static const defaultFamily = 'Segoe UI';

  static const windows = [
    defaultFamily,
    'Bahnschrift',
    'Arial',
    'Verdana',
    'Tahoma',
    'Trebuchet MS',
    'Georgia',
    'Cambria',
    'Consolas',
    'Comic Sans MS',
    'Impact',
    'Segoe Print',
  ];

  // Request the available subset for families with a smaller weight range.
  static const _googleWeights = {
    'Inter': '400;600;700;800',
    'Poppins': '400;600;700;800',
    'Montserrat': '400;600;700;800',
    'Nunito': '400;600;700;800',
    'Lexend': '400;600;700;800',
    'Rubik': '400;600;700;800',
    'Oswald': '400;600;700',
    'Bebas Neue': '400',
    'Fredoka': '400;600;700',
    'Press Start 2P': '400',
    'Comfortaa': '400;600;700',
    'Roboto': '400;600;700;800',
  };

  static Iterable<String> get google => _googleWeights.keys;

  static final _validFamily = RegExp(r'^[A-Za-z0-9 \-]{1,48}$');

  static String? validate(Object? value) {
    if (value is! String || _validFamily.stringMatch(value) != value) {
      return null;
    }
    final family = value.trim();
    return family.isEmpty ? null : family;
  }

  static String normalize(Object? value) => validate(value) ?? defaultFamily;

  static String? googleStylesheet(String family,
      {required bool installedOnly}) {
    final weights = installedOnly ? null : _googleWeights[family];
    if (weights == null) return null;
    final encodedFamily = Uri.encodeQueryComponent(family);
    return 'https://fonts.googleapis.com/css2?family=$encodedFamily:wght@$weights&display=swap';
  }
}
