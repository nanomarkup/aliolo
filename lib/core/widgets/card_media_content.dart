import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';

class CardMediaContent extends StatelessWidget {
  final CardModel card;
  final SubjectModel subject;
  final String languageCode;
  final Color headerColor;
  final bool isMobile;
  final VideoPlayerController? videoController;
  final bool hasVideo;
  final List<String> images;
  final int mediaIndex;
  final ValueChanged<int>? onMediaIndexChanged;
  final VoidCallback? onPlayAudio;
  final bool hasAudio;
  final String? headerText;
  final String? centerTextOverride;
  final bool hideAudioIcon;

  const CardMediaContent({
    super.key,
    required this.card,
    required this.subject,
    required this.languageCode,
    required this.headerColor,
    required this.isMobile,
    this.videoController,
    this.hasVideo = false,
    this.images = const [],
    this.mediaIndex = 0,
    this.onMediaIndexChanged,
    this.onPlayAudio,
    this.hasAudio = false,
    this.headerText,
    this.centerTextOverride,
    this.hideAudioIcon = false,
  });

  int get slideCount => (hasVideo ? 1 : 0) + images.length;
  bool get showVideoNow => hasVideo && mediaIndex == 0;
  String? get currentImage => showVideoNow ? null : (images.isNotEmpty ? images[mediaIndex - (hasVideo ? 1 : 0)] : null);

  Widget _buildContent(BuildContext context, String deduplicatedText, double textFontSize, bool showCenterAudioIcon) {
    final lang = languageCode.toLowerCase();

    if (showVideoNow && videoController != null) {
      if (!videoController!.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: AspectRatio(
          aspectRatio: videoController!.value.aspectRatio,
          child: VideoPlayer(videoController!),
        ),
      );
    } else if (card.isCountingRenderer) {
      return CountingGrid(
        count: card.numericalAnswer,
        iconSize: isMobile ? 40 : 60,
      );
    } else if (card.isColors || card.isSpecialRenderer) {
      return CardRenderer(
        card: card,
        subject: subject,
        languageCode: lang,
        fallbackColor: headerColor,
        fit: BoxFit.contain,
        textFontSize: textFontSize,
      );
    } else if (currentImage != null) {
      return AlioloImage(
        imageUrl: currentImage!,
        fit: BoxFit.contain,
        backgroundColor: headerColor.withValues(alpha: 0.05),
      );
    } else if (deduplicatedText.isNotEmpty) {
      return Center(
        child: Text(
          deduplicatedText,
          style: TextStyle(
            fontSize: textFontSize,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else if (showCenterAudioIcon) {
      return Container(
        color: headerColor.withValues(alpha: 0.05),
        child: Center(
          child: IconButton(
            icon: Icon(
              Icons.volume_up,
              size: 120,
              color: onPlayAudio != null ? headerColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
            ),
            onPressed: onPlayAudio,
          ),
        ),
      );
    } else {
      return const Icon(
        Icons.image_not_supported,
        size: 100,
        color: Colors.grey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = languageCode.toLowerCase();
    
    final hasPriorityVisuals = card.isSpecialRenderer || 
                               card.isCountingRenderer || 
                               card.isColors || 
                               hasVideo || 
                               images.isNotEmpty;

    final rawDisplayText = card.getDisplayText(lang).trim();
    
    // Logic for final text to display in the content area:
    // 1. Prefer centerTextOverride if provided (used by LearnPage for audio-only cards)
    // 2. Otherwise, if it matches the header text AND we have other visual content, hide it.
    // 3. If it's the ONLY visual content, show it even if it matches the header.
    final String finalDisplayText;
    if (centerTextOverride != null) {
      finalDisplayText = centerTextOverride!;
    } else {
      final isMatchingHeader = headerText != null && rawDisplayText.toLowerCase() == headerText!.toLowerCase();
      if (isMatchingHeader && hasPriorityVisuals) {
        finalDisplayText = '';
      } else {
        finalDisplayText = rawDisplayText;
      }
    }
        
    final hasVisual = hasPriorityVisuals || finalDisplayText.isNotEmpty;
                      
    final showCenterAudioIcon = !hasVisual && !hideAudioIcon;
    final showOverlayAudioIcon = hasVisual && !hideAudioIcon;
    final textFontSize = isMobile ? 80.0 : 120.0;

    Widget content = _buildContent(context, finalDisplayText, textFontSize, showCenterAudioIcon);

    final bool hasSlider = slideCount > 1 && !card.isSpecialRenderer && !card.isCountingRenderer && !card.isColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Card(
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: headerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Container(
            color: headerColor.withValues(alpha: 0.05),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: isMobile ? 300 : 0,
                maxHeight: isMobile && !hasVisual ? 450 : double.infinity,
              ),
              child: Stack(
                fit: isMobile ? StackFit.loose : StackFit.expand,
                alignment: Alignment.center,
                children: [
                  content,
                  if (hasSlider) ...[
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        onPressed: onMediaIndexChanged != null 
                          ? () => onMediaIndexChanged!((mediaIndex - 1 + slideCount) % slideCount)
                          : null,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        onPressed: onMediaIndexChanged != null 
                          ? () => onMediaIndexChanged!((mediaIndex + 1) % slideCount)
                          : null,
                      ),
                    ),
                  ],
                  if (showOverlayAudioIcon)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.volume_up,
                            color: onPlayAudio != null ? headerColor : Colors.grey,
                            size: 28,
                          ),
                          onPressed: onPlayAudio,
                          tooltip: 'Play audio',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
