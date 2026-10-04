import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

class MetaTagHelper {
  /// Updates Open Graph meta tags dynamically on Flutter Web for rich chat link previews.
  static void updatePropertyMetaTags({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    if (!kIsWeb) return;

    try {
      // 1. Update Document Title
      web.document.title = 'Property+ | $title';

      // 2. Helper to set or create <meta> tags
      void setMeta(String propertyAttr, String propertyValue, String contentValue) {
        final query = 'meta[$propertyAttr="$propertyValue"]';
        var element = web.document.querySelector(query) as web.HTMLMetaElement?;
        if (element == null) {
          element = web.document.createElement('meta') as web.HTMLMetaElement;
          element.setAttribute(propertyAttr, propertyValue);
          web.document.head?.appendChild(element);
        }
        element.content = contentValue;
      }

      final fullTitle = 'Property+ | $title';
      setMeta('property', 'og:title', fullTitle);
      setMeta('name', 'twitter:title', fullTitle);

      setMeta('name', 'description', description);
      setMeta('property', 'og:description', description);
      setMeta('name', 'twitter:description', description);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        setMeta('property', 'og:image', imageUrl);
        setMeta('name', 'twitter:image', imageUrl);
      }
    } catch (_) {
      // Fail silently if DOM is unavailable
    }
  }
}
