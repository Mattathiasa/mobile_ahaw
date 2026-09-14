import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/cloudinary_service.dart';
import '../../services/landing_content_service.dart';
import '../../theme/app_colors.dart';
import '../brand_mark.dart';
import 'home_common.dart';

/// The landing hero — the mobile counterpart of the `#home` section in
/// src/pages/Home.tsx:299.
///
/// The seal leads the page, as it does on the web: it carries the church's
/// identity — the rim text, the cross, the dove, the open Bible — none of which
/// is legible at nav size, so this is the one place it is shown large enough to
/// be read. The web pairs it with an interactive three.js cross; here the seal
/// itself gets a slow float, which reads as alive without shipping a 3D engine
/// to a low-end Android phone.
///
/// Only `ctaSecondary` is rendered, matching the web — the hero has one button
/// there, and it goes to the About section.
class HeroSection extends StatelessWidget {
  final LandingContent content;
  final void Function(String id)? onAnchor;

  const HeroSection({super.key, required this.content, this.onAnchor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 150, 24, 64),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          const BrandMark(size: BrandMarkSize.xl)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -6, end: 6, duration: 3200.ms, curve: Curves.easeInOut)
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.9, 0.9)),

          const SizedBox(height: 28),

          SectionBadge(Icons.auto_awesome_outlined, content.heroBadge)
              .animate()
              .fadeIn()
              .moveY(begin: -20),

          const SizedBox(height: 28),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                height: 1.15,
                color: homeHeadingColor(isDark),
              ),
              children: [
                TextSpan(text: content.heroTitle),
                if (content.heroTitleHighlight.isNotEmpty)
                  TextSpan(
                    text: '\n${content.heroTitleHighlight}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).moveY(begin: 20),

          const SizedBox(height: 20),

          Text(
            content.heroDescription,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 16,
              height: 1.6,
              color: homeBodyColor(isDark),
            ),
          ).animate().fadeIn(delay: 400.ms).moveY(begin: 20),

          if (content.heroImageUrl.isNotEmpty) ...[
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                CloudinaryService.optimized(content.heroImageUrl, width: 1200),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.96, 0.96)),
          ],

          if (content.ctaSecondary.trim().isNotEmpty) ...[
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => followLandingLink(
                  context,
                  content.ctaSecondaryUrl,
                  fallback: '#about',
                  onAnchor: onAnchor,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  content.ctaSecondary,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ],
      ),
    );
  }
}
