import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// How to reach the head office — the `#contact` section in
/// src/pages/Home.tsx:678.
///
/// Distinct from the footer, which only carries the small social icon row.
/// This is the block visitors come looking for: the address, the numbers, the
/// addresses and the office hours, all live-editable from the Landing Editor.
class ContactSection extends StatelessWidget {
  final LandingContent content;
  const ContactSection({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);

    final socials = <({FaIconData icon, Color color, String url, String title})>[
      if (content.contactYoutube.isNotEmpty)
        (
          icon: FontAwesomeIcons.youtube,
          color: const Color(0xFFFF0000),
          url: content.contactYoutube,
          title: 'YouTube'
        ),
      if (content.contactTelegram.isNotEmpty)
        (
          icon: FontAwesomeIcons.telegram,
          color: const Color(0xFF229ED9),
          url: content.contactTelegram,
          title: 'Telegram'
        ),
      if (content.contactFacebook.isNotEmpty)
        (
          icon: FontAwesomeIcons.facebook,
          color: const Color(0xFF1877F2),
          url: content.contactFacebook,
          title: 'Facebook'
        ),
      if (content.contactTiktok.isNotEmpty)
        (
          icon: FontAwesomeIcons.tiktok,
          color: AppColors.lightText,
          url: content.contactTiktok,
          title: 'TikTok'
        ),
      // Always present — see LandingContent.websiteUrl.
      (
        icon: FontAwesomeIcons.globe,
        color: AppColors.primary,
        url: content.websiteUrl,
        title: loc.t('common.website')
      ),
    ];

    return Padding(
      padding: homeSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBadge(Icons.phone_outlined, content.contactBadge),
          const SizedBox(height: 14),
          SectionHeading(content.contactTitle,
              description: content.contactDescription),
          const SizedBox(height: 28),

          // ── Address ──
          if (content.address.isNotEmpty)
            _ContactCard(
              icon: Icons.location_on_outlined,
              label: content.addressLabel,
              isDark: isDark,
              children: [
                Text(
                  content.address,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 15, height: 1.6, color: homeBodyColor(isDark)),
                ),
                if (content.mapUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _LinkRow(
                    label: loc.t('common.openInMaps'),
                    trailing: Icons.open_in_new,
                    onTap: () => openExternal(content.mapUrl, context: context),
                  ),
                ],
              ],
            ),

          // ── Phones ──
          if (content.phones.isNotEmpty)
            _ContactCard(
              icon: Icons.phone_outlined,
              label: content.phoneLabel,
              isDark: isDark,
              children: content.phones
                  .map((p) => _LinkRow(
                        label: p,
                        onTap: () =>
                            openExternal('tel:${p.replaceAll(RegExp(r'\s+'), '')}',
                            context: context),
                      ))
                  .toList(),
            ),

          // ── Emails ──
          if (content.emails.isNotEmpty)
            _ContactCard(
              icon: Icons.mail_outline,
              label: content.emailLabel,
              isDark: isDark,
              children: content.emails
                  .map((e) => _LinkRow(
                        label: e,
                        onTap: () => openExternal('mailto:$e'),
                      ))
                  .toList(),
            ),

          // ── Hours + socials ──
          if (content.hours.isNotEmpty || socials.isNotEmpty)
            _ContactCard(
              icon: Icons.schedule_outlined,
              label: content.hoursLabel,
              isDark: isDark,
              children: [
                if (content.hours.isNotEmpty)
                  Text(
                    content.hours,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 15,
                        height: 1.6,
                        color: homeBodyColor(isDark)),
                  ),
                if (socials.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    content.socialsLabel.toUpperCase(),
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: socials
                        .map((s) => Tooltip(
                              message: s.title,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => openExternal(s.url, context: context),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: s.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: FaIcon(s.icon,
                                      size: 18, color: s.color),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final List<Widget> children;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: homeCardDecoration(isDark, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ).animate().fadeIn().moveY(begin: 20);
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Icon(trailing, size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
