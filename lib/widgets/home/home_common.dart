import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/localization_service.dart';

import '../../services/landing_content_service.dart';
import '../../theme/app_colors.dart';

/// Maps the Lucide icon names stored in Firestore to Material icons.
///
/// Covers every name in `ICON_MAP` at the top of the web's
/// src/pages/Home.tsx — a name the admin picks in the Landing Editor has to
/// resolve on both clients, and anything unrecognised falls through to the
/// same sparkle the web uses.
IconData homeIconFor(Object? name) {
  switch (name) {
    case 'Users':
      return Icons.people_outline;
    case 'FileText':
      return Icons.description_outlined;
    case 'BarChart3':
      return Icons.bar_chart;
    case 'Calendar':
      return Icons.calendar_today_outlined;
    case 'MapPin':
      return Icons.location_on_outlined;
    case 'Shield':
      return Icons.shield_outlined;
    case 'Heart':
      return Icons.favorite_outline;
    case 'Languages':
      return Icons.translate;
    case 'Bell':
      return Icons.notifications_outlined;
    case 'CheckCircle2':
      return Icons.check_circle_outline;
    case 'Mail':
      return Icons.mail_outline;
    case 'ArrowRight':
      return Icons.arrow_forward;
    case 'Sparkles':
      return Icons.auto_awesome_outlined;
    case 'Youtube':
      return Icons.play_circle_outline;
    case 'Send':
      return Icons.send_outlined;
    case 'Phone':
      return Icons.phone_outlined;
    case 'Clock':
      return Icons.schedule_outlined;
    case 'Globe':
      return Icons.public;
    case 'Church':
      return Icons.church_outlined;
    case 'MessageSquare':
      return Icons.chat_bubble_outline;
    case 'BookOpen':
      return Icons.menu_book_outlined;
    case 'Compass':
      return Icons.explore_outlined;
    case 'Award':
      return Icons.workspace_premium_outlined;
    case 'Target':
      return Icons.track_changes_outlined;
    case 'Scale':
      return Icons.balance_outlined;
    case 'Handshake':
      return Icons.handshake_outlined;
    default:
      return Icons.auto_awesome_outlined;
  }
}

/// Opens an external URL, telling the reader when it cannot be opened.
///
/// This used to return silently on failure, and that hid a real bug for a long
/// time: the Android manifest declared no `<queries>` entry for `https` or
/// `mailto`, so on Android 11+ `canLaunchUrl` answered false for every social
/// link, the website and every email address, and each one looked like a button
/// that simply did nothing. The manifest is fixed, but a link can still fail
/// legitimately — a device with no browser or no mail client — and saying so is
/// better than a dead tap.
///
/// Pass [context] wherever one is available so the failure can surface as a
/// SnackBar; without it the call still works and just logs.
Future<bool> openExternal(String url, {BuildContext? context}) async {
  final uri = Uri.tryParse(url);
  var opened = false;

  if (uri != null) {
    try {
      if (await canLaunchUrl(uri)) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) print('[openExternal] $url failed: $e');
    }
  }

  if (!opened && context != null && context.mounted) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.t('common.linkCannotOpen'))),
    );
  }
  return opened;
}

/// Follows any link configured in the Landing Editor — hero buttons, feature
/// cards, footer columns. Mirrors `followLink` in src/pages/Home.tsx:188.
///
/// [onAnchor] receives the section id for `#foo` links so the landing page can
/// scroll to it; pass null where there is nothing to scroll.
Future<void> followLandingLink(
  BuildContext context,
  String? url, {
  String fallback = '',
  void Function(String id)? onAnchor,
}) async {
  final action = resolveLink(url, fallback: fallback);
  switch (action.kind) {
    case LinkKind.external:
      await openExternal(action.value, context: context);
    case LinkKind.anchor:
      onAnchor?.call(action.value);
    case LinkKind.route:
      // Only the routes this app actually declares; anything else (a web-only
      // path like /features) would throw on an unknown route, so it is dropped
      // rather than crashing the landing page.
      const known = {'/', '/login', '/signup', '/dashboard'};
      final path = action.value.split('#').first;
      if (known.contains(path) && context.mounted) {
        Navigator.pushNamed(context, path);
      }
    case LinkKind.none:
      break;
  }
}

/// The small uppercase pill above a section heading.
class SectionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const SectionBadge(this.icon, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's title and optional lead paragraph.
class SectionHeading extends StatelessWidget {
  final String title;
  final String description;
  const SectionHeading(this.title, {super.key, this.description = ''});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.trim().isNotEmpty)
          Text(
            title,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 15,
              height: 1.6,
              color: AppColors.primary.withValues(alpha: isDark ? 0.9 : 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

/// The small uppercase eyebrow the About section puts above its sub-headings.
class SectionEyebrow extends StatelessWidget {
  final String text;
  const SectionEyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.notoSansEthiopic(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// The shared surface every card on the landing page sits on.
BoxDecoration homeCardDecoration(bool isDark, {double radius = 20}) =>
    BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
    );

/// Body text colour that reads on both backgrounds.
Color homeBodyColor(bool isDark) =>
    isDark ? Colors.white70 : AppColors.lightText.withValues(alpha: 0.7);

/// Heading text colour that reads on both backgrounds.
Color homeHeadingColor(bool isDark) =>
    isDark ? Colors.white : AppColors.lightText;

/// Standard vertical rhythm between landing sections.
const EdgeInsets homeSectionPadding =
    EdgeInsets.symmetric(vertical: 48, horizontal: 24);

/// A published date rendered in the reader's language.
///
/// The web went out of its way to stop using the *browser's* locale here — an
/// Amharic reader on an en-US phone was seeing `3/14/2025` in the middle of an
/// otherwise Amharic page (see the note atop src/lib/formatters.ts). Same
/// intent: format in the chosen language, falling back to the default only
/// when `intl` has no data for it.
///
/// Gregorian, localised — matching the web. Ethiopian calendar rendering is a
/// separate question there too.
String formatLandingDate(Object? value, String language) {
  final millis = switch (value) {
    Timestamp t => t.millisecondsSinceEpoch,
    DateTime d => d.millisecondsSinceEpoch,
    int i => i,
    String s => DateTime.tryParse(s)?.millisecondsSinceEpoch,
    _ => null,
  };
  if (millis == null) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final format = DateFormat.yMMMd(
      DateFormat.localeExists(language) ? language : null);
  return format.format(date);
}
