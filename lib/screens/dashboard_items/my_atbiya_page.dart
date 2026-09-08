import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/member_service.dart';
import '../../services/membership_requests_service.dart';
import '../../theme/app_colors.dart';
import 'members_page.dart';
import 'membership_requests_page.dart';
import 'hierarchy_page.dart';

/// Parish console for a congregation admin: shows the parish, its member and
/// pending-request counts, and quick links into the already-scoped Members,
/// Membership Requests, and Fellowship Groups screens.
class MyAtbiyaPage extends StatefulWidget {
  const MyAtbiyaPage({super.key});

  @override
  State<MyAtbiyaPage> createState() => _MyAtbiyaPageState();
}

class _MyAtbiyaPageState extends State<MyAtbiyaPage> {
  final _memberService = MemberService();
  final _requestsService = MembershipRequestsService();
  int? _memberCount;
  int? _pendingCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    final scope = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    try {
      final members = await _memberService.getMembersInScope(
          wholeDirectory: scope.wholeDirectory, atbiyaId: scope.atbiyaId);
      final pending = await _requestsService.listPending(
          atbiyaId: scope.wholeDirectory ? null : scope.atbiyaId);
      if (mounted) {
        setState(() {
          _memberCount = members.length;
          _pendingCount = pending.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).userModel;
    final parishName = user?.atbiyaName ?? 'My Parish';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Atbiya',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              onPressed: _loadCounts,
              icon: const Icon(Icons.refresh, color: AppColors.primary)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.7)
              ]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              const Icon(Icons.church, color: Colors.white, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PARISH',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white70,
                              letterSpacing: 1)),
                      Text(parishName,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ]),
              ),
            ]),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _statCard('Members', _memberCount, Icons.people, isDark)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard('Pending', _pendingCount,
                    Icons.hourglass_top, isDark)),
          ]),
          const SizedBox(height: 20),
          _action(context, 'Parish Members',
              'View and manage your congregation', Icons.people_outline,
              const MembersPage(), isDark),
          _action(context, 'Membership Requests',
              'Approve or reject new members', Icons.person_add_alt,
              const MembershipRequestsPage(), isDark),
          _action(context, 'Fellowship Groups',
              'Manage Mahderats under your parish', Icons.groups_outlined,
              const HierarchyPage(), isDark),
        ],
      ),
    );
  }

  Widget _statCard(String label, int? value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 8),
        Text(_loading ? '—' : '${value ?? 0}',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        Text(label.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _action(BuildContext context, String title, String subtitle,
      IconData icon, Widget page, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(title,
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.lightText)),
        subtitle: Text(subtitle,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}
