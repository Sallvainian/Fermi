import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui' as ui;

class WebImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const WebImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // For non-web platforms, use regular Image.network
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width ?? 100,
            height: height ?? 100,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    }

    // For web, use HtmlElementView with an img element
    final String viewType = 'img-${imageUrl.hashCode}';
    
    // Register the view factory only once
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _getObjectFit(fit);
        
        img.onError.listen((event) {
          // Image failed to load
        });
        
        img.onLoad.listen((event) {
          // Image loaded successfully
        });
        
        return img;
      },
    );

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 200,
      child: HtmlElementView(viewType: viewType),
    );
  }

  String _getObjectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }
}