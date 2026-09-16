import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/member_service.dart';
import '../../services/membership_requests_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';
import 'membership_requests_page.dart';
import 'mahderat_manager_page.dart';

/// Parish console for a congregation admin: shows the parish, its member and
/// pending-request counts, and quick links into the already-scoped Members,
/// Membership Requests, and Fellowship Groups screens.
class MyAtbiyaPage extends StatefulWidget {
  const MyAtbiyaPage({super.key});

  @override
  State<MyAtbiyaPage> createState() => _MyAtbiyaPageState();
}

class _MyAtbiyaPageState extends State<MyAtbiyaPage>
    with SingleTickerProviderStateMixin {
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final _memberService = MemberService();
  final _requestsService = MembershipRequestsService();
  int? _memberCount;
  int? _pendingCount;
  bool _loading = true;

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';
  List<Map<String, dynamic>> _members = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadCounts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
          _members = members;
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
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).userModel;
    final perms = Provider.of<PermissionService>(context, listen: false);
    final parishName = user?.atbiyaName ?? loc.t('admin.myCongregationTitle');

    return DashboardScaffold(
      titleKey: 'nav.myAtbiya',
      moduleKey: 'myAtbiya',
      constrainWidth: false,
      actions: [
        IconButton(
            onPressed: _loadCounts,
            icon: const Icon(Icons.refresh, color: AppColors.primary)),
      ],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900, fontSize: 12),
        tabs: [
          Tab(text: loc.t('admin.tabRequests')),
          Tab(text: loc.t('admin.tabMembers')),
          Tab(text: loc.t('admin.tabMahderat')),
          Tab(text: loc.t('admin.tabDetails')),
        ],
      ),
      body: Column(
        children: [
          _header(parishName, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _requestsTab(perms, user?.hierarchyLevel, isDark),
                _membersTab(isDark),
                _mahderatTab(user, perms, isDark),
                _detailsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The parish banner and its two counts, above the tabs.
  Widget _header(String parishName, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.7)
            ]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Icon(Icons.church, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.t('admin.congregationBadge').toUpperCase(),
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white70,
                            letterSpacing: 1)),
                    Text(parishName,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ]),
            ),
            _headerCount(loc.t('admin.tabMembers'), _memberCount),
            const SizedBox(width: 14),
            _headerCount(loc.t('admin.statusPending'), _pendingCount),
          ]),
        ).animate().fadeIn(),
      ]),
    );
  }

  Widget _headerCount(String label, int? value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loading ? '—' : '${value ?? 0}',
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text(label.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white70)),
        ],
      );

  /// Requests, or an explanation when this role cannot decide them — the same
  /// split the web makes in MyAtbiya.tsx rather than hiding the tab.
  Widget _requestsTab(PermissionService perms, String? level, bool isDark) {
    final registry =
        Provider.of<RoleRegistryService>(context, listen: false);
    final mayDecide = perms.isSuperAdmin ||
        perms.can('canApproveMembers') ||
        registry.isApproverRole(level);
    if (!mayDecide) {
      return _notice(loc.t('admin.notApprover'),
          loc.t('admin.notApproverDesc'), Icons.person_add_alt, isDark);
    }
    return const MembershipRequestsPage(embedded: true);
  }

  Widget _membersTab(bool isDark) {
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _members
        : _members.where((m) {
            final hay = [
              m['fullNameEnglish'],
              m['fullNameAmharic'],
              m['fullName'],
              m['username'],
              m['phone'],
            ].whereType<String>().join(' ').toLowerCase();
            return hay.contains(q);
          }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: loc.t('admin.searchMembers'),
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      if (_loading)
        const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else if (filtered.isEmpty)
        Expanded(
          child: _notice(
              _members.isEmpty
                  ? loc.t('admin.noMembersYet')
                  : loc.t('admin.noMemberMatch'),
              _members.isEmpty
                  ? loc.t('admin.noMembersYetDesc')
                  : loc.t('admin.noMemberMatchDesc'),
              Icons.people_outline,
              isDark),
        )
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _memberRow(filtered[i], isDark),
          ),
        ),
    ]);
  }

  Widget _memberRow(Map<String, dynamic> m, bool isDark) {
    final name = m['fullNameEnglish'] ??
        m['fullName'] ??
        m['username'] ??
        loc.t('admin.member');
    final status = (m['status'] as String?) ?? 'active';
    final statusColor = status == 'active'
        ? AppColors.success
        : status == 'pending'
            ? AppColors.divineGold
            : Colors.grey;
    final sub = [
      if ((m['username'] ?? '').toString().isNotEmpty) '@${m['username']}',
      if ((m['phone'] ?? '').toString().isNotEmpty) m['phone'],
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10, color: Colors.grey)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Text(status,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: statusColor)),
        ),
      ]),
    );
  }

  Widget _mahderatTab(dynamic user, PermissionService perms, bool isDark) {
    final atbiyaId = (user?.atbiyaId ?? '') as String;
    if (atbiyaId.isEmpty) {
      return _notice(loc.t('admin.noCongregationsForMahderat'), '',
          Icons.groups_outlined, isDark);
    }
    return MahderatManagerScreen(
      atbiyaId: atbiyaId,
      atbiyaName: user?.atbiyaName ?? '',
      // The same gate the stub used, which mirrors isOwnAtbiyaEditor() in
      // firestore.rules — a parish leader maintains its own groups.
      canEdit: perms.isSuperAdmin ||
          perms.can('canEditOwnAtbiya') ||
          perms.can('canManageAtbiyas'),
      embedded: true,
    );
  }

  /// Read-only for now. The parish record spans two collections — the public
  /// fields in `hierarchy`, and `contact`/`bankAccounts`/`lat`/`lng` in
  /// `atbiyaPrivate`, because /hierarchy is readable by anonymous visitors and
  /// firestore.rules refuses any hierarchy write that touches those keys. An
  /// editor has to write both, so it is deliberately not bolted on here.
  Widget _detailsTab(bool isDark) {
    return _notice(loc.t('admin.tabDetails'),
        loc.t('admin.detailsPublicNote'), Icons.church_outlined, isDark);
  }

  Widget _notice(String title, String body, IconData icon, bool isDark) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.lightText)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 12, color: Colors.grey, height: 1.5)),
            ],
          ]),
        ),
      );

}
