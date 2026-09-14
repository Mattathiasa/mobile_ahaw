import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_mark.dart';

/// Full-screen block shown when the admin enables the kill switch
/// from the web app (Mobile App Control).
class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.build_circle_outlined,
                    size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text(
                'Under Maintenance',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? Colors.white60
                      : AppColors.lightText.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown to a signed-in member whose account is still `status: 'pending'`.
///
/// It updates itself: `AuthService` watches `users/{uid}` live, so the moment
/// an approver acts this screen is replaced. It used to sit on a one-shot read
/// with no refresh, which meant approval did not take effect until the app was
/// killed and reopened.
class PendingApprovalScreen extends StatelessWidget {
  final String? parishName;
  final VoidCallback onSignOut;

  const PendingApprovalScreen({
    super.key,
    required this.parishName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final parish = parishName?.trim() ?? '';

    // The web splits this into a "with <parish>" form and a generic one so the
    // parish name can be emphasised; same split here.
    final body = parish.isNotEmpty
        ? '${loc.t('pages.pendingRequestWith')} $parish${loc.t('pages.pendingApproveNote')}'
        : loc.t('pages.pendingSentGeneric');

    return _GateScaffold(
      icon: Icons.hourglass_top_rounded,
      accent: AppColors.divineGold,
      title: loc.t('pages.requestSent'),
      badge: loc.t('pages.pendingTitle'),
      body: body,
      action: _GateAction(
        label: loc.t('pages.pendingSignOut'),
        icon: Icons.logout,
        color: AppColors.sacredRed,
        onTap: onSignOut,
        filled: false,
      ),
    );
  }
}

/// Shown to a member whose request was turned down.
///
/// Without this a rejected member fell through to the dashboard, where every
/// query is denied by the rules — which reads as the app being broken rather
/// than as a decision having been made.
class RejectedScreen extends StatelessWidget {
  final String? reason;
  final VoidCallback onSignOut;

  const RejectedScreen({super.key, required this.reason, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final why = reason?.trim() ?? '';

    return _GateScaffold(
      icon: Icons.cancel_outlined,
      accent: AppColors.sacredRed,
      title: loc.t('pages.rejectedTitle'),
      body: loc.t('pages.rejectedGeneric'),
      detailLabel: why.isEmpty ? null : loc.t('pages.rejectedReasonLabel'),
      detail: why.isEmpty ? null : why,
      action: _GateAction(
        label: loc.t('pages.pendingSignOut'),
        icon: Icons.logout,
        color: AppColors.sacredRed,
        onTap: onSignOut,
        filled: false,
      ),
    );
  }
}

class _GateAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  const _GateAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = true,
  });
}

/// The shared frame for every gate: emblem, badge, title, body, one action.
class _GateScaffold extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? badge;
  final String body;
  final String? detailLabel;
  final String? detail;
  final _GateAction? action;

  const _GateScaffold({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.badge,
    this.detailLabel,
    this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heading = isDark ? Colors.white : AppColors.lightText;
    final muted = isDark ? Colors.white70 : AppColors.lightText.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: BrandMarkSize.lg),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: accent),
                ),
                const SizedBox(height: 24),
                if (badge != null && badge!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      badge!.toUpperCase(),
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 15,
                    height: 1.6,
                    color: muted,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (detailLabel ?? '').toUpperCase(),
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail!,
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 14,
                            height: 1.55,
                            color: heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: action!.filled
                        ? ElevatedButton.icon(
                            onPressed: action!.onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: action!.color,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: Icon(action!.icon, size: 18),
                            label: Text(
                              action!.label.toUpperCase(),
                              style: GoogleFonts.notoSansEthiopic(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: action!.onTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: action!.color,
                              side: BorderSide(
                                  color:
                                      action!.color.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: Icon(action!.icon, size: 18),
                            label: Text(
                              action!.label.toUpperCase(),
                              style: GoogleFonts.notoSansEthiopic(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Full-screen block shown when this build is older than the minimum
/// build number required by the web admin.
class ForceUpdateScreen extends StatelessWidget {
  final String latestVersionName;
  final String updateUrl;

  const ForceUpdateScreen({
    super.key,
    required this.latestVersionName,
    required this.updateUrl,
  });

  /// Opens the store listing.
  ///
  /// This is the one dead end in the app that really matters: a user the admin
  /// has force-updated cannot get past this screen by any other route, so a
  /// silent failure strands them. It gated on `canLaunchUrl` and said nothing
  /// when that answered false — which it did on every Android 11+ device until
  /// the manifest gained its `<queries>` entries. Now the button reports
  /// failure and falls back to trying the launch anyway.
  Future<void> _openStore(BuildContext context) async {
    if (updateUrl.isEmpty) return;
    final uri = Uri.tryParse(updateUrl);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (kDebugMode) print('[ForceUpdate] could not open $updateUrl: $e');
      }
    }
    if (!opened && context.mounted) {
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('common.linkCannotOpen'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update,
                    size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text(
                'Update Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                latestVersionName.isEmpty
                    ? 'A newer version of the app is required to continue.'
                    : 'Version $latestVersionName is required to continue. Please update the app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? Colors.white60
                      : AppColors.lightText.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
              if (updateUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download),
                    label: Text(
                      'UPDATE NOW',
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
