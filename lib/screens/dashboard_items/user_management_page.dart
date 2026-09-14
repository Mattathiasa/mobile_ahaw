import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/localization_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';
import '../../services/permission_service.dart';
import '../../services/member_service.dart';
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final MemberService _memberService = MemberService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateUserSheet(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final fullNameAmharicCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    String selectedRole = 'user';
    String selectedHierarchyLevel = 'Zone';
    String? selectedHierarchyId;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: loc.t('admin.createNewUser'),
            subtitle: loc.t('admin.addUserDesc'),
            isDark: isDark,
            saving: saving,
            submitLabel: loc.t('admin.createUser'),
            onSubmit: () async {
              if (usernameCtrl.text.isEmpty || fullNameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
              setSheet(() => saving = true);
              try {
                await _memberService.createMember({
                  'username': usernameCtrl.text.trim(),
                  'password': passwordCtrl.text.trim(),
                  'fullName': fullNameCtrl.text.trim(),
                  'fullNameAmharic': fullNameAmharicCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': selectedRole,
                  'hierarchyLevel': selectedHierarchyLevel,
                  'hierarchyEntityId': selectedHierarchyId,
                  'status': 'active',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack(loc.t('admin.userCreated'), success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Username *', isDark),
              buildTextField(usernameCtrl, 'e.g. john.doe', isDark),
              const SizedBox(height: 16),
              buildLabel('Password *', isDark),
              buildTextField(passwordCtrl, loc.t('admin.minChars'), isDark, obscure: true),
              const SizedBox(height: 16),
              buildLabel('Full Name (English) *', isDark),
              buildTextField(fullNameCtrl, 'e.g. John Doe', isDark),
              const SizedBox(height: 16),
              buildLabel('Full Name (Amharic)', isDark),
              buildTextField(fullNameAmharicCtrl, 'e.g. ዮሐንስ ተስፋዬ', isDark),
              const SizedBox(height: 16),
              buildLabel(loc.t('admin.hierarchyLevel'), isDark),
              _buildHierarchyLevelDropdown(selectedHierarchyLevel, (v) => setSheet(() => selectedHierarchyLevel = v!), isDark),
              const SizedBox(height: 16),
              buildLabel('Role', isDark),
              _buildRoleDropdown(selectedRole, (v) => setSheet(() => selectedRole = v!), isDark),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.sacredRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);

    return DashboardScaffold(
      titleKey: 'nav.userManagement',
      moduleKey: 'userManagement',
      constrainWidth: false,
      actions: [
        if (perms.isSuperAdmin || perms.can('canCreateUser'))
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateUserSheet(context),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(loc.t('admin.createNewUser'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.12))),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20), hintText: loc.t('admin.searchUsersByName'), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(loc.t('errors.generic')));

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final uname = (data['username'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || uname.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    final id = filtered[index].id;
                    return _buildUserCard(id, data, isDark, perms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String id, Map<String, dynamic> data, bool isDark, PermissionService perms) {
    final fullName = data['fullName'] ?? loc.t('admin.member');
    final role = data['role'] ?? 'user';
    final level = data['hierarchyLevel'] ?? 'Member';
    final username = data['username'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(fullName[0].toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fullName, style: GoogleFonts.notoSansEthiopic(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText)),
              const SizedBox(height: 2),
              Text('@$username', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600])),
              const SizedBox(height: 6),
              Row(children: [
                _buildBadge(level.toUpperCase(), AppColors.primary),
                const SizedBox(width: 6),
                _buildBadge(role.toUpperCase(), AppColors.divineGold),
              ]),
            ]),
          ),
          if (perms.isSuperAdmin || perms.can('canDeleteUser'))
            IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: () => _showUserOptions(id, data)),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
  );

  void _showUserOptions(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(ctx).canvasColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(loc.t('admin.editUser')), onTap: () => Navigator.pop(ctx)),
            ListTile(leading: const Icon(Icons.block, color: AppColors.sacredRed), title: Text(loc.t('admin.suspend'), style: const TextStyle(color: AppColors.sacredRed)), onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(id, data['fullName']);
            }),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('admin.suspendAccount')),
        content: Text(loc.t('admin.suspendAccountDesc',
            {'name': name ?? loc.t('admin.member')})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('common.cancel'))),
          TextButton(onPressed: () async {
            await _memberService.suspendMember(id);
            if (ctx.mounted) Navigator.pop(ctx);
            _showSnack(loc.t('admin.suspended'), success: true);
          }, child: Text(loc.t('admin.suspend'), style: const TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
    const SizedBox(height: 16),
    Text(loc.t('admin.noUsersFound').toUpperCase(), style: GoogleFonts.notoSansEthiopic(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey.withValues(alpha: 0.5))),
  ]));

  Widget _buildHierarchyLevelDropdown(String value, ValueChanged<String?> onChanged, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.12))),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, items: ['Sinodos', 'Memriya', 'Zone', 'Atbiya', 'HiyawanMahderat'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: onChanged, isExpanded: true)),
  );

  Widget _buildRoleDropdown(String value, ValueChanged<String?> onChanged, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.12))),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, items: ['user', 'admin', 'moderator', 'super_admin'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: onChanged, isExpanded: true)),
  );
}
