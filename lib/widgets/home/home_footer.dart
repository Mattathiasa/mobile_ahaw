import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../brand_mark.dart';
import 'home_common.dart';

/// The landing footer — src/pages/Home.tsx:795.
///
/// Two link columns whose labels and destinations come from the Landing
/// Editor and the legal row. A column row with
/// no URL renders as plain text rather than as a link that does nothing: all
/// eight used to be `href="#"` on the web, and the mobile app did not render
/// them at all.
class HomeFooter extends StatelessWidget {
  final LandingContent content;
  final void Function(String id)? onAnchor;

  const HomeFooter({super.key, required this.content, this.onAnchor});


  @override
  Widget build(BuildContext context) {
    final c = content;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);

    final socials = <({FaIconData icon, Color color, String url, String title})>[
      if (c.footerYoutube.isNotEmpty)
        (
          icon: FontAwesomeIcons.youtube,
          color: const Color(0xFFFF0000),
          url: c.footerYoutube,
          title: 'YouTube'
        ),
      if (c.footerTelegram.isNotEmpty)
        (
          icon: FontAwesomeIcons.telegram,
          color: const Color(0xFF229ED9),
          url: c.footerTelegram,
          title: 'Telegram'
        ),
      if (c.footerFacebook.isNotEmpty)
        (
          icon: FontAwesomeIcons.facebook,
          color: const Color(0xFF1877F2),
          url: c.footerFacebook,
          title: 'Facebook'
        ),
      (
        icon: FontAwesomeIcons.globe,
        color: AppColors.primary,
        url: c.websiteUrl,
        title: loc.t('common.website')
      ),
      if (c.footerEmail.isNotEmpty)
        (
          icon: FontAwesomeIcons.envelope,
          color: AppColors.primary,
          url: 'mailto:${c.footerEmail}',
          title: loc.t('common.emailAction')
        ),
      if (c.footerPhone.isNotEmpty)
        (
          icon: FontAwesomeIcons.phone,
          color: AppColors.primary,
          url: 'tel:${c.footerPhone.replaceAll(RegExp(r'\s+'), '')}',
          title: loc.t('common.callAction')
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.9)
            : Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: BrandMarkSize.lg, showWordmark: true),

          if (c.footerDescription.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              c.footerDescription,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                height: 1.7,
                color: homeBodyColor(isDark),
              ),
            ),
          ],

          if (socials.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: socials
                  .map((s) => Tooltip(
                        message: s.title,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => openExternal(s.url, context: context),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: FaIcon(s.icon, size: 18, color: s.color),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 36),

          _LinkColumn(
            heading: c.platformHeading,
            headingColor: AppColors.primary,
            links: c.platformLinks,
            onAnchor: onAnchor,
          ),
          _LinkColumn(
            heading: c.supportHeading,
            headingColor: AppColors.primaryLight,
            links: c.supportLinks,
            onAnchor: onAnchor,
          ),

          const SizedBox(height: 32),
          Divider(color: AppColors.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 16),

          Text(
            c.footerCopyright,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 11,
              letterSpacing: 1.5,
              color: homeBodyColor(isDark).withValues(alpha: 0.6),
            ),
          ),

          if (c.privacyUrl.isNotEmpty || c.termsUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              children: [
                if (c.privacyUrl.isNotEmpty)
                  _LegalLink(c.privacyLabel, c.privacyUrl, onAnchor),
                if (c.termsUrl.isNotEmpty)
                  _LegalLink(c.termsLabel, c.termsUrl, onAnchor),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the footer's two link columns.
class _LinkColumn extends StatelessWidget {
  final String heading;
  final Color headingColor;
  final List<LandingLink> links;
  final void Function(String id)? onAnchor;

  const _LinkColumn({
    required this.heading,
    required this.headingColor,
    required this.links,
    this.onAnchor,
  });

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 14),
          ...links.map((link) {
            final style = GoogleFonts.notoSansEthiopic(
              fontSize: 14,
              color: link.url.isEmpty
                  ? homeBodyColor(isDark).withValues(alpha: 0.6)
                  : AppColors.primary,
              fontWeight: link.url.isEmpty ? FontWeight.normal : FontWeight.w600,
            );
            // A row with a URL is a button; a row without one is plain text.
            if (link.url.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(link.label, style: style),
              );
            }
            return InkWell(
              onTap: () => followLandingLink(context, link.url,
                  onAnchor: onAnchor),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(link.label, style: style),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String url;
  final void Function(String id)? onAnchor;
  const _LegalLink(this.label, this.url, this.onAnchor);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => followLandingLink(context, url, onAnchor: onAnchor),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
