import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../brand_mark.dart';

/// The navigable sections, in the order they appear down the page.
///
/// This is the single source of truth: the menu sheet and the scroll spy both
/// map over it, and each id matches a section key the landing page registers.
/// Same list, same order, as `SECTIONS` in src/pages/Home.tsx:63 — the mobile
/// menu used to carry four hardcoded Amharic labels that matched neither the
/// page nor the reader's chosen language.
const List<String> kHomeSections = [
  'home',
  'about',
  'services',
  'support',
  'news',
  'sermons',
  'contact',
  'suggestions',
];

/// The fixed landing-page navigation: seal, language, theme, Login, and the
/// section menu.
///
/// The bar itself is transparent at every scroll position — it paints no
/// background and blurs nothing, so the hero stays sharp edge to edge. The
/// glass lives on the individual controls instead. An earlier version frosted
/// the whole bar with an unconditional [BackdropFilter], which blurred a strip
/// of the hero even before the page had been scrolled.
class HomeNav extends StatelessWidget implements PreferredSizeWidget {
  /// True once the page has scrolled past the hero. The bar stays transparent
  /// either way; this only firms up the pills so they keep their edge against
  /// whatever content is passing underneath.
  final bool scrolled;

  /// The section currently in view, for the menu's active marker.
  final String activeSection;

  final void Function(String sectionId) onNavigate;

  const HomeNav({
    super.key,
    required this.scrolled,
    required this.activeSection,
    required this.onNavigate,
  });

  /// The row is 40 high with 12 of breathing room above and below. The old
  /// value of 80 also had to absorb a 40px top margin in the scrolled state,
  /// which left too little for the SafeArea and the controls together.
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final loc = Provider.of<LocalizationService>(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onNavigate('home'),
              child: const BrandMark(size: BrandMarkSize.sm),
            ),
            const Spacer(),

            // Shows the CURRENT language and moves to the next on tap,
            // matching the web. It used to show the next language's code, so a
            // reader on Amharic saw a button labelled "OM". The label is the
            // short code rather than the endonym because 'Afaan Oromoo' on its
            // own overflowed a 320dp row; the sheet still spells it out.
            _GlassPill(
              scrolled: scrolled,
              isDark: isDark,
              onTap: () => loc.setLanguage(
                  LocalizationService.nextLanguageAfter(loc.language)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    LocalizationService.languageShortCodes[loc.language] ??
                        loc.language.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            _GlassPill(
              scrolled: scrolled,
              isDark: isDark,
              onTap: () => themeProvider.toggleTheme(!isDark),
              child: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                  size: 17, color: AppColors.primary),
            ),
            const SizedBox(width: 6),

            // The web nav carries a Login button beside the menu; the mobile
            // app only had it as a hero CTA, so a reader who had scrolled past
            // the hero had no way back to it. Solid, so it stays the one
            // accent among four glass pills.
            Flexible(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(
                    loc.t('nav.login'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            _GlassPill(
              scrolled: scrolled,
              isDark: isDark,
              onTap: () => _showMenu(context, loc),
              child:
                  const Icon(Icons.menu, size: 19, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, LocalizationService loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ...kHomeSections.map((section) {
              final active = section == activeSection;
              return ListTile(
                leading: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: active ? 1 : 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                horizontalTitleGap: 4,
                minLeadingWidth: 16,
                title: Text(
                  loc.t('nav.$section'),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: active
                        ? AppColors.primary
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onNavigate(section);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// One frosted control.
///
/// The blur is per-pill rather than per-bar, so the hero shows through sharp
/// between the controls and only the glass itself softens what is behind it.
class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  final bool scrolled;

  const _GlassPill({
    required this.child,
    required this.onTap,
    required this.isDark,
    required this.scrolled,
  });

  @override
  Widget build(BuildContext context) {
    // Over the hero the glass can stay light; once page content is sliding
    // underneath it needs a touch more body to hold the icon legible.
    final fill = isDark
        ? Colors.white.withValues(alpha: scrolled ? 0.10 : 0.06)
        : Colors.white.withValues(alpha: scrolled ? 0.72 : 0.55);
    final border = isDark
        ? Colors.white.withValues(alpha: scrolled ? 0.18 : 0.12)
        : Colors.white.withValues(alpha: scrolled ? 0.90 : 0.75);

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 38,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withValues(alpha: scrolled ? 0.10 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
