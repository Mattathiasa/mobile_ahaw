import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/permission_service.dart';
import '../services/role_registry_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/main_drawer.dart';
import 'dashboard_items/announcements_page.dart';
import 'dashboard_items/reports_page.dart';
import 'dashboard_items/members_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController _scrollController = ScrollController();
  final DashboardService _dashboardService = DashboardService();
  bool _scrolled = false;
  late Future<DashboardData> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _loadDashboard();
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

  /// Loads dashboard data scoped to the signed-in user's directory scope, so a
  /// parish user's member count isn't a rules-denied query.
  Future<DashboardData> _loadDashboard() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    final scope = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    return _dashboardService.getDashboardData(
      wholeDirectory: scope.wholeDirectory,
      atbiyaId: scope.atbiyaId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final perms = Provider.of<PermissionService>(context);
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: const MainDrawer(),
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
                        color: AppColors.primary.withOpacity(0.1)))
                : null,
            boxShadow: _scrolled
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10)
                  ]
                : [],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu,
                          color: isDark ? Colors.white : AppColors.lightText),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: isDark ? AppColors.white : AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => themeProvider.toggleTheme(!isDark),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            Provider.of<AuthService>(context).userModel?.initials ??
                                (user?.email ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Background decorative blobs (matches web ThreeBackground) ──
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Main scrollable content ──
          RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardData = _loadDashboard();
              });
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              child: FutureBuilder<DashboardData>(
                future: _dashboardData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 100.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null) {
                    return Center(
                      child: Text('Error loading data',
                          style: GoogleFonts.notoSansEthiopic()),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile header card
                      _buildHeaderCard(
                        context,
                        user,
                        Provider.of<AuthService>(context).userData,
                        isDark,
                      ),
                      const SizedBox(height: 20),

                      // Stats grid
                      _buildStatsGrid(context, data.stats, isDark),
                      const SizedBox(height: 28),

                      // Quick actions — only shown when dashboardView != 'basic'
                      if (perms.dashboardView != 'basic') ...[
                        _buildSectionHeader(
                            context,
                            'Divine Tasks',
                            isDark ? Colors.white : AppColors.lightText,
                            FontAwesomeIcons.bolt),
                        const SizedBox(height: 14),
                        _buildQuickActions(context, isDark),
                        const SizedBox(height: 28),
                      ],

                      // Recent Announcements
                      _buildSectionHeaderWithViewAll(
                        context,
                        'Recent Announcements',
                        isDark ? Colors.white : AppColors.lightText,
                        FontAwesomeIcons.bullhorn,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AnnouncementsPage()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildRecentAnnouncements(
                          context, data.recentAnnouncements, isDark),
                      const SizedBox(height: 28),

                      // Upcoming Meetings
                      _buildSectionHeader(
                          context,
                          'Upcoming Meetings',
                          isDark ? Colors.white : AppColors.lightText,
                          FontAwesomeIcons.calendarDay),
                      const SizedBox(height: 14),
                      _buildUpcomingMeetings(
                          context, data.upcomingMeetings, isDark),
                      const SizedBox(height: 28),

                      // Recent Reports
                      _buildSectionHeader(
                          context,
                          'Recent Reports',
                          isDark ? Colors.white : AppColors.lightText,
                          FontAwesomeIcons.fileSignature),
                      const SizedBox(height: 14),
                      _buildRecentReports(
                          context, data.recentReports, isDark),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Profile Header Card (expanded to match web)
  // ─────────────────────────────────────────────
  Widget _buildHeaderCard(BuildContext context, dynamic user,
      Map<String, dynamic>? userData, bool isDark) {
    // Use userModel directly for richer, typed data
    final userModel = Provider.of<AuthService>(context).userModel;

    final name = userModel?.fullNameAmharic ??
        userModel?.fullNameEnglish ??
        userModel?.fullName ??
        user?.email?.split('@')[0] ??
        'Church Member';
    final role = userModel?.role ?? 'Member';
    final level = userModel?.hierarchyLevel ?? 'Atbiya';
    final phone = userModel?.phone;
    final church = userModel?.address?['city'] ??
        userModel?.address?['woreda'] ??
        userModel?.address?['zone'];
    final dateOfBirth = userModel?.dateOfBirth;
    final workSchool = userModel?.workSchool;
    final maritalStatus = userModel?.maritalStatus;
    final hasChildren = userModel?.hasChildren ?? false;
    final childrenCount = userModel?.childrenCount ?? 0;
    final email = userModel?.email ?? user?.email ?? '';

    // Format joined date from createdAt
    String joinedText = '';
    if (userModel?.createdAt != null) {
      try {
        DateTime? dt;
        final raw = userModel!.createdAt;
        if (raw is DateTime) {
          dt = raw;
        } else if (raw.runtimeType.toString().contains('Timestamp')) {
          dt = (raw as dynamic).toDate() as DateTime;
        } else if (raw is String) {
          dt = DateTime.tryParse(raw);
        }
        if (dt != null) {
          const months = ['Jan','Feb','Mar','Apr','May','Jun',
                          'Jul','Aug','Sep','Oct','Nov','Dec'];
          joinedText = 'Joined: ${months[dt.month - 1]} ${dt.year}';
        }
      } catch (_) {}
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A365D).withOpacity(0.45)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: badge + joined date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline,
                            size: 10, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'MEMBER PROFILE',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (userData?['createdAt'] != null)
                    Text(
                      joinedText,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                name,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                  height: 1.1,
                ),
              ),
              if (userModel?.fullNameAmharic != null) ...[
                const SizedBox(height: 4),
                Text(
                  userModel!.fullNameAmharic!,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Level + Role badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildSmallBadge(level, AppColors.primary),
                  _buildSmallBadge('Role: $role', AppColors.primaryLight),
                ],
              ),

              Divider(
                  color: AppColors.primary.withOpacity(0.07),
                  height: 28),

              // Info grid — matches web's detail columns
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _buildInfoItem(
                      Icons.alternate_email,
                      email.isNotEmpty ? email : 'No email',
                      isDark),
                  if (phone != null)
                    _buildInfoItem(Icons.phone_outlined, phone, isDark),
                  if (church != null)
                    _buildInfoItem(
                        Icons.location_on_outlined, church, isDark),
                  if (dateOfBirth != null)
                    _buildInfoItem(Icons.cake_outlined,
                        dateOfBirth.toString().length >= 10
                            ? dateOfBirth.toString().substring(0, 10)
                            : dateOfBirth.toString(),
                        isDark),
                  if (workSchool != null)
                    _buildInfoItem(
                        Icons.work_outline, workSchool, isDark),
                  if (maritalStatus != null)
                    _buildInfoItem(
                      Icons.favorite_outline,
                      hasChildren
                          ? '$maritalStatus ($childrenCount kids)'
                          : maritalStatus,
                      isDark,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Decorative corner blob (matches web's absolute top-right circle)
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).scale(
        begin: const Offset(0.98, 0.98));
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.notoSansEthiopic(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12, color: AppColors.primary.withOpacity(0.55)),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.notoSansEthiopic(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark
                ? Colors.white70
                : AppColors.lightText.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Stats Grid — with decorative corner element
  // ─────────────────────────────────────────────
  Widget _buildStatsGrid(
      BuildContext context, DashboardStats stats, bool isDark) {
    final items = [
      {
        'title': 'Total Members',
        'value': stats.totalMembers.toString(),
        'icon': FontAwesomeIcons.users,
        'color': AppColors.primary,
      },
      {
        'title': 'Announcements',
        'value': stats.activeAnnouncements.toString(),
        'icon': FontAwesomeIcons.bullhorn,
        'color': AppColors.divineGold,
      },
      {
        'title': 'Pending Reports',
        'value': stats.pendingReports.toString(),
        'icon': FontAwesomeIcons.fileLines,
        'color': AppColors.sacredRed,
      },
      {
        'title': 'Meetings',
        'value': stats.upcomingMeetings.toString(),
        'icon': FontAwesomeIcons.peopleGroup,
        'color': const Color(0xFF9C27B0),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStatCard(
          context,
          title: item['title'] as String,
          value: item['value'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          isDark: isDark,
          animDelay: index * 80,
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    int animDelay = 0,
  }) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 8,
                    color: isDark
                        ? Colors.white54
                        : AppColors.lightText.withOpacity(0.55),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Decorative corner circle (matches web StatCard)
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: animDelay))
        .moveY(begin: 10);
  }

  // ─────────────────────────────────────────────
  // Section headers
  // ─────────────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, String title,
      Color textColor, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FaIcon(icon, size: 13, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.notoSansEthiopic(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).moveX(begin: -5);
  }

  Widget _buildSectionHeaderWithViewAll(BuildContext context, String title,
      Color textColor, IconData icon, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionHeader(context, title, textColor, icon),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            children: [
              Text(
                'View All',
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward,
                  size: 12, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Quick Actions — tall cards matching web style
  // ─────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      {
        'page': const ReportsPage(),
        'icon': FontAwesomeIcons.fileSignature,
        'title': 'Submit Report',
        'desc': 'Track & monitor progress',
        'color': AppColors.primary,
      },
      {
        'page': const MembersPage(),
        'icon': FontAwesomeIcons.users,
        'title': 'Members',
        'desc': 'Manage church members',
        'color': AppColors.divineGold,
      },
      {
        'page': const AnnouncementsPage(),
        'icon': FontAwesomeIcons.bullhorn,
        'title': 'Alerts',
        'desc': 'Latest church updates',
        'color': AppColors.sacredRed,
      },
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(actions.length, (index) {
        final action = actions[index];
        final color = action['color'] as Color;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: index < actions.length - 1 ? 10 : 0),
            child: _buildQuickActionCard(
              context,
              page: action['page'] as Widget,
              icon: action['icon'] as IconData,
              title: action['title'] as String,
              desc: action['desc'] as String,
              color: color,
              isDark: isDark,
              animDelay: index * 80,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required Widget page,
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
    int animDelay = 0,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(22),
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container — matches web hover color-fill effect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 9,
                  color: isDark
                      ? Colors.white54
                      : AppColors.lightText.withOpacity(0.55),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: animDelay))
        .moveY(begin: 10);
  }

  // ─────────────────────────────────────────────
  // List sections
  // ─────────────────────────────────────────────
  Widget _buildRecentAnnouncements(BuildContext context,
      List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _buildEmptyState('No recent announcements');
    return Column(
      children: items
          .map((item) => _buildItemCard(
                context,
                title: item['title'] ?? 'Untitled',
                subtitle: item['content'] ?? '',
                icon: Icons.campaign_outlined,
                isDark: isDark,
              ))
          .toList(),
    );
  }

  Widget _buildUpcomingMeetings(BuildContext context,
      List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _buildEmptyState('No upcoming meetings');
    return Column(
      children: items
          .map((item) => _buildItemCard(
                context,
                title: item['title'] ?? 'Meeting',
                subtitle: item['scheduledDate'] ?? 'Date TBD',
                icon: Icons.calendar_today_outlined,
                isDark: isDark,
              ))
          .toList(),
    );
  }

  Widget _buildRecentReports(BuildContext context,
      List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _buildEmptyState('No recent reports');
    return Column(
      children: items
          .map((item) => _buildItemCard(
                context,
                title: item['planName'] ?? 'Report',
                subtitle: item['option'] ?? '',
                icon: Icons.description_outlined,
                isDark: isDark,
                badge: item['option'],
              ))
          .toList(),
    );
  }

  Widget _buildItemCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            Icon(Icons.arrow_forward_ios,
                size: 12,
                color: isDark ? Colors.white30 : Colors.grey[400]),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.02);
  }

  // ─────────────────────────────────────────────
  // Empty state — dashed border style (matches web)
  // ─────────────────────────────────────────────
  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          // Flutter doesn't support dashed natively; we use a solid thin border
          // with low opacity to approximate the web's dashed look
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 40, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            message.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.lightText.withOpacity(0.3),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
