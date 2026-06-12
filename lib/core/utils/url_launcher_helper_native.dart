import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchBrowserUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {
    // Fallback if launchUrl fails
  }

  // Fallback for Windows local environment
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
  } else {
    throw Exception('Could not launch $url');
  }
}
