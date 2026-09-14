import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';

/// A slim bar that appears when the device loses its network path.
///
/// Wraps a screen's body rather than living in the AppBar, so it also shows on
/// the screens that draw their own chrome (the landing page, the gates).
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    final loc = Provider.of<LocalizationService>(context);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          // `SizedBox.shrink()`, not a `double.infinity` width: AnimatedSize
          // measures its child, and an infinite width there leaves the whole
          // app with a zero-width viewport and nothing paints at all.
          child: online
              ? const SizedBox.shrink()
              : Material(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              loc.t('common.offlineBanner'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansEthiopic(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppColors.lightText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
