import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

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
        preferredSize: const Size.fromHeight(80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: _scrolled 
            ? const EdgeInsets.fromLTRB(16, 40, 16, 0)
            : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: _scrolled
                ? (isDark
                      ? const Color(0xFF0D2440).withOpacity(0.7)
                      : const Color(0xFFE7F0FA).withOpacity(0.7))
                : Colors.transparent,
            borderRadius: _scrolled ? BorderRadius.circular(20) : BorderRadius.zero,
            border: _scrolled
                ? Border.all(color: AppColors.primary.withOpacity(0.1))
                : null,
          ),
          child: ClipRRect(
            borderRadius: _scrolled ? BorderRadius.circular(20) : BorderRadius.zero,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _scrollToSection(_homeKey),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.transparent,
                              backgroundImage: AssetImage('assets/logo.png'),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'AHAW',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildHeaderIcon(
                            icon: isDark ? Icons.light_mode : Icons.dark_mode,
                            onTap: () => themeProvider.toggleTheme(!isDark),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIcon(
                            icon: Icons.menu,
                            onTap: () => _showMobileMenu(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
            _buildBenefitsSection(context),
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
      padding: const EdgeInsets.fromLTRB(24, 160, 24, 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.1),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'DIVINE TECHNOLOGY',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ).animate().fadeIn().moveY(begin: -20),

          const SizedBox(height: 32),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
              children: const [
                TextSpan(text: 'ቤተክርስቲያንን በ\n'),
                TextSpan(
                  text: 'ዘመናዊ ጥበብ',
                  style: TextStyle(color: AppColors.primary),
                ),
                TextSpan(text: '\nእናገልግል'),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).moveY(begin: 20),

          const SizedBox(height: 24),

          Text(
            'በመጽሐፍ ቅዱስ የተገለጠውን የእግዚአብሔርን ሃሳብ የምታገለግል በቃሉና በመንፈሱ የታደሰች ቤተክርስቲያን።',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms).moveY(begin: 20),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(
                'አሁኑኑ ይጀምሩ',
                style: GoogleFonts.notoSansEthiopic(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms).scale(),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final stats = [
      {'val': '850', 'label': 'አጥቢያዎች', 'icon': Icons.church},
      {'val': '2.4k', 'label': 'አገልጋዮች', 'icon': Icons.people},
      {'val': '40%', 'label': 'ዕድገት', 'icon': Icons.trending_up},
      {'val': '120+', 'label': 'ሃገረ ስብከቶች', 'icon': Icons.public},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(stat['icon'] as IconData, color: AppColors.primary, size: 24),
                const SizedBox(height: 8),
                Text(
                  stat['val'] as String,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  (stat['label'] as String).toUpperCase(),
                  style: TextStyle(fontSize: 10, color: AppColors.primary.withOpacity(0.6)),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (index * 100).ms).scale();
        },
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final features = [
      {'title': 'አባላት አስተዳደር', 'desc': 'የአባላትን መረጃ በቀላሉ ይያዙ', 'icon': Icons.people_outline},
      {'title': 'ዕቅድና ሪፖርት', 'desc': 'ተግባራትን ያቅዱ፣ ሪፖርት ያውጡ', 'icon': Icons.assignment_outlined},
      {'title': 'ፋይናንስ', 'desc': 'የገቢና ወጪ ሂሳቦችን ይቆጣጠሩ', 'icon': Icons.account_balance_wallet_outlined},
    ];

    return Container(
      key: _servicesKey,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'አገልግሎቶች',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ).animate().fadeIn(),
          const SizedBox(height: 32),
          ...features.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(f['icon'] as IconData, color: AppColors.primary, size: 30),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(f['desc'] as String, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().moveX(begin: 20)),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context) {
    return Container(
      key: _aboutKey,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          const Text('ለምን አሃው?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildBenefitItem('ደህንነት', 'አስተማማኝ መረጃ'),
          _buildBenefitItem('ተደራሽነት', 'በየትኛውም ቦታ'),
          _buildBenefitItem('ግልጽነት', 'ግልጽ ሪፖርቶች'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          Text('አሃው', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
          SizedBox(height: 10),
          Text('© 2025 የማህበረ አሃው ስነ-ምህዳር', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.primary),
        onPressed: onTap,
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuLink('ዋና ገፅ', _homeKey, context),
              _buildMenuLink('ስለ እኛ', _aboutKey, context),
              _buildMenuLink('አገልግሎቶች', _servicesKey, context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuLink(String text, GlobalKey key, BuildContext context) {
    return ListTile(
      title: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        _scrollToSection(key);
      },
    );
  }
}
