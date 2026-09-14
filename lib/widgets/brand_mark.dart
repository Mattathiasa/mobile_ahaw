import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The Mahibere Ahaw seal, framed so its detail survives — a port of the web's
/// src/components/BrandMark.tsx.
///
/// The logo is a dense circular seal: Amharic and English rim text, the cross,
/// the dove, the open Bible, the hands. None of it reads much below 48px, and
/// it has a light interior, so on a light page the seal's own black rim is the
/// only thing separating it from the background.
///
/// So every instance gets the same treatment: a white disc backing, a thin gold
/// ring picked from the cross in the artwork, and a soft halo behind it. That
/// holds up on both the light (#E7F0FA) and dark (#0D2440) backgrounds without
/// needing a per-theme variant.
enum BrandMarkSize { sm, md, lg, xl }

class BrandMark extends StatelessWidget {
  final BrandMarkSize size;

  /// Render "MAHIBERE AHAW" beside the seal.
  final bool showWordmark;

  /// The eyebrow under the wordmark. Null drops it.
  final String? tagline;

  const BrandMark({
    super.key,
    this.size = BrandMarkSize.md,
    this.showWordmark = false,
    this.tagline,
  });

  /// Box sizes are deliberately generous — see the note above about legibility.
  double get _box => switch (size) {
        BrandMarkSize.sm => 40,
        BrandMarkSize.md => 56,
        BrandMarkSize.lg => 64,
        BrandMarkSize.xl => 124,
      };

  double get _pad => switch (size) {
        BrandMarkSize.sm => 3,
        BrandMarkSize.md => 4,
        BrandMarkSize.lg => 4,
        BrandMarkSize.xl => 6,
      };

  double get _ring => size == BrandMarkSize.sm ? 1 : 2;

  double get _halo => switch (size) {
        BrandMarkSize.sm => 8,
        BrandMarkSize.md => 14,
        BrandMarkSize.lg => 14,
        BrandMarkSize.xl => 28,
      };

  double get _nameSize => switch (size) {
        BrandMarkSize.sm => 16,
        BrandMarkSize.md => 20,
        BrandMarkSize.lg => 24,
        BrandMarkSize.xl => 32,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seal = Container(
      width: _box,
      height: _box,
      padding: EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.divineGold.withValues(alpha: 0.85),
          width: _ring,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.divineGold.withValues(alpha: 0.28),
            blurRadius: _halo,
            spreadRadius: _halo / 4,
          ),
        ],
      ),
      child: const ClipOval(
        child: Image(image: AssetImage('assets/logo.png'), fit: BoxFit.cover),
      ),
    );

    if (!showWordmark) return seal;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        seal,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAHIBERE AHAW',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _nameSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              if (tagline != null)
                Text(
                  tagline!,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: _nameSize * 0.4,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
