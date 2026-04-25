import 'package:flutter/material.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';

class CardRenderer extends StatelessWidget {
  final CardModel card;
  final SubjectModel? subject;
  final String languageCode;
  final Color fallbackColor;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool compactPreview;
  final double? textFontSize;
  final String? excludeText;
  final bool forceAudioIcon;
  final VoidCallback? onPlayAudio;

  const CardRenderer({
    super.key,
    required this.card,
    required this.subject,
    required this.languageCode,
    required this.fallbackColor,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.compactPreview = false,
    this.textFontSize,
    this.excludeText,
    this.forceAudioIcon = false,
    this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageCode.toLowerCase();

    if (forceAudioIcon) {
      return _buildAudioFallback();
    }

    final colorRenderer = _buildColorRenderer();
    if (colorRenderer != null) return colorRenderer;

    if (card.isCountingRenderer) {
      return CountingGrid(
        count: card.numericalAnswer,
        iconSize: textFontSize ?? 40,
      );
    }

    final specialRenderer = _buildSpecialRenderer(lang);
    if (specialRenderer != null) return specialRenderer;

    final imageUrl =
        card.primaryImageUrl(lang) ??
        card.primaryImageUrl('global') ??
        card.primaryImageUrl('en');
    
    final hasPriorityVisuals = imageUrl != null;

    if (imageUrl != null) {
      return AlioloImage(
        imageUrl: imageUrl,
        fit: fit,
        alignment: alignment,
        backgroundColor: fallbackColor.withValues(alpha: 0.05),
      );
    }

    final rawDisplayText = card.getDisplayText(lang).trim();
    if (rawDisplayText.isNotEmpty) {
      final isMatchingExclude = excludeText != null && rawDisplayText.toLowerCase() == excludeText!.toLowerCase();
      
      // If matches exclude and we have images, hide it.
      // If it's the only visual, show it anyway.
      if (!isMatchingExclude || !hasPriorityVisuals) {
        return Center(
          child: Text(
            rawDisplayText,
            style: TextStyle(
              fontSize: textFontSize ?? 48,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
    }

    return _buildFallback(lang);
  }

  Widget? _buildSpecialRenderer(String lang) {
    if (card.isAdditionEmojiRenderer) {
      return AdditionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
      );
    }

    if (card.isAdditionNumberRenderer) {
      return AdditionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
        useNumbers: true,
      );
    }

    if (card.isSubtractionEmojiRenderer) {
      return SubtractionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
      );
    }

    if (card.isSubtractionNumberRenderer) {
      return SubtractionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
        useNumbers: true,
      );
    }

    return null;
  }

  Widget? _buildColorRenderer() {
    if (!card.isColors) return null;
    final colorCode =
        card.displayText.trim().isNotEmpty
            ? card.displayText.trim()
            : (card.hexColor ?? '');
    if (colorCode.isEmpty) return null;

    final color = Color(int.parse(colorCode.replaceFirst('#', '0xFF')));
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: color),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildColorLabel(colorCode, color),
          ),
        ),
      ],
    );
  }

  Widget _buildColorLabel(String colorCode, Color color) {
    final isLight = ThemeData.estimateBrightnessForColor(color) ==
        Brightness.light;
    final labelBackground = isLight
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.24);
    final labelForeground = isLight
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black87.withValues(alpha: 0.9);

    return DecoratedBox(
      key: const Key('color-hex-label'),
      decoration: BoxDecoration(
        color: labelBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: labelForeground.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          colorCode,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: labelForeground,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFallback(String lang) {
    final audioUrl = card.getAudioUrl(lang);
    if (onPlayAudio != null || (audioUrl != null && audioUrl.isNotEmpty)) {
      return _buildAudioFallback();
    }
    return Container(
      color: fallbackColor.withValues(alpha: 0.1),
      child: Icon(Icons.image, size: 32, color: fallbackColor),
    );
  }

  Widget _buildAudioFallback() {
    return Container(
      color: fallbackColor.withValues(alpha: 0.05),
      child: Center(
        child: IconButton(
          icon: Icon(
            Icons.volume_up,
            size: textFontSize ?? 40,
            color: onPlayAudio != null ? fallbackColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
          ),
          onPressed: onPlayAudio,
        ),
      ),
    );
  }
}
