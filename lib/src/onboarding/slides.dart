import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aliolo/data/services/translation_service.dart';

class OnboardingSlide extends StatelessWidget {
  final Widget visual;
  final String title;
  final String description;
  final Widget? extra;
  final bool useFixedHeader;
  final bool invertContent;

  const OnboardingSlide({
    super.key,
    required this.visual,
    required this.title,
    required this.description,
    this.extra,
    this.useFixedHeader = true,
    this.invertContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    final titleFontSize = isDesktop ? 32.0 : 22.0;
    final descFontSize = isDesktop ? 18.0 : 13.0;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Stack(
          children: [
            // 1. Scrollable Content
            Positioned.fill(
              bottom: 180, // Ends before the footer
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Top spacing - reduced
                            SizedBox(height: useFixedHeader ? 120 : 40),
                            
                            if (!useFixedHeader && !invertContent) ...[
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1D4289),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: descFontSize,
                                  height: 1.3,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            visual,

                            if (!useFixedHeader && invertContent) ...[
                              const SizedBox(height: 24),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1D4289),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: descFontSize,
                                  height: 1.3,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],

                            if (extra != null) ...[
                              const SizedBox(height: 24),
                              extra!,
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            if (useFixedHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor,
                        bgColor,
                        bgColor.withValues(alpha: 0.9),
                        bgColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.6, 0.8, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D4289),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: descFontSize,
                          height: 1.3,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withValues(alpha: 0.0),
                      bgColor,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
