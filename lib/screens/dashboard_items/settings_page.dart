import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/member_service.dart';
import '../../widgets/image_upload_field.dart';
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
  final MemberService _memberService = MemberService();
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

          // ── Account ──
          _sectionTitle('ACCOUNT'),
          Container(
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.person_outline, color: AppColors.primary),
                  title: Text('Edit Profile',
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppColors.lightText)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: user == null ? null : () => _openProfileForm(user),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading:
                      const Icon(Icons.lock_outline, color: AppColors.primary),
                  title: Text('Change Password',
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppColors.lightText)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: _openPasswordForm,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 30.ms),

          const SizedBox(height: 24),

          // ── Notifications ──
          _sectionTitle('NOTIFICATIONS'),
          Container(
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                for (final pref in const [
                  ['push', 'Push notifications'],
                  ['announcements', 'Announcements'],
                  ['meetings', 'Meeting reminders'],
                  ['reports', 'Report updates'],
                ])
                  SwitchListTile(
                    value: (user?.notificationPreferences?[pref[0]] ?? true) == true,
                    activeColor: AppColors.primary,
                    dense: true,
                    title: Text(pref[1],
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color:
                                isDark ? Colors.white : AppColors.lightText)),
                    onChanged: user == null
                        ? null
                        : (v) => _toggleNotification(user, pref[0], v),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 60.ms),

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

  Future<void> _toggleNotification(
      UserModel user, String key, bool value) async {
    final prefs =
        Map<String, dynamic>.from(user.notificationPreferences ?? {});
    prefs[key] = value;
    await _memberService.updateMember(user.id, {'notificationPreferences': prefs});
    if (mounted) {
      await Provider.of<AuthService>(context, listen: false).refreshUser();
    }
  }

  void _openProfileForm(UserModel user) {
    final nameEnCtrl =
        TextEditingController(text: user.fullNameEnglish ?? user.fullName);
    final nameAmCtrl = TextEditingController(text: user.fullNameAmharic);
    final phoneCtrl = TextEditingController(text: user.phone);
    String photo = user.profilePicture ?? '';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Profile',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    Center(
                      child: ImageUploadField(
                        initialUrl: photo,
                        folder: 'avatars',
                        label: 'Profile photo',
                        onUploaded: (url) => photo = url,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _formField(nameEnCtrl, 'Full Name (English)', required: true),
                    _formField(nameAmCtrl, 'Full Name (Amharic)'),
                    _formField(phoneCtrl, 'Phone',
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                try {
                                  await _memberService.updateMember(user.id, {
                                    'fullNameEnglish': nameEnCtrl.text.trim(),
                                    'fullNameAmharic': nameAmCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'profilePicture': photo,
                                  });
                                  if (mounted) {
                                    await Provider.of<AuthService>(context,
                                            listen: false)
                                        .refreshUser();
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPasswordForm() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Password',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _formField(currentCtrl, 'Current password',
                        required: true, obscure: true),
                    _formField(newCtrl, 'New password (min 6)',
                        required: true, obscure: true),
                    _formField(confirmCtrl, 'Confirm new password',
                        required: true, obscure: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (newCtrl.text != confirmCtrl.text) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('New passwords do not match.')));
                                  return;
                                }
                                setSheet(() => saving = true);
                                try {
                                  await Provider.of<AuthService>(context,
                                          listen: false)
                                      .changePassword(
                                    currentPassword: currentCtrl.text,
                                    newPassword: newCtrl.text,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Password updated.')));
                                  }
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('$e')));
                                  }
                                }
                              },
                        child: Text(saving ? 'Updating…' : 'Update Password',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label,
      {bool required = false,
      bool obscure = false,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
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
