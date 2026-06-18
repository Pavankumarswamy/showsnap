import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';

final Set<String> _registeredViews = {};

Widget buildWebVideoPlayer(String videoId) {
  final viewId = 'youtube-web-$videoId';
  
  if (!_registeredViews.contains(viewId)) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=0&controls=1&rel=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    _registeredViews.add(viewId);
  }

  return HtmlElementView(viewType: viewId);
}
