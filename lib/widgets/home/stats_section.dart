import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/landing_content_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// The four headline numbers, from `content.stats`. Mirrors the `#stats`
/// section in src/pages/Home.tsx:365.
///
/// No hardcoded fallback rows: the web renders nothing when the admin has
/// configured no stats, and inventing Amharic placeholders here made the mobile
/// app show numbers the church never published.
class StatsSection extends StatelessWidget {
  final LandingContent content;
  const StatsSection({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final stats = content.stats;
    if (stats.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: homeCardDecoration(isDark),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(homeIconFor(stat['icon']),
                    color: AppColors.primary, size: 24),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    stat['value']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: homeHeadingColor(isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (stat['label']?.toString() ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (index * 100).ms).scale();
        },
      ),
    );
  }
}
