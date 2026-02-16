import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/custom_button.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_scrolled) {
        setState(() => _scrolled = true);
      } else if (_scrollController.offset <= 50 && _scrolled) {
        setState(() => _scrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: _scrolled
                ? (isDark
                      ? const Color(0xFF0D2440).withOpacity(0.85)
                      : const Color(0xFFE7F0FA).withOpacity(0.85))
                : Colors.transparent,
            border: _scrolled
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  )
                : null,
            boxShadow: _scrolled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _scrollToSection(_homeKey),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 10,
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/logo.png',
                              height: 40,
                              width: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'AHAW',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ).animate().scale(duration: 300.ms),
                  ),
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: isDark ? AppColors.white : AppColors.primary,
                        ),
                        onPressed: () => themeProvider.toggleTheme(!isDark),
                      ),
                      const SizedBox(width: 8),
                      // Language Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Text(
                            'EN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.menu, color: AppColors.primary),
                        onPressed: () => _showMobileMenu(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(context),
            _buildStatsSection(context),
            _buildFeaturesSection(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      key: _homeKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 140, 24, 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'REVOLUTIONIZING MINISTRY',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().moveY(begin: -20),

          const SizedBox(height: 32),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: isDark ? AppColors.white : AppColors.lightText,
              ),
              children: const [
                TextSpan(text: 'የወደፊቱ\n'),
                TextSpan(
                  text: 'Divine Tech.',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).moveY(begin: 20),

          const SizedBox(height: 24),

          Text(
            'በመጽሐፍ ቅዱስ የተገለጠውን የእግዚአብሔርን ሃሳብ የምታገለግል በቃሉና በመንፈሱ የታደሰች ኦርቶዶክሳዊት ቤ/ክ።',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 18,
              color: isDark
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.8),
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 200.ms).moveY(begin: 20),

          const SizedBox(height: 48),

          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ጀምር',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _scrollToSection(_aboutKey),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    foregroundColor: isDark ? Colors.white : AppColors.primary,
                  ),
                  child: const Text(
                    'ተጨማሪ ይመልከቱ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).moveY(begin: 20),

          const SizedBox(height: 60),

          // 3D Card Effect Placeholder
          Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  color: Colors.white.withOpacity(0.4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/dashboardpreview.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            (isDark
                                    ? AppColors.darkBackground
                                    : const Color(0xFF0D2440))
                                .withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 20,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ahaw Pro Cloud',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms)
              .scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final stats = [
      {'val': '850', 'label': 'Congregations', 'icon': Icons.map},
      {'val': '2.4k', 'label': 'Admin Staff', 'icon': Icons.security},
      {'val': '40%', 'label': 'Spiritual Growth', 'icon': Icons.favorite},
      {'val': '120+', 'label': 'Global Reach', 'icon': Icons.language},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.white.withOpacity(0.5),
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.primary.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 32,
              childAspectRatio: 0.8,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final stat = stats[index];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.1)
                          : const Color(0xFFE7F0FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Icon(
                      stat['icon'] as IconData,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    stat['val'] as String,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (stat['label'] as String).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: isDark
                          ? AppColors.secondary.withOpacity(0.8)
                          : AppColors.primary.withOpacity(0.4),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: (100 * index).ms).moveY(begin: 20);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final features = [
      {
        'title': 'የአባላት አስተዳደር',
        'desc': 'የቤተክርስቲያን አባላትን በቀላሉ ያስተዳድሩ',
        'icon': FontAwesomeIcons.users,
        'color': AppColors.primary,
      },
      {
        'title': 'ዕቅድ አስተዳደር',
        'desc': 'የወርሃዊ እና የዓመታዊ እቅዶችን ያስተዳድሩ',
        'icon': FontAwesomeIcons.fileLines,
        'color': AppColors.secondary,
      },
      {
        'title': 'የሪፖርት አቅራቢያ',
        'desc': 'ሪፖርቶችን በቀላሉ ያቅርቡ እና ይከታተሉ',
        'icon': FontAwesomeIcons.chartSimple,
        'color': const Color(0xFF0D2440),
      },
    ];

    return Container(
      key: _servicesKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ባህሪያት',
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need to lead your church into the future.',
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 18,
              color: AppColors.primary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ...features
              .map(
                (f) => Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A365D) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              f['color'] as Color,
                              (f['color'] as Color).withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (f['color'] as Color).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: FaIcon(
                            f['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        f['title'] as String,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        f['desc'] as String,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 16,
                          color: isDark
                              ? Colors.white70
                              : AppColors.lightText.withOpacity(0.7),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'ተጨማሪ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList()
              .animate(interval: 100.ms)
              .fadeIn()
              .moveY(begin: 30),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      key: _contactKey,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1C30) : Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.png', width: 32, height: 32),
              ),
              const SizedBox(width: 12),
              const Text(
                'AHAW',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Integrating ancient spiritual values with the precision of modern engineering.',
            style: TextStyle(
              color: isDark
                  ? Colors.white60
                  : AppColors.lightText.withOpacity(0.6),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              _buildSocialButton(FontAwesomeIcons.facebook),
              const SizedBox(width: 16),
              _buildSocialButton(FontAwesomeIcons.twitter),
              const SizedBox(width: 16),
              _buildSocialButton(FontAwesomeIcons.linkedin),
            ],
          ),
          const SizedBox(height: 48),
          Divider(color: AppColors.primary.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(
            '© 2025 Mahibere Ahaw Ecosystem.\nAll rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white30
                  : AppColors.lightText.withOpacity(0.3),
              height: 1.6,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: FaIcon(icon, size: 20, color: AppColors.primary)),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).isDarkMode;

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D2440) : const Color(0xFFE7F0FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              _buildMenuLink('ዋና ገፅ', _homeKey, context),
              _buildMenuLink('ስለ እኛ', _aboutKey, context),
              _buildMenuLink('የእኛ አገልግሎቶች', _servicesKey, context),
              _buildMenuLink('እውቂያ', _contactKey, context),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'ግባ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuLink(String text, GlobalKey key, BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.lightText,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.primary.withOpacity(0.5),
      ),
      onTap: () {
        Navigator.pop(context);
        _scrollToSection(key);
      },
    );
  }
}
