import 'package:flutter/material.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';

class CardRenderer extends StatelessWidget {
  final CardModel card;
  final SubjectModel? subject;
  final String languageCode;
  final Color fallbackColor;
  final BoxFit fit;
  final double? textFontSize;

  const CardRenderer({
    super.key,
    required this.card,
    required this.subject,
    required this.languageCode,
    required this.fallbackColor,
    this.fit = BoxFit.contain,
    this.textFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final lang = languageCode.toLowerCase();

    final colorRenderer = _buildColorRenderer();
    if (colorRenderer != null) return colorRenderer;

    if (subject?.isAlphabet == true) {
      return _buildAlphabetRenderer(lang);
    }

    if (card.isCountingRenderer) {
      return CountingGrid(
        count: card.numericalAnswer,
        iconSize: textFontSize ?? 40,
      );
    }

    final imageUrl =
        card.primaryImageUrl(lang) ??
        card.primaryImageUrl('global') ??
        card.primaryImageUrl('en');
    if (imageUrl != null) {
      return AlioloImage(
        imageUrl: imageUrl,
        fit: fit,
        backgroundColor: fallbackColor.withValues(alpha: 0.05),
      );
    }

    final displayText = card.getDisplayText(lang);
    if (displayText.trim().isNotEmpty) {
      return Center(
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: textFontSize ?? 48,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final mathRenderer = _buildMathRenderer(lang);
    if (mathRenderer != null) return mathRenderer;

    return _buildFallback();
  }

  Widget? _buildMathRenderer(String lang) {
    if (!(card.isMathRenderer || card.isMath || subject?.isMath == true)) {
      return null;
    }

    if (subject?.usesEmojiSubtractionRenderer == true) {
      return SubtractionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
      );
    }

    if (subject?.usesNumberSubtractionRenderer == true) {
      return SubtractionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
        useNumbers: true,
      );
    }

    if (subject?.usesEmojiAdditionRenderer == true) {
      return AdditionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
      );
    }

    if (subject?.usesNumberAdditionRenderer == true) {
      return AdditionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: subject?.maxOperand ?? 20,
        iconSize: (textFontSize ?? 24).clamp(12, 64).toDouble(),
        useNumbers: true,
      );
    }

    if (card.mathQuestion != null && card.mathQuestion!.isNotEmpty) {
      return Center(
        child: Text(
          card.mathQuestion!,
          style: TextStyle(
            fontSize: textFontSize ?? 48,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: Text(
        card.getAnswer(lang).isNotEmpty
            ? card.getAnswer(lang)
            : card.getAnswer('global'),
        style: TextStyle(
          fontSize: textFontSize ?? 48,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget? _buildColorRenderer() {
    if (!(card.isColors || subject?.isColors == true)) return null;
    if (card.hexColor == null) return null;

    return SizedBox.expand(
      child: ColoredBox(
        color: Color(int.parse(card.hexColor!.replaceFirst('#', '0xFF'))),
      ),
    );
  }

  Widget _buildAlphabetRenderer(String lang) {
    return Center(
      child: Text(
        card.getAnswer(lang).isNotEmpty
            ? card.getAnswer(lang)
            : card.getAnswer('global'),
        style: TextStyle(
          fontSize: textFontSize ?? 64,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: fallbackColor.withValues(alpha: 0.1),
      child: Icon(Icons.image, size: 32, color: fallbackColor),
    );
  }
}
