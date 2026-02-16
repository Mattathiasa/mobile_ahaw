import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 20 && !_scrolled) {
        setState(() => _scrolled = true);
      } else if (_scrollController.offset <= 20 && _scrolled) {
        setState(() => _scrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dynamic styles based on theme
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.lightText;
    final subTextColor = isDark ? Colors.white70 : AppColors.lightText.withOpacity(0.6);

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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (user?.email ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 300.ms),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                          Text(
                            user?.email?.split('@')[0] ?? 'User',
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 100.ms).moveX(begin: -10),
                    ],
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
                          size: 20,
                        ),
                        onPressed: () => themeProvider.toggleTheme(!isDark),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
                        onPressed: () {
                          Provider.of<AuthService>(context, listen: false).signOut();
                        },
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
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 100), // Adjusted top padding for header
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard(
                  context,
                  title: 'Total Members',
                  value: '1,234',
                  icon: FontAwesomeIcons.users,
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                _buildStatCard(
                  context,
                  title: 'Active Plans',
                  value: '8',
                  icon: FontAwesomeIcons.calendarCheck,
                  color: AppColors.success,
                  isDark: isDark,
                ),
                _buildStatCard(
                  context,
                  title: 'Pending Reports',
                  value: '3',
                  icon: FontAwesomeIcons.fileLines,
                  color: AppColors.warning,
                  isDark: isDark,
                ),
                _buildStatCard(
                  context,
                  title: 'Upcoming Meetings',
                  value: '2',
                  icon: FontAwesomeIcons.peopleGroup,
                  color: const Color(0xFF9C27B0),
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 32),
            
            Text(
              'Quick Actions',
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().fadeIn(delay: 200.ms).moveY(begin: 10),
            
            const SizedBox(height: 16),

            // Action Tiles
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
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
                children: [
                  _buildActionTile(
                    context,
                    icon: Icons.person_add,
                    title: 'Add New Member',
                    isFirst: true,
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.primary.withOpacity(0.05)),
                  _buildActionTile(
                    context,
                    icon: Icons.assignment_add,
                    title: 'Submit Monthly Report',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.primary.withOpacity(0.05)),
                  _buildActionTile(
                    context,
                    icon: Icons.calendar_month,
                    title: 'Schedule Meeting',
                    isLast: true,
                    onTap: () {},
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).moveY(begin: 20),
            
            const SizedBox(height: 32),
            
            // Recent Activity / Banner (Optional)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Event',
                          style: GoogleFonts.notoSansEthiopic(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sunday Service',
                          style: GoogleFonts.notoSansEthiopic(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '09:00 AM - 12:00 PM',
                              style: GoogleFonts.notoSansEthiopic(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.event, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).moveY(begin: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor.withOpacity(0.8),
          border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.05))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
           // Apply blur effect for glassmorphism if needed, using BackdropFilter
           // For simplicity, just using opacity above
           child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            backgroundColor: Colors.transparent, // Important for glass effect
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDark ? Colors.white38 : Colors.grey,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.notoSansEthiopic(fontSize: 12),
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                activeIcon: Icon(Icons.campaign),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined),
                activeIcon: Icon(Icons.assignment),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 10,
              color: isDark ? Colors.white60 : AppColors.lightText.withOpacity(0.6),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).moveY(begin: 20);
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
