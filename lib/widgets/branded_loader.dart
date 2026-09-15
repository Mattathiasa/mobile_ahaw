import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../i18n/translations.dart';

import '../theme/app_colors.dart';

/// A minimalist welcome screen built around the Mahibere Ahaw emblem — a port
/// of the web's src/components/BrandedLoader.tsx, which describes itself the
/// same way.
///
/// Deliberately *not* a spinner. The web uses a slow breathing aura behind the
/// seal so the hand-off to the page is seamless rather than a jolt from a
/// progress indicator to content; the same reasoning applies here.
enum BrandedLoaderVariant {
  /// The public welcome screen. Full-bleed, on the site's own palette.
  brand,

  /// Dashboard and route transitions — quiet and unobtrusive.
  app,

  /// A section still filling in while the rest of the screen is usable.
  inline,
}

class BrandedLoader extends StatelessWidget {
  final BrandedLoaderVariant variant;

  /// Replaces the default welcome / status line.
  final String? message;

  const BrandedLoader({
    super.key,
    this.variant = BrandedLoaderVariant.brand,
    this.message,
  });

  /// Convenience for the many call sites that just want the inline form.
  const BrandedLoader.inline({super.key, this.message})
      : variant = BrandedLoaderVariant.inline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case BrandedLoaderVariant.inline:
        return _Inline(label: message);
      case BrandedLoaderVariant.app:
        return _App(message: message, isDark: isDark);
      case BrandedLoaderVariant.brand:
        return _Brand(message: message, isDark: isDark);
    }
  }
}

/// The emblem disc: white ground, gold ring, logo. Shared by both big variants.
class _Emblem extends StatelessWidget {
  final double size;
  final bool isDark;
  const _Emblem({required this.size, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.divineGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.darkBackground.withValues(alpha: 0.1),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: const ClipOval(
        child: Image(
          image: AssetImage('assets/logo.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final String? message;
  final bool isDark;
  const _Brand({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The breathing aura. 4.5s, the same rhythm as the web.
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.divineGold.withValues(alpha: 0.25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.divineGold.withValues(alpha: 0.25),
                            blurRadius: 48,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 1,
                          end: 1.08,
                          duration: 4500.ms,
                          curve: Curves.easeInOut,
                        )
                        .fadeIn(begin: 0.3, duration: 4500.ms),
                    _Emblem(size: 132, isDark: isDark)
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scaleXY(
                          begin: 0.94,
                          end: 1,
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  Text(
                    'MAHIBERE AHAW',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.4,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message ?? 'እንኳን ደህና መጡ • Welcome',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: (isDark
                              ? AppColors.primaryLight
                              : AppColors.primary)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 800.ms)
                  .moveY(begin: 8, end: 0, duration: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _App extends StatelessWidget {
  final String? message;
  final bool isDark;
  const _App({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.divineGold.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.divineGold.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(begin: 0.35, duration: 2000.ms),
                  _Emblem(size: 48, isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              (message ?? kTranslations['en']!['admin.loading']!).toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inline extends StatelessWidget {
  final String? label;
  const _Inline({this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
