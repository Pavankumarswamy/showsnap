import 'dart:html' as html;

Future<void> launchBrowserUrl(String url) async {
  html.window.open(url, '_blank');
}
