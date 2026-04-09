import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AlioloImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useBorder;
  final Color? borderColor;
  final Color? backgroundColor;

  const AlioloImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.useBorder = false,
    this.borderColor,
    this.backgroundColor,
  });

  bool get isSvg => imageUrl.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (isSvg) {
      image = SvgPicture.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: (context) =>
            placeholder ?? const Center(child: CircularProgressIndicator()),
      );
    } else {
      image = Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? const Icon(Icons.error),
      );
    }

    if (useBorder || backgroundColor != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: useBorder
              ? Border.all(
                  color: borderColor ?? Colors.black.withValues(alpha: 0.1),
                  width: 1,
                )
              : null,
        ),
        child: image,
      );
    }

    return image;
  }
}
