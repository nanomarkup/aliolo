import 'package:flutter/material.dart';

class AlioloLayoutTokens {
  static const double appBarOuterTopPadding = 16;
  static const double appBarContentHeight = 64;
  static const double appBarPreferredHeight = 80;
  static const double bodyTopGap = 92;
  static const double bodyHorizontalPadding = 16;
  static const double bodyBottomPadding = 32;
  static const double compactRowSpacing = 12;
  static const double compactTilePadding = 12;
  static const double compactTileBottomSpacing = 8;
  static const double compactTileTitleSize = 16;
  static const double compactTileMetaSize = 13;
  static const double appBarTitleSize = 20;
  static const double appBarSubtitleSize = 15;
  static const double compactControlRadius = 12;

  static const EdgeInsets pageBodyPadding = EdgeInsets.fromLTRB(
    bodyHorizontalPadding,
    bodyTopGap,
    bodyHorizontalPadding,
    bodyBottomPadding,
  );

  static const EdgeInsets compactTilePaddingAll = EdgeInsets.all(
    compactTilePadding,
  );

  static const EdgeInsets compactTileBottomPadding = EdgeInsets.only(
    bottom: compactTileBottomSpacing,
  );
}
