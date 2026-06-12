import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_permissions.dart';

// ─── Hierarchy levels and their display colors ────────────────────────────────

const _levels = [
  'Sinodos', 'KuamiSinodos', 'Memriya', 'Zone',
  'Atbiya', 'EnkesekaseMaikel', 'HiyawanMahderat',
];

const _levelColors = {
  'Sinodos':          Color(0xFF6366F1),
  'KuamiSinodos':     Color(0xFF3B82F6),
  'Memriya':          Color(0xFF10B981),
  'Zone':             Color(0xFFF59E0B),
  'Atbiya':           Color(0xFFF97316),
  'EnkesekaseMaikel': Color(0xFFEF4444),
  'HiyawanMahderat':  Color(0xFF6B7280),
};

// ─── Permission groups (same order as web) ────────────────────────────────────

const _permissionGroups = [
  'Pages', 'Announcements', 'Plans', 'Reports', 'Members',
  'Meetings', 'Finance', 'Documents', 'Teachings', 'Missionary', 'Dashboard',
];

const _permissionMeta = {
  // Pages
  'canViewDashboard':       ('View Dashboard',           'Access the main dashboard',                    'Pages'),
  'canViewAnnouncements':   ('View Announcements',       'See the announcements page',                   'Pages'),
  'canViewPlans':           ('View Plans',               'See the plans & ministry page',                'Pages'),
  'canViewReports':         ('View Reports',             'See the reports page',                         'Pages'),
  'canViewMembers':         ('View Members',             'See the members directory',                    'Pages'),
  'canViewMeetings':        ('View Meetings',            'See the meetings page',                        'Pages'),
  'canViewFinance':         ('View Finance',             'See the finance page',                         'Pages'),
  'canViewChurchRules':     ('View Church Rules',        'See the church rules page',                    'Pages'),
  'canViewHigeDenb':        ('View HigeDenb',            'See the HigeDenb page',                        'Pages'),
  'canViewStrategicPlan':   ('View Strategic Plan',      'See the strategic plan page',                  'Pages'),
  'canViewDocuments':       ('View Documents',           'See the documents page',                       'Pages'),
  'canViewHierarchy':       ('View Hierarchy',           'See the church hierarchy page',                'Pages'),
  'canViewMissionary':      ('View Missionary',          'See the missionary page',                      'Pages'),
  'canViewTeachings':       ('View Teachings',           'See the teachings page',                       'Pages'),
  'canViewVolunteer':       ('View Volunteer',           'See the volunteer page',                       'Pages'),
  'canViewUserManagement':  ('View User Management',     'See the user management page',                 'Pages'),
  'canViewSettings':        ('View Settings',            'Access settings',                              'Pages'),
  'canViewNotifications':   ('View Notifications',       'See notifications',                            'Pages'),
  // Announcements
  'canCreateAnnouncement':  ('Create Announcement',      'Post new announcements',                       'Announcements'),
  'canEditAnnouncement':    ('Edit Announcement',        'Edit existing announcements',                  'Announcements'),
  'canDeleteAnnouncement':  ('Delete Announcement',      'Delete announcements',                         'Announcements'),
  // Plans
  'canCreatePlan':          ('Create Plan',              'Create new ministry plans',                    'Plans'),
  'canDeletePlan':          ('Delete Plan',              'Delete ministry plans',                        'Plans'),
  // Reports
  'canCreateReport':        ('Create Report',            'Submit new reports',                           'Reports'),
  'canViewAllReports':      ('View All Reports',         'See reports from all units',                   'Reports'),
  'canCommentOnReport':     ('Comment on Report',        'Add feedback to reports',                      'Reports'),
  // Members
  'canAddMembers':          ('Add Members',              'Enroll new church members',                    'Members'),
  'canEditMembers':         ('Edit Members',             'Edit member profiles',                         'Members'),
  'canDeleteMembers':       ('Delete Members',           'Remove members from the system',               'Members'),
  'canExportData':          ('Export Data',              'Export member and report data',                'Members'),
  // Meetings
  'canScheduleMeeting':     ('Schedule Meeting',         'Create new meetings',                          'Meetings'),
  'canDeleteMeeting':       ('Delete Meeting',           'Delete scheduled meetings',                    'Meetings'),
  // Finance
  'canAddTransaction':      ('Add Transaction',          'Record financial transactions',                'Finance'),
  'canCreateBudget':        ('Create Budget',            'Create monthly budgets',                       'Finance'),
  'canGenerateFinancialReport': ('Generate Financial Report', 'Generate financial reports',             'Finance'),
  // Documents
  'canUploadDocuments':     ('Upload Documents',         'Upload files and create folders',              'Documents'),
  'canDeleteDocuments':     ('Delete Documents',         'Delete files and folders',                     'Documents'),
  // Teachings
  'canCreateTeaching':      ('Create Teaching',          'Publish new teachings',                        'Teachings'),
  // Missionary
  'canSubmitMissionaryApplication': ('Submit Missionary Application', 'Apply for missionary service',   'Missionary'),
  'canSubmitMissionaryReport':      ('Submit Missionary Report',      'Submit field reports',           'Missionary'),
  // Dashboard
  'canViewFullDashboard':   ('Full Dashboard View',      'See all stats and quick actions',              'Dashboard'),
  'canViewLimitedDashboard':('Limited Dashboard View',   'See basic stats only',                         'Dashboard'),
};

