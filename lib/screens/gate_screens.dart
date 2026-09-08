import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

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
                  color: AppColors.primary.withOpacity(0.1),
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
                      : AppColors.lightText.withOpacity(0.6),
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
/// firestore.rules denies all data until an approver activates them, so this
/// holding screen explains the wait and offers a sign-out.
class PendingApprovalScreen extends StatelessWidget {
  final String? parishName;
  final VoidCallback onSignOut;

  const PendingApprovalScreen({
    super.key,
    required this.onSignOut,
    this.parishName,
  });

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
                  color: AppColors.divineGold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top,
                    size: 64, color: AppColors.divineGold),
              ),
              const SizedBox(height: 28),
              Text(
                'Awaiting Approval',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                parishName != null && parishName!.isNotEmpty
                    ? 'Your membership request to $parishName has been received. An approver will activate your account shortly.'
                    : 'Your membership request has been received. An approver will activate your account shortly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? Colors.white60
                      : AppColors.lightText.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sacredRed,
                    side:
                        BorderSide(color: AppColors.sacredRed.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text('SIGN OUT',
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
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

  Future<void> _openStore() async {
    if (updateUrl.isEmpty) return;
    final uri = Uri.tryParse(updateUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  color: AppColors.primary.withOpacity(0.1),
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
                      : AppColors.lightText.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 28),
              if (updateUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openStore,
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
