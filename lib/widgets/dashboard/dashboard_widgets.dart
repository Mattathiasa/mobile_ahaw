import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';

/// Shared content primitives for the authenticated screens.
///
/// Each of these replaces a cluster of near-identical private builders: there
/// were eleven separate empty states, four section headers and a dozen card
/// builders across the dashboard screens, all drawing the same thing slightly
/// differently. Beyond the duplication, every one of them hardcoded English —
/// funnelling them through here is what makes localizing 26 screens tractable.

/// A titled block heading, optionally with a trailing action.
///
/// Replaces `_buildSectionHeader` / `_buildSectionHeaderWithViewAll` /
/// `_buildSection` / `_sectionTitle`.
class SectionHeader extends StatelessWidget {
  /// Dotted i18n key, e.g. `pages.recentAnnouncements`.
  final String titleKey;

  /// Literal title, for names that come from data rather than the catalog.
  final String? title;

  final IconData? icon;

  /// Trailing affordance — typically a "view all" button.
  final Widget? action;

  const SectionHeader({
    super.key,
    this.titleKey = '',
    this.title,
    this.icon,
    this.action,
  }) : assert(titleKey != '' || title != null,
            'SectionHeader needs a titleKey or a literal title');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = title ??
        Provider.of<LocalizationService>(context).t(titleKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.lightText.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// The standard surface every list row and form block sits on.
///
/// Replaces `_buildCard` / `_card` / `_postCard` / `_financeCard` /
/// `_buildEntityCard` / `_buildGoalCard` / `_buildMemberCard` and friends.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Tints the border, for status-carrying rows (overdue, rejected, …).
  final Color? accent;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: (accent ?? AppColors.primary)
            .withValues(alpha: accent != null ? 0.35 : 0.1),
      ),
    );

    final inner = Padding(padding: padding, child: child);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: inner),
            ),
    );
  }
}

/// A single headline number. Replaces the three unrelated `_statCard` variants.
class DashboardStat extends StatelessWidget {
  final String value;

  /// Dotted i18n key for the caption.
  final String labelKey;

  /// Literal caption, when it comes from data rather than the catalog.
  final String? label;

  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  const DashboardStat({
    super.key,
    required this.value,
    required this.icon,
    this.labelKey = '',
    this.label,
    this.accent,
    this.onTap,
  }) : assert(labelKey != '' || label != null,
            'DashboardStat needs a labelKey or a literal label');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colour = accent ?? AppColors.primary;
    final text =
        label ?? Provider.of<LocalizationService>(context).t(labelKey);

    return DashboardCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colour),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colour.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "nothing here yet" view.
///
/// Replaces eleven private implementations. [messageKey] is a dotted i18n key;
/// [action] is an optional call to action, which several of the old copies
/// wanted but none had room for.
class DashboardEmpty extends StatelessWidget {
  final IconData icon;
  final String messageKey;
  final String? message;
  final String? detailKey;
  final Widget? action;

  const DashboardEmpty({
    super.key,
    required this.icon,
    this.messageKey = '',
    this.message,
    this.detailKey,
    this.action,
  }) : assert(messageKey != '' || message != null,
            'DashboardEmpty needs a messageKey or a literal message');

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = message ?? loc.t(messageKey);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.lightText.withValues(alpha: 0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34,
                  color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : AppColors.lightText,
              ),
            ),
            if (detailKey != null) ...[
              const SizedBox(height: 6),
              Text(
                loc.t(detailKey!),
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 13, height: 1.5, color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The denied view, for a screen a role may open but not read.
///
/// The old screens mostly rendered an empty list here, which reads as "there is
/// nothing" rather than "you may not see this".
class DashboardDenied extends StatelessWidget {
  final String? messageKey;
  const DashboardDenied({super.key, this.messageKey});

  @override
  Widget build(BuildContext context) => DashboardEmpty(
        icon: Icons.lock_outline,
        messageKey: messageKey ?? 'admin.notApprover',
      );
}