// ─── Main Page ────────────────────────────────────────────────────────────────

class PermissionControlPage extends StatefulWidget {
  const PermissionControlPage({super.key});

  @override
  State<PermissionControlPage> createState() => _PermissionControlPageState();
}

class _PermissionControlPageState extends State<PermissionControlPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;

  // State mirrors web exactly
  Map<String, List<String>> _roleOverrides = {};
  Map<String, Map<String, bool>> _userOverrides = {};
  List<String> _superAdminUids = [];
  List<Map<String, dynamic>> _users = [];

  bool _loading = true;
  bool _saving = false;
  String _saveStatus = 'idle'; // idle | success | error

  // UI state
  String _userSearch = '';
  Map<String, dynamic>? _selectedUser;
  final Set<String> _expandedGroups = Set.from(_permissionGroups);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load from Firestore (same collections as web) ─────────────────────────

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.collection('siteConfig').doc('rolePermissions').get(),
        _db.collection('siteConfig').doc('userPermissionOverrides').get(),
        _db.collection('siteConfig').doc('superAdmins').get(),
        _db.collection('users').get(),
      ]);

      // Role overrides
      final roSnap = results[0] as DocumentSnapshot;
      if (roSnap.exists && roSnap.data() != null) {
        final data = roSnap.data() as Map<String, dynamic>;
        final ro = <String, List<String>>{};
        for (final e in data.entries) {
          if (e.key == '_meta') continue;
          if (e.value is List) ro[e.key] = List<String>.from(e.value as List);
        }
        _roleOverrides = ro;
      }

      // User overrides
      final uoSnap = results[1] as DocumentSnapshot;
      if (uoSnap.exists && uoSnap.data() != null) {
        final data = uoSnap.data() as Map<String, dynamic>;
        final uo = <String, Map<String, bool>>{};
        for (final e in data.entries) {
          if (e.key == '_meta') continue;
          if (e.value is Map) {
            uo[e.key] = Map<String, bool>.from(
              (e.value as Map).map((k, v) => MapEntry(k.toString(), v as bool)),
            );
          }
        }
        _userOverrides = uo;
      }

      // Super admins
      final saSnap = results[2] as DocumentSnapshot;
      if (saSnap.exists && saSnap.data() != null) {
        final uids = (saSnap.data() as Map<String, dynamic>)['uids'];
        if (uids is List) _superAdminUids = List<String>.from(uids);
      }

      // Users
      final usersSnap = results[3] as QuerySnapshot;
      _users = usersSnap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('[PermissionControl] Load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Save to Firestore ─────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    setState(() { _saving = true; _saveStatus = 'idle'; });
    final currentUser = Provider.of<AuthService>(context, listen: false).userModel;
    final updatedBy = currentUser?.email ?? 'admin';
    final now = DateTime.now().toIso8601String();

    try {
      await Future.wait([
        _db.collection('siteConfig').doc('rolePermissions').set({
          ..._roleOverrides,
          '_meta': {'updatedAt': now, 'updatedBy': updatedBy},
        }),
        _db.collection('siteConfig').doc('userPermissionOverrides').set({
          ..._userOverrides,
          '_meta': {'updatedAt': now, 'updatedBy': updatedBy},
        }),
        _db.collection('siteConfig').doc('superAdmins').set({
          'uids': _superAdminUids,
          '_meta': {'updatedAt': now, 'updatedBy': updatedBy},
        }),
      ]);

      // Reload permissions for current session
      if (mounted) {
        final perms = Provider.of<PermissionService>(context, listen: false);
        final auth = Provider.of<AuthService>(context, listen: false);
        if (auth.userModel != null) {
          await perms.loadForUser(
            userId: auth.userModel!.id,
            hierarchyLevel: auth.userModel!.hierarchyLevel,
            role: auth.userModel!.role,
          );
        }
      }

      setState(() => _saveStatus = 'success');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saveStatus = 'idle');
      });
    } catch (e) {
      setState(() => _saveStatus = 'error');
      debugPrint('[PermissionControl] Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Role permission helpers ───────────────────────────────────────────────

  Set<String> _getRolePerms(String level) {
    return Set<String>.from(
      _roleOverrides[level] ?? defaultRolePermissions[level] ?? [],
    );
  }

  void _toggleRolePerm(String level, String perm) {
    final current = _getRolePerms(level);
    if (current.contains(perm)) { current.remove(perm); }
    else { current.add(perm); }
    setState(() => _roleOverrides[level] = current.toList());
  }

  void _resetRoleToDefault(String level) {
    setState(() => _roleOverrides.remove(level));
  }

  // ── User override helpers ─────────────────────────────────────────────────

  bool? _getUserPerm(String userId, String perm) {
    return _userOverrides[userId]?[perm];
  }

  void _setUserPerm(String userId, String perm, bool? value) {
    setState(() {
      final entry = Map<String, bool>.from(_userOverrides[userId] ?? {});
      if (value == null) { entry.remove(perm); }
      else { entry[perm] = value; }
      if (entry.isEmpty) { _userOverrides.remove(userId); }
      else { _userOverrides[userId] = entry; }
    });
  }

  void _clearUserOverrides(String userId) {
    setState(() => _userOverrides.remove(userId));
  }

  // ── Super admin helpers ───────────────────────────────────────────────────

  void _toggleSuperAdmin(String userId) {
    setState(() {
      if (_superAdminUids.contains(userId)) {
        _superAdminUids.remove(userId);
      } else {
        _superAdminUids.add(userId);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text('Permission Control',
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.lightText)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAll,
              icon: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Saving…' : 'Save All',
                  style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.notoSansEthiopic(fontSize: 11),
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.shield_outlined, size: 16), text: 'Roles'),
            Tab(icon: Icon(Icons.person_outline, size: 16), text: 'Users'),
            Tab(icon: Icon(Icons.star_outline, size: 16), text: 'SuperAdmin'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Save status banner
                if (_saveStatus == 'success')
                  const _StatusBanner(
                    color: AppColors.success,
                    icon: Icons.check_circle_outline,
                    message: 'Changes saved and applied to all users immediately.',
                  ),
                if (_saveStatus == 'error')
                  const _StatusBanner(
                    color: AppColors.sacredRed,
                    icon: Icons.error_outline,
                    message: 'Failed to save. Check your connection.',
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _RolePermissionsTab(
                        isDark: isDark,
                        roleOverrides: _roleOverrides,
                        expandedGroups: _expandedGroups,
                        getRolePerms: _getRolePerms,
                        toggleRolePerm: _toggleRolePerm,
                        resetRoleToDefault: _resetRoleToDefault,
                        onToggleGroup: (g) => setState(() {
                          if (_expandedGroups.contains(g)) { _expandedGroups.remove(g); }
                          else { _expandedGroups.add(g); }
                        }),
                      ),
                      _UserOverridesTab(
                        isDark: isDark,
                        users: _users,
                        userSearch: _userSearch,
                        selectedUser: _selectedUser,
                        userOverrides: _userOverrides,
                        superAdminUids: _superAdminUids,
                        getRolePerms: _getRolePerms,
                        getUserPerm: _getUserPerm,
                        setUserPerm: _setUserPerm,
                        clearUserOverrides: _clearUserOverrides,
                        onSearchChanged: (v) => setState(() => _userSearch = v),
                        onUserSelected: (u) => setState(() => _selectedUser = u),
                      ),
                      _SuperAdminTab(
                        isDark: isDark,
                        users: _users,
                        superAdminUids: _superAdminUids,
                        onToggle: _toggleSuperAdmin,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Tab 1: Role Permissions ──────────────────────────────────────────────────

class _RolePermissionsTab extends StatelessWidget {
  final bool isDark;
  final Map<String, List<String>> roleOverrides;
  final Set<String> expandedGroups;
  final Set<String> Function(String) getRolePerms;
  final void Function(String, String) toggleRolePerm;
  final void Function(String) resetRoleToDefault;
  final void Function(String) onToggleGroup;

  const _RolePermissionsTab({
    required this.isDark,
    required this.roleOverrides,
    required this.expandedGroups,
    required this.getRolePerms,
    required this.toggleRolePerm,
    required this.resetRoleToDefault,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Set which permissions each hierarchy level has by default. These apply to all users at that level unless overridden individually.',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : AppColors.lightText.withOpacity(0.7),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // For each permission group
          ..._permissionGroups.map((group) {
            final groupPerms = allPermissions
                .where((p) => _permissionMeta[p]?.$3 == group)
                .toList();
            if (groupPerms.isEmpty) return const SizedBox.shrink();
            final isExpanded = expandedGroups.contains(group);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  // Group header
                  InkWell(
                    onTap: () => onToggleGroup(group),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(group.toUpperCase(),
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.lightText.withOpacity(0.6))),
                          const Spacer(),
                          Text('${groupPerms.length} permissions',
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 9,
                                  color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  if (isExpanded) ...[
                    Divider(
                        color: AppColors.primary.withOpacity(0.06), height: 1),
                    // Permission rows
                    ...groupPerms.map((perm) {
                      final meta = _permissionMeta[perm];
                      if (meta == null) return const SizedBox.shrink();
                      return _PermissionRow(
                        perm: perm,
                        label: meta.$1,
                        description: meta.$2,
                        isDark: isDark,
                        getRolePerms: getRolePerms,
                        roleOverrides: roleOverrides,
                        toggleRolePerm: toggleRolePerm,
                        resetRoleToDefault: resetRoleToDefault,
                      );
                    }),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divineGold, width: 2),
                ),
              ),
              const SizedBox(width: 8),
              Text('Amber ring = changed from default',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Permission row (one permission × all 7 levels) ──────────────────────────

class _PermissionRow extends StatelessWidget {
  final String perm;
  final String label;
  final String description;
  final bool isDark;
  final Map<String, List<String>> roleOverrides;
  final Set<String> Function(String) getRolePerms;
  final void Function(String, String) toggleRolePerm;
  final void Function(String) resetRoleToDefault;

  const _PermissionRow({
    required this.perm,
    required this.label,
    required this.description,
    required this.isDark,
    required this.roleOverrides,
    required this.getRolePerms,
    required this.toggleRolePerm,
    required this.resetRoleToDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.primary.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permission label + description
          Text(label,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText)),
          Text(description,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 10),

          // Level toggles — horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _levels.map((level) {
                final perms = getRolePerms(level);
                final hasPerm = perms.contains(perm);
                final hasOverride = roleOverrides.containsKey(level);
                final defaultHas = (defaultRolePermissions[level] ?? []).contains(perm);
                final changed = hasOverride && hasPerm != defaultHas;
                final color = _levelColors[level] ?? AppColors.primary;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => toggleRolePerm(level, perm),
                    child: Column(
                      children: [
                        // Level name
                        Text(
                          level.length > 8
                              ? '${level.substring(0, 7)}…'
                              : level,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: color),
                        ),
                        const SizedBox(height: 4),
                        // Toggle chip
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 24,
                          decoration: BoxDecoration(
                            color: hasPerm
                                ? color.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: changed
                                  ? AppColors.divineGold
                                  : (hasPerm
                                      ? color.withOpacity(0.4)
                                      : Colors.grey.withOpacity(0.2)),
                              width: changed ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              hasPerm ? Icons.check : Icons.close,
                              size: 12,
                              color: hasPerm ? color : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: User Overrides ────────────────────────────────────────────────────

class _UserOverridesTab extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> users;
  final String userSearch;
  final Map<String, dynamic>? selectedUser;
  final Map<String, Map<String, bool>> userOverrides;
  final List<String> superAdminUids;
  final Set<String> Function(String) getRolePerms;
  final bool? Function(String, String) getUserPerm;
  final void Function(String, String, bool?) setUserPerm;
  final void Function(String) clearUserOverrides;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onUserSelected;

  const _UserOverridesTab({
    required this.isDark,
    required this.users,
    required this.userSearch,
    required this.selectedUser,
    required this.userOverrides,
    required this.superAdminUids,
    required this.getRolePerms,
    required this.getUserPerm,
    required this.setUserPerm,
    required this.clearUserOverrides,
    required this.onSearchChanged,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = users.where((u) {
      final name = ((u['fullNameEnglish'] ?? u['fullName'] ?? u['username'] ?? '') as String).toLowerCase();
      final email = ((u['email'] ?? '') as String).toLowerCase();
      final q = userSearch.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    if (selectedUser == null) {
      // Show user list
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: GoogleFonts.notoSansEthiopic(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primary, size: 18),
                  hintText: 'Search users…',
                  hintStyle: GoogleFonts.notoSansEthiopic(
                      fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final u = filtered[i];
                final uid = u['id'] as String;
                final hasOverrides =
                    (userOverrides[uid] ?? {}).isNotEmpty;
                final isSA = superAdminUids.contains(uid);
                final level = u['hierarchyLevel'] as String? ?? 'Unknown';
                final color = _levelColors[level] ?? Colors.grey;
                final name = u['fullNameEnglish'] ?? u['fullName'] ?? u['username'] ?? 'User';

                return GestureDetector(
                  onTap: () => onUserSelected(u),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (name as String)[0].toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(name,
                                        style: GoogleFonts.notoSansEthiopic(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.lightText)),
                                  ),
                                  if (isSA)
                                    const Icon(Icons.star,
                                        size: 14, color: AppColors.divineGold),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(level,
                                        style: GoogleFonts.notoSansEthiopic(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: color)),
                                  ),
                                  if (hasOverrides) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.divineGold
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('OVERRIDES',
                                          style: GoogleFonts.notoSansEthiopic(
                                              fontSize: 7,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.divineGold)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Show permission overrides for selected user
    final uid = selectedUser!['id'] as String;
    final level = selectedUser!['hierarchyLevel'] as String? ?? 'HiyawanMahderat';
    final name = selectedUser!['fullNameEnglish'] ??
        selectedUser!['fullName'] ??
        selectedUser!['username'] ??
        'User';
    final color = _levelColors[level] ?? Colors.grey;

    return Column(
      children: [
        // User header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white,
            border: Border(
                bottom: BorderSide(
                    color: AppColors.primary.withOpacity(0.08))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onUserSelected({}),
                child: const Icon(Icons.arrow_back,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text((name as String)[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.lightText)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(level,
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: color)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => clearUserOverrides(uid),
                icon: const Icon(Icons.refresh, size: 14,
                    color: AppColors.sacredRed),
                label: Text('Clear',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        color: AppColors.sacredRed,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Overrides are applied on top of the $level role permissions. '
            'Green = granted, Red = revoked, Grey = inherited from role.',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.grey,
                height: 1.4),
          ),
        ),

        // Permission list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
            children: _permissionGroups.expand((group) {
              final groupPerms = allPermissions
                  .where((p) => _permissionMeta[p]?.$3 == group)
                  .toList();
              if (groupPerms.isEmpty) return <Widget>[];
              return [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: AppColors.primary.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(group.toUpperCase(),
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey)),
                      ),
                      Expanded(
                          child: Divider(
                              color: AppColors.primary.withOpacity(0.1))),
                    ],
                  ),
                ),
                ...groupPerms.map((perm) {
                  final meta = _permissionMeta[perm];
                  if (meta == null) return const SizedBox.shrink();
                  final roleHas = getRolePerms(level).contains(perm);
                  final override = getUserPerm(uid, perm);
                  final effective = override ?? roleHas;

                  Color bgColor;
                  Color borderColor;
                  if (override == true) {
                    bgColor = AppColors.success.withOpacity(0.06);
                    borderColor = AppColors.success.withOpacity(0.2);
                  } else if (override == false) {
                    bgColor = AppColors.sacredRed.withOpacity(0.06);
                    borderColor = AppColors.sacredRed.withOpacity(0.2);
                  } else {
                    bgColor = isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.grey.withOpacity(0.04);
                    borderColor = AppColors.primary.withOpacity(0.08);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: effective
                                ? AppColors.success.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            effective
                                ? Icons.lock_open_outlined
                                : Icons.lock_outline,
                            size: 14,
                            color: effective
                                ? AppColors.success
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta.$1,
                                  style: GoogleFonts.notoSansEthiopic(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightText)),
                              Text(meta.$2,
                                  style: GoogleFonts.notoSansEthiopic(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey)),
                            ],
                          ),
                        ),
                        // Reset override button
                        if (override != null)
                          GestureDetector(
                            onTap: () => setUserPerm(uid, perm, null),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.refresh,
                                  size: 14, color: Colors.grey),
                            ),
                          ),
                        // Toggle switch
                        GestureDetector(
                          onTap: () {
                            final newVal = !effective;
                            // If new value equals role default, remove override
                            setUserPerm(
                                uid, perm, newVal == roleHas ? null : newVal);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 24,
                            decoration: BoxDecoration(
                              color: effective
                                  ? AppColors.primary
                                  : Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              alignment: effective
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ];
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 3: Super Admins ──────────────────────────────────────────────────────

class _SuperAdminTab extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> users;
  final List<String> superAdminUids;
  final void Function(String) onToggle;

  const _SuperAdminTab({
    required this.isDark,
    required this.users,
    required this.superAdminUids,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.divineGold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.divineGold.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, size: 16, color: AppColors.divineGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Super Admin Management',
                          style: GoogleFonts.notoSansEthiopic(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.divineGold)),
                      const SizedBox(height: 4),
                      Text(
                        'Super Admins bypass all permission checks and have full access to everything including this control panel. Assign this role with extreme care.',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : AppColors.lightText.withOpacity(0.7),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Current super admins summary
          if (superAdminUids.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.divineGold.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.divineGold.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: AppColors.divineGold),
                      const SizedBox(width: 6),
                      Text(
                        'Current Super Admins (${superAdminUids.length})',
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: AppColors.divineGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: superAdminUids.map((uid) {
                      final u = users.firstWhere(
                          (x) => x['id'] == uid,
                          orElse: () => {'id': uid});
                      final name = u['fullNameEnglish'] ??
                          u['fullName'] ??
                          u['username'] ??
                          uid;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.divineGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.divineGold.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 10, color: AppColors.divineGold),
                            const SizedBox(width: 5),
                            Text(name,
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.divineGold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // All users list with toggle
          ...users.map((u) {
            final uid = u['id'] as String;
            final isSA = superAdminUids.contains(uid);
            final level = u['hierarchyLevel'] as String? ?? 'Unknown';
            final color = _levelColors[level] ?? Colors.grey;
            final name = u['fullNameEnglish'] ??
                u['fullName'] ??
                u['username'] ??
                'User';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSA
                    ? AppColors.divineGold.withOpacity(0.06)
                    : (isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSA
                      ? AppColors.divineGold.withOpacity(0.3)
                      : AppColors.primary.withOpacity(0.08),
                  width: isSA ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isSA
                          ? AppColors.divineGold.withOpacity(0.15)
                          : color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSA
                          ? const Icon(Icons.star,
                              size: 20, color: AppColors.divineGold)
                          : Text(
                              (name as String)[0].toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: GoogleFonts.notoSansEthiopic(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightText)),
                            ),
                            if (isSA)
                              const Icon(Icons.star,
                                  size: 14, color: AppColors.divineGold),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(level,
                                  style: GoogleFonts.notoSansEthiopic(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: color)),
                            ),
                            const SizedBox(width: 6),
                            Text(u['email'] ?? '',
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 9, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Toggle
                  GestureDetector(
                    onTap: () => onToggle(uid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isSA
                            ? AppColors.divineGold
                            : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: isSA
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;

  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
