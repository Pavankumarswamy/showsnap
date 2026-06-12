import 'dart:io';

Future<void> launchBrowserUrl(String url) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
  }
}
