import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/landing_content_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';

/// Renders the church "About" content (origin, mission, vision, beliefs,
/// values) plus the platform-features section — the mobile equivalent of the
/// web About + About Features pages. All text comes from the shared landing
/// content the web admin edits (siteConfig/landingPage), per language.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = Provider.of<LandingContentService>(context);
    final lang = Provider.of<LocalizationService>(context).language;
    final content = LandingContent(service.forLanguage(lang));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(content.aboutBadge,
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !service.loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _title(content.aboutTitle, isDark),
                if (content.aboutDescription.isNotEmpty)
                  _paragraph(content.aboutDescription, isDark),
                const SizedBox(height: 20),
                _section(content.whoWeAreTitle, content.whoWeAreDescription,
                    FontAwesomeIcons.seedling, isDark),
                _section(content.aboutMissionTitle,
                    content.aboutMissionDescription, FontAwesomeIcons.bullseye,
                    isDark),
                _section(content.visionTitle, content.visionDescription,
                    FontAwesomeIcons.eye, isDark),
                if (content.beliefs.isNotEmpty) ...[
                  _title(content.beliefsTitle, isDark),
                  ...content.beliefs.map((b) => _tile(b, isDark)),
                  const SizedBox(height: 12),
                ],
                if (content.values.isNotEmpty) ...[
                  _title(content.valuesTitle, isDark),
                  ...content.values.map((v) => _tile(v, isDark)),
                  const SizedBox(height: 12),
                ],
                if (content.featureItems.isNotEmpty) ...[
                  _title(content.featuresTitle, isDark),
                  ...content.featureItems.map((f) => _tile(f, isDark)),
                ],
              ],
            ),
    );
  }

  Widget _title(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
      );

  Widget _paragraph(String text, bool isDark) => Text(text,
      style: GoogleFonts.notoSansEthiopic(
          fontSize: 14,
          height: 1.7,
          color: isDark ? Colors.white70 : Colors.grey.shade700));

  Widget _section(String title, String body, IconData icon, bool isDark) {
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FaIcon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText)),
          ),
        ]),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(body,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  height: 1.7,
                  color: isDark ? Colors.white60 : Colors.grey.shade700)),
        ],
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> item, bool isDark) {
    final title = (item['title'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const FaIcon(FontAwesomeIcons.crosshairs,
              size: 12, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600)),
            ],
          ]),
        ),
      ]),
    ).animate().fadeIn();
  }
}
