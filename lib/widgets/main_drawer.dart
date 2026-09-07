import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/permission_service.dart';
import '../services/remote_config_service.dart';
import '../services/software_control_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../screens/dashboard_items/announcements_page.dart';
import '../screens/dashboard_items/plans_page.dart';
import '../screens/dashboard_items/reports_page.dart';
import '../screens/dashboard_items/members_page.dart';
import '../screens/dashboard_items/meetings_page.dart';
import '../screens/dashboard_items/finance_page.dart';
import '../screens/dashboard_items/church_rules_page.dart';
import '../screens/dashboard_items/hige_denb_page.dart';
import '../screens/dashboard_items/missionary_page.dart';
import '../screens/dashboard_items/teachings_page.dart';
import '../screens/dashboard_items/strategic_plan_page.dart';
import '../screens/dashboard_items/partner_page.dart';
import '../screens/dashboard_items/volunteer_page.dart';
import '../screens/dashboard_items/documents_page.dart';
import '../screens/dashboard_items/notifications_page.dart';
import '../screens/dashboard_items/settings_page.dart';
import '../screens/dashboard_items/user_management_page.dart';
import '../screens/dashboard_items/hierarchy_page.dart';
import '../screens/dashboard_items/permission_control_page.dart';

class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  // Track which page is currently active by its title
  String _activePage = 'Dashboard';

  // English title → translation catalog key (display only; identity stays English)
  static const _titleKeys = {
    'Dashboard': 'dashboard',
    'Announcements': 'announcements',
    'Plans': 'plans',
    'Reports': 'reports',
    'Members': 'members',
    'Meetings': 'meetings',
    'Finance': 'finance',
    'Church Rules': 'churchRules',
    'Hige Denb': 'higeDenb',
    'Missionary': 'missionary',
    'Teachings': 'teachings',
    'Strategic Plan': 'strategicPlan',
    'Volunteer': 'volunteer',
    'Documents': 'documents',
    'Notifications': 'notifications',
    'User Management': 'userManagement',
    'Hierarchy': 'hierarchy',
    'Settings': 'settings',
  };

  void _navigateTo(BuildContext context, String title, Widget? page) {
    setState(() => _activePage = title);
    Navigator.pop(context); // Close drawer
    if (page != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ).then((_) {
        // Reset active page to Dashboard when returning
        if (mounted) setState(() => _activePage = 'Dashboard');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = Provider.of<AuthService>(context).user;
    final authService = Provider.of<AuthService>(context);
    final perms = Provider.of<PermissionService>(context);

    final remoteConfig = Provider.of<RemoteConfigService>(context);
    final softwareControl = Provider.of<SoftwareControlService>(context);
    final level = authService.userModel?.hierarchyLevel ?? 'HiyawanMahderat';

    // Permission-gated nav items (featureKey lets the web admin disable
    // modules remotely via Mobile App Control)
    final navItems = [
      const _NavItem(FontAwesomeIcons.house,             'Dashboard',      null,                          null, null),
      const _NavItem(FontAwesomeIcons.bullhorn,          'Announcements',  AnnouncementsPage(),     'canViewAnnouncements', 'announcements'),
      const _NavItem(FontAwesomeIcons.fileLines,         'Plans',          PlansPage(),             'canViewPlans', 'plans'),
      const _NavItem(FontAwesomeIcons.calendarCheck,     'Reports',        ReportsPage(),           'canViewReports', 'reports'),
      const _NavItem(FontAwesomeIcons.users,             'Members',        MembersPage(),           'canViewMembers', 'members'),
      const _NavItem(FontAwesomeIcons.peopleGroup,       'Meetings',       MeetingsPage(),          'canViewMeetings', 'meetings'),
      const _NavItem(FontAwesomeIcons.handHoldingDollar, 'Finance',        FinancePage(),           'canViewFinance', 'finance'),
      const _NavItem(FontAwesomeIcons.scaleBalanced,     'Church Rules',   ChurchRulesPage(),       'canViewChurchRules', 'churchRules'),
      const _NavItem(FontAwesomeIcons.bookOpen,          'Hige Denb',      HigeDenbPage(),          'canViewHigeDenb', 'higeDenb'),
      const _NavItem(FontAwesomeIcons.globe,             'Missionary',     MissionaryPage(),        'canViewMissionary', 'missionary'),
      const _NavItem(FontAwesomeIcons.bookOpenReader,    'Teachings',      TeachingsPage(),         'canViewTeachings', 'teachings'),
      const _NavItem(FontAwesomeIcons.fileContract,      'Strategic Plan', StrategicPlanPage(),     'canViewStrategicPlan', 'strategicPlan'),
      const _NavItem(FontAwesomeIcons.handshake,         'Partner',        PartnerPage(),           null, 'partner'),
      const _NavItem(FontAwesomeIcons.heartPulse,        'Volunteer',      VolunteerPage(),         'canViewVolunteer', 'volunteer'),
      const _NavItem(FontAwesomeIcons.folderOpen,        'Documents',      DocumentsPage(),         'canViewDocuments', 'documents'),
      const _NavItem(FontAwesomeIcons.solidBell,         'Notifications',  NotificationsPage(),     null, 'notifications'),
    ];

    final adminItems = [
      const _NavItem(FontAwesomeIcons.usersGear,    'User Management', UserManagementPage(),    'canViewUserManagement', 'userManagement'),
      const _NavItem(FontAwesomeIcons.networkWired, 'Hierarchy',       HierarchyPage(),         'canViewHierarchy', 'hierarchy'),
      const _NavItem(FontAwesomeIcons.gear,         'Settings',        SettingsPage(),          'canViewSettings', null),
      const _NavItem(FontAwesomeIcons.shieldHalved, 'Permissions',     PermissionControlPage(), 'superAdminOnly', 'permissionControl'),
    ];

    // Remote kill-switch per module (Mobile App Control) AND role-based nav
    // access set on the web (Software Control) both hide an entry.
    bool featureOn(_NavItem i) =>
        i.featureKey == null || remoteConfig.isEnabled(i.featureKey!);
    bool navOn(_NavItem i) =>
        i.featureKey == null ||
        softwareControl.navAllowed(i.featureKey!, level, perms.isSuperAdmin);

    final visibleNav = navItems
        .where((i) =>
            featureOn(i) &&
            navOn(i) &&
            (i.permission == null || perms.can(i.permission!)))
        .toList();
    final visibleAdmin = adminItems
        .where((i) {
          if (!featureOn(i) || !navOn(i)) return false;
          if (i.permission == 'superAdminOnly') return perms.isSuperAdmin;
          return i.permission == null || perms.can(i.permission!);
        })
        .toList();

    return Drawer(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Column(
        children: [
          _buildHeader(context, user, isDark),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...visibleNav.map((item) => _buildNavItem(
                      context,
                      icon: item.icon,
                      title: item.title,
                      page: item.page,
                      isDark: isDark,
                    )),
                if (visibleAdmin.isNotEmpty) ...[
                  Divider(
                    color: AppColors.primary.withOpacity(0.1),
                    indent: 16,
                    endIndent: 16,
                  ),
                  ...visibleAdmin.map((item) => _buildNavItem(
                        context,
                        icon: item.icon,
                        title: item.title,
                        page: item.page,
                        isDark: isDark,
                      )),
                ],
              ],
            ),
          ),
          _buildLogoutButton(context, authService, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user, bool isDark) {
    final authService = Provider.of<AuthService>(context);
    final userModel = authService.userModel;

    // Use the richest available name
    final name = userModel?.fullNameAmharic ??
        userModel?.fullNameEnglish ??
        userModel?.fullName ??
        user?.email?.split('@')[0] ??
        'User';
    final role = userModel?.role ?? 'Member';
    final level = userModel?.hierarchyLevel ?? 'Atbiya';
    final email = userModel?.email ?? user?.email ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(isDark ? 0.1 : 0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with initials
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: (userModel?.profilePicture != null && userModel!.profilePicture!.isNotEmpty)
                    ? Image.network(
                        userModel.profilePicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            _getInitials(name),
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _getInitials(name),
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 9,
                        color: isDark
                            ? Colors.white54
                            : AppColors.lightText.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Badges row
          Row(
            children: [
              _buildHeaderBadge(level, AppColors.primary),
              const SizedBox(width: 6),
              _buildHeaderBadge(role, AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 10),
          // Pro badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user,
                    size: 10, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'MAHIBERE AHAW PRO',
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
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.notoSansEthiopic(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? page,
    required bool isDark,
  }) {
    final isActive = _activePage == title;
    final loc = Provider.of<LocalizationService>(context);
    final displayTitle =
        _titleKeys.containsKey(title) ? loc.t(_titleKeys[title]!) : title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateTo(context, title, page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(
                    icon,
                    size: 12,
                    color: isActive
                        ? Colors.white
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.lightText),
                      letterSpacing: isActive ? 0.2 : 0,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
      BuildContext context, AuthService authService, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: InkWell(
        onTap: () => authService.signOut(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.sacredRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sacredRed.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: AppColors.sacredRed, size: 18),
              const SizedBox(width: 10),
              Text(
                Provider.of<LocalizationService>(context)
                    .t('logout')
                    .toUpperCase(),
                style: GoogleFonts.notoSansEthiopic(
                  color: AppColors.sacredRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple data class for nav items
class _NavItem {
  final IconData icon;
  final String title;
  final Widget? page;
  final String? permission;
  /// Remote feature-flag key (Mobile App Control); null = never disabled.
  final String? featureKey;

  const _NavItem(
      this.icon, this.title, this.page, this.permission, this.featureKey);
}

/// Returns up to 2 initials from a display name
String _getInitials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
