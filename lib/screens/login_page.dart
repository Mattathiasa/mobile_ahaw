import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import 'suggestion_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // ── Success: pop back to AuthWrapper which will show DashboardPage ──
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        if (_errorMessage!.contains('firebase_auth')) {
          _errorMessage = _errorMessage!.split('] ').last;
        }
        // Clean up common Firebase error prefixes
        if (_errorMessage!.startsWith('Exception: ')) {
          _errorMessage = _errorMessage!.replaceFirst('Exception: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = Provider.of<LocalizationService>(context);

    // Real 4-way language cycle (EN → AM → OM → TI) wired to the app locale.
    const langs = LocalizationService.supportedLanguages;
    final nextLang = langs[(langs.indexOf(loc.language) + 1) % langs.length];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Dynamic Background ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0D2440),
                        const Color(0xFF1A365D),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFFF0F7FF),
                        const Color(0xFFE0EBF5),
                        const Color(0xFFF8F9FA),
                      ],
              ),
            ),
          ),

          // ── Decorative Blobs ──
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: 50, duration: 4.seconds),

          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.12),
                    blurRadius: 80,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -30, duration: 5.seconds),

          // ── Top-left: Home button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined,
                        size: 16,
                        color: isDark ? Colors.white70 : AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      loc.t('loginHome').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white70 : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().moveY(begin: -10),
          ),

          // ── Top-right: Theme + Language toggles ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Row(
              children: [
                // Theme toggle
                _buildTopButton(
                  isDark: isDark,
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 16,
                    color: isDark ? AppColors.accent : AppColors.primary,
                  ),
                  onTap: () => themeProvider.toggleTheme(!isDark),
                ),
                const SizedBox(width: 8),
                // Language toggle
                _buildTopButton(
                  isDark: isDark,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language,
                          size: 14,
                          color: isDark ? AppColors.accent : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        nextLang.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white70 : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => loc.setLanguage(nextLang),
                ),
              ],
            ).animate().fadeIn().moveY(begin: -10),
          ),

          // ── Main Card ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.85),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Gradient accent bar (matches web) ──
                        Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.accent,
                                AppColors.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Logo ──
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 60,
                                    width: 60,
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 500.ms)
                                  .scale(delay: 200.ms, duration: 500.ms),

                              const SizedBox(height: 20),

                              // ── Sparkle badge (matches web) ──
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        size: 11, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      loc.t('loginBadge').toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 100.ms),

                              const SizedBox(height: 14),

                              // ── Title ──
                              Text(
                                loc.t('loginTitle'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ).animate().fadeIn().moveY(begin: 10),

                              Text(
                                loc.t('loginSubtitle'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ).animate().fadeIn(delay: 150.ms).moveY(begin: 10),

                              const SizedBox(height: 28),

                              // ── Error message ──
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.sacredRed.withOpacity(0.08),
                                    border: Border.all(
                                        color: AppColors.sacredRed
                                            .withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: AppColors.sacredRed, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                              color: AppColors.sacredRed,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(),

                              // ── Email field ──
                              _buildTextField(
                                controller: _emailController,
                                label: loc.t('loginUsernameLabel'),
                                icon: Icons.mail_outline,
                                isDark: isDark,
                              ).animate().fadeIn(delay: 300.ms).moveX(begin: -20),

                              const SizedBox(height: 14),

                              // ── Password field ──
                              _buildTextField(
                                controller: _passwordController,
                                label: loc.t('loginPasswordLabel'),
                                icon: Icons.lock_outline,
                                isObscure: true,
                                isLast: true,
                                isDark: isDark,
                                onSubmitted: (_) => _signIn(),
                              ).animate().fadeIn(delay: 400.ms).moveX(begin: -20),

                              const SizedBox(height: 24),

                              // ── Sign In button ──
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 10,
                                    shadowColor:
                                        AppColors.primary.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              loc.t('loginSignIn'),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward,
                                                size: 18),
                                          ],
                                        ),
                                ),
                              ).animate().fadeIn(delay: 500.ms).moveY(begin: 20),

                              const SizedBox(height: 8),

                              // ── Create account link ──
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context, '/signup'),
                                child: Text(
                                  "Don't have an account? Create one",
                                  style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),

                              // ── Suggestion box link (public) ──
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SuggestionPage())),
                                child: Text(
                                  'Send us a suggestion',
                                  style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary.withOpacity(0.8),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── Auth note (matches web dashed box) ──
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primary.withOpacity(0.05)
                                      : const Color(0xFFE7F0FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      loc.t('loginAuthNote').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: isDark
                                            ? Colors.white38
                                            : AppColors.primary.withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      loc.t('loginAuthDesc'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white30
                                            : AppColors.lightText
                                                .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 600.ms),

                              const SizedBox(height: 20),

                              // ── Footer ──
                              Text(
                                '© 2025 Mahibere Ahaw',
                                style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey[400],
                                ),
                              ).animate().fadeIn(delay: 700.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required bool isDark,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    bool isLast = false,
    required bool isDark,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: GoogleFonts.notoSansEthiopic(
          color: isDark ? Colors.white : AppColors.lightText,
        ),
        textInputAction:
            isLast ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark
                ? Colors.white54
                : AppColors.primary.withOpacity(0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.white38 : AppColors.primary.withOpacity(0.5),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
