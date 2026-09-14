import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screens/about_page.dart';
import '../../services/landing_content_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// Who the church is — the `#about` section in src/pages/Home.tsx:394.
///
/// A summary, not the whole history: the complete account runs to about 1,800
/// words, so the full text lives on [AboutPage] and this links through to it,
/// exactly as the web links through to /about. `about` sits directly under the
/// hero because who the church is answers the first question a visitor
/// actually has, and the feature tour means nothing before it.
class AboutSection extends StatelessWidget {
  final LandingContent content;
  const AboutSection({super.key, required this.content});

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: homeSectionPadding,
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBadge(Icons.church_outlined, content.aboutBadge),
          const SizedBox(height: 14),
          SectionHeading(content.aboutTitle,
              description: content.aboutDescription),

          const SizedBox(height: 28),

          // ── Identity, Mission & Vision ──
          _Card(
            icon: Icons.church_outlined,
            title: content.whoWeAreTitle,
            body: content.whoWeAreDescription,
            isDark: isDark,
            footer: content.historyLinkLabel.isEmpty
                ? null
                : ElevatedButton.icon(
                    onPressed: () => _openHistory(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    label: Text(
                      content.historyLinkLabel,
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w900),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                  ),
          ),

          // The mission is a list of commitments, not a paragraph — rendered as
          // one when the content supplies several lines (Home.tsx:449).
          _MissionCard(
            title: content.aboutMissionTitle,
            lines: content.aboutMissionLines,
          ),

          _Card(
            icon: Icons.explore_outlined,
            title: content.visionTitle,
            body: content.visionDescription,
            isDark: isDark,
          ),

          // ── Statement of Faith ──
          if (content.beliefs.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionEyebrow(content.beliefsEyebrow),
            SectionHeading(content.beliefsTitle),
            const SizedBox(height: 18),
            ...content.beliefs.asMap().entries.map(
                  (e) => _Tile(e.value, isDark)
                      .animate()
                      .fadeIn(delay: (e.key * 70).ms)
                      .moveY(begin: 14),
                ),
          ],

          // ── Core Values ──
          if (content.values.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionEyebrow(content.valuesEyebrow),
            SectionHeading(content.valuesTitle),
            const SizedBox(height: 18),
            ...content.values.asMap().entries.map(
                  (e) => _Tile(e.value, isDark)
                      .animate()
                      .fadeIn(delay: (e.key * 70).ms)
                      .moveY(begin: 14),
                ),
          ],

          // The full-history CTA. The section above is a summary, so the way
          // through to the complete account has to be impossible to miss.
          if (content.historyLinkLabel.isNotEmpty) ...[
            const SizedBox(height: 28),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _openHistory(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(
                  content.historyLinkLabel,
                  style:
                      GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool isDark;
  final Widget? footer;

  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    required this.isDark,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: homeCardDecoration(isDark, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: homeHeadingColor(isDark),
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 15,
                height: 1.65,
                color: homeBodyColor(isDark),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    ).animate().fadeIn().moveY(begin: 20);
  }
}

/// The mission card — inverted colours, and a bullet list when the admin wrote
/// more than one line.
class _MissionCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _MissionCard({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.track_changes_outlined,
                size: 24, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (lines.length > 1)
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 9, right: 10),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
          else if (lines.isNotEmpty)
            Text(
              lines.first,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 15,
                height: 1.65,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    ).animate().fadeIn().moveY(begin: 20);
  }
}

/// One belief or value: icon tile, title, description.
class _Tile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _Tile(this.data, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: homeCardDecoration(isDark, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(homeIconFor(data['icon']),
                size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title']?.toString() ?? '',
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: homeHeadingColor(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data['description']?.toString() ?? '',
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14,
                    height: 1.6,
                    color: homeBodyColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
