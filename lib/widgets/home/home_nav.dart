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

/// The fixed landing-page navigation: seal, theme toggle, language toggle,
/// Login, and the section menu. Mirrors the nav in src/pages/Home.tsx:224.
class HomeNav extends StatelessWidget implements PreferredSizeWidget {
  /// True once the page has scrolled past the hero, which frosts the bar.
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

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final loc = Provider.of<LocalizationService>(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: scrolled
          ? const EdgeInsets.fromLTRB(16, 40, 16, 0)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: scrolled
            ? (isDark
                ? AppColors.darkBackground.withValues(alpha: 0.7)
                : AppColors.lightBackground.withValues(alpha: 0.7))
            : Colors.transparent,
        borderRadius:
            scrolled ? BorderRadius.circular(20) : BorderRadius.zero,
        border: scrolled
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.1))
            : null,
      ),
      child: ClipRRect(
        borderRadius:
            scrolled ? BorderRadius.circular(20) : BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => onNavigate('home'),
                    child: const BrandMark(size: BrandMarkSize.sm),
                  ),
                  const Spacer(),

                  // Shows the CURRENT language and moves to the next on tap,
                  // matching the web. It used to show the next language's code,
                  // so a reader on Amharic saw a button labelled "OM".
                  _PillButton(
                    onTap: () => loc.setLanguage(
                        LocalizationService.nextLanguageAfter(loc.language)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          LocalizationService.languageEndonyms[loc.language] ??
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
                  const SizedBox(width: 8),

                  _PillButton(
                    onTap: () => themeProvider.toggleTheme(!isDark),
                    child: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),

                  // The web nav carries a Login button beside the menu; the
                  // mobile app only had it as a hero CTA, so a reader who had
                  // scrolled past the hero had no way back to it.
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        loc.t('nav.login'),
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  _PillButton(
                    onTap: () => _showMenu(context, loc),
                    child: const Icon(Icons.menu,
                        size: 20, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
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

class _PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PillButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}
