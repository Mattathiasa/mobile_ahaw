import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/landing_content_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// Ministerial support and the bank accounts — the `#support` section in
/// src/pages/Home.tsx:624.
///
/// `support.badge` and `support.title` are separate fields on the web; the
/// mobile app used to render the title inside the badge pill and never show the
/// heading at all.
class SupportSection extends StatelessWidget {
  final LandingContent content;
  const SupportSection({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: homeSectionPadding,
      color: AppColors.primary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBadge(Icons.favorite_outline, content.supportBadge),
          const SizedBox(height: 14),
          SectionHeading(content.supportTitle,
              description: content.supportDescription),

          // The mission restated beside the giving details.
          if (content.missionTitle.isNotEmpty ||
              content.missionStatement.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, color: Colors.white54, size: 28),
                  const SizedBox(height: 12),
                  if (content.missionTitle.isNotEmpty)
                    Text(
                      content.missionTitle.toUpperCase(),
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  if (content.missionStatement.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '“${content.missionStatement}”',
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 16,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (content.banks.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...content.banks.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: homeCardDecoration(isDark, radius: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          e.value['name']?.toString() ?? '',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SelectableText(
                        e.value['account']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: homeHeadingColor(isDark),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (e.key * 60).ms)),
          ],
        ],
      ),
    );
  }
}
