import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';

/// Mirrors the essentials of the web Settings page: profile summary,
/// appearance (dark mode), and app/system info.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    final user = authService.userModel;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.t('settings'),
            style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            )),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card ──
          _sectionTitle('PROFILE'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: (user?.profilePicture != null && user!.profilePicture!.isNotEmpty)
                          ? Image.network(
                              user.profilePicture!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarInitials(user),
                            )
                          : _avatarInitials(user),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullNameAmharic ??
                                user?.fullNameEnglish ??
                                user?.fullName ??
                                user?.username ??
                                'User',
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark ? Colors.white : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(user?.email ?? '',
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoRow('Username', user?.username ?? '—', isDark),
                _infoRow('Hierarchy Level', user?.hierarchyLevel ?? '—', isDark),
                _infoRow('Role', user?.role ?? '—', isDark),
                if ((user?.phone ?? '').isNotEmpty)
                  _infoRow('Phone', user!.phone!, isDark),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 24),

          // ── Language ──
          _sectionTitle(loc.t('language').toUpperCase()),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final lang in LocalizationService.supportedLanguages)
                  RadioListTile<String>(
                    value: lang,
                    groupValue: loc.language,
                    onChanged: (v) {
                      if (v != null) loc.setLanguage(v);
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      LocalizationService.languageNames[lang] ?? lang,
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 24),

          // ── Appearance ──
          _sectionTitle('APPEARANCE'),
          Container(
            decoration: _cardDecoration(isDark),
            child: SwitchListTile(
              value: themeProvider.isDarkMode,
              onChanged: (v) => themeProvider.toggleTheme(v),
              activeColor: AppColors.primary,
              title: Text('Dark Mode',
                  style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : AppColors.lightText,
                  )),
              subtitle: Text('Switch between light and dark themes',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 11, color: Colors.grey)),
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: AppColors.primary,
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 24),

          // ── About ──
          _sectionTitle('ABOUT'),
          Container(
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('App Version',
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : AppColors.lightText,
                      )),
                  trailing: Text(_version.isEmpty ? '—' : _version,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12, color: Colors.grey)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.church_outlined,
                      color: AppColors.primary),
                  title: Text('Mahibere Ahaw',
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : AppColors.lightText,
                      )),
                  subtitle: Text('Yekiristos Betekerstian',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),

          // ── Logout ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                authService.signOut();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sacredRed,
                side: BorderSide(color: AppColors.sacredRed.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(loc.t('logout').toUpperCase(),
                  style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 12,
                  )),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.grey,
            )),
      );

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      );

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Colors.grey,
              )),
          Text(value,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.lightText,
              )),
        ],
      ),
    );
  }

  Widget _avatarInitials(UserModel? user) {
    return Center(
      child: Text(
        _initials(user?.fullNameEnglish ?? user?.fullName ?? user?.username ?? 'U'),
        style: GoogleFonts.notoSansEthiopic(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
