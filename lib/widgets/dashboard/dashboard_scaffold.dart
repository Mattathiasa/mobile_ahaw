import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../../services/module_config_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../branded_loader.dart';

/// The shell every authenticated screen sits in.
///
/// This block — themed background, transparent AppBar, Ethiopic w900 title,
/// manual back button — was copy-pasted into 25+ screens, each with its own
/// hardcoded English title. Centralising it does three things at once: the
/// chrome stops drifting, the title routes through [LocalizationService], and
/// the content gets the tablet/web width cap that only dashboard_page.dart was
/// applying.
///
/// Mirrors the web's DashboardLayout + ConfigurablePageHeader pairing: pass
/// [moduleKey] and an admin's title override from `siteConfig/moduleConfig`
/// wins over [titleKey], exactly as `useModuleConfig(module)` does there.
class DashboardScaffold extends StatelessWidget {
  /// Dotted i18n key for the title, e.g. `nav.announcements`.
  final String titleKey;

  /// Module key for the admin-editable title override. Null = no override.
  final String? moduleKey;

  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  /// Constrains content on tablet/desktop instead of stretching edge to edge.
  final bool constrainWidth;

  const DashboardScaffold({
    super.key,
    required this.titleKey,
    required this.body,
    this.moduleKey,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.constrainWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);
    final onSurface = isDark ? Colors.white : AppColors.lightText;

    var title = loc.t(titleKey);
    if (moduleKey != null) {
      final override =
          Provider.of<ModuleConfigService>(context).headerTitle(moduleKey!);
      if (override.trim().isNotEmpty) title = override;
    }

    final content = constrainWidth
        ? Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: Responsive.contentMaxWidthOf(context)),
              child: body,
            ),
          )
        : body;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900,
            color: onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: content,
    );
  }
}

/// The loading state, so screens stop hand-rolling a bare progress spinner.
class DashboardLoading extends StatelessWidget {
  const DashboardLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const BrandedLoader(variant: BrandedLoaderVariant.app);
}
