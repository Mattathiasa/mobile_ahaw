import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/cloudinary_service.dart';
import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// The feature cards — the `#services` section in src/pages/Home.tsx:566.
///
/// Each card is a photo, an icon tile, a title, a description and its own
/// "learn more" link. Previously these were plain rows that all went to /login
/// regardless of what the admin configured; the destination now comes from the
/// card itself via [featureLinkTarget].
class FeaturesSection extends StatelessWidget {
  final LandingContent content;
  final void Function(String id)? onAnchor;

  const FeaturesSection({super.key, required this.content, this.onAnchor});

  @override
  Widget build(BuildContext context) {
    final items = content.featureItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);

    return Padding(
      padding: homeSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(content.featuresTitle,
              description: content.featuresDescription),
          const SizedBox(height: 28),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            final photo = (f['imageUrl'] as String?)?.trim() ?? '';
            final label = (f['learnMoreLabel'] as String?)?.trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: homeCardDecoration(isDark, radius: 22),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => followLandingLink(
                    context,
                    featureLinkTarget(f),
                    onAnchor: onAnchor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photo.isNotEmpty)
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                CloudinaryService.optimized(photo, width: 800),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.lightText
                                          .withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(homeIconFor(f['icon']),
                                    size: 22, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (photo.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(homeIconFor(f['icon']),
                                    size: 24, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              f['title']?.toString() ?? '',
                              style: GoogleFonts.notoSansEthiopic(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: homeHeadingColor(isDark),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              f['description']?.toString() ?? '',
                              style: GoogleFonts.notoSansEthiopic(
                                fontSize: 14,
                                height: 1.6,
                                color: homeBodyColor(isDark),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label != null && label.isNotEmpty
                                      ? label
                                      : loc.t('common.learnMore'),
                                  style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward,
                                    size: 16, color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (i * 80).ms).moveY(begin: 20);
          }),
        ],
      ),
    );
  }
}
