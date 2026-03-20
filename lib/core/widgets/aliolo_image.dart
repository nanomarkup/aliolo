import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AlioloImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AlioloImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  bool get isSvg => imageUrl.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    if (isSvg) {
      return SvgPicture.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: (context) => placeholder ?? const Center(child: CircularProgressIndicator()),
      );
    } else {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => errorWidget ?? const Icon(Icons.error),
      );
    }
  }
}
