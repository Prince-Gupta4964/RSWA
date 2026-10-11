import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerYouTubeViewFactory(String viewType, String videoId) {
  try {
    final origin = Uri.base.origin;
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final web.HTMLIFrameElement iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
        iframe.src = 'https://www.youtube.com/embed/$videoId?autoplay=1&origin=$origin';
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
        return iframe;
      },
    );
  } catch (_) {}
}
