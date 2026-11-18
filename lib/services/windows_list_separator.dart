import 'dart:io';

/// The list separator Windows uses for this user (Control Panel > Region),
/// which is what Excel expects between CSV columns: a comma in Mexico or
/// the US, a semicolon in Spain and most of Europe.
Future<String> windowsListSeparator() async {
  if (!Platform.isWindows) return ',';
  try {
    final result = await Process.run('reg', [
      'query',
      r'HKCU\Control Panel\International',
      '/v',
      'sList',
    ]).timeout(const Duration(seconds: 3));
    if (result.exitCode != 0) return ',';
    return parseListSeparator(result.stdout.toString());
  } catch (_) {
    return ',';
  }
}

/// Reads the value from `reg query` output; anything unusual falls back to
/// a comma.
String parseListSeparator(String regOutput) {
  final match = RegExp(r'sList\s+REG_SZ\s+(\S)\s*$', multiLine: true)
      .firstMatch(regOutput);
  final value = match?[1];
  return const [',', ';', '|'].contains(value) ? value! : ',';
}
