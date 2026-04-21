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
    final colorCode = card.hexColorFor(languageCode) ?? card.hexColor;
    if (colorCode == null) return null;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Color(int.parse(colorCode.replaceFirst('#', '0xFF'))),
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
