import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/member_service.dart';
import '../../services/membership_requests_service.dart';
import '../../services/org_unit_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;
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

  final _org = OrgUnitService();
  OrgUnit? _parish;
  Map<String, dynamic> _parishPrivate = const {};
  bool _detailsLoading = true;
  bool _savingDetails = false;
  String? _detailsError;

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';
  List<Map<String, dynamic>> _members = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadCounts();
    _loadParish();
  }

  /// Reads both halves of the congregation record — the public document and,
  /// where the reader is allowed it, the private one.
  Future<void> _loadParish() async {
    final id =
        Provider.of<AuthService>(context, listen: false).userModel?.atbiyaId ??
            '';
    if (id.isEmpty) {
      if (mounted) setState(() => _detailsLoading = false);
      return;
    }
    try {
      final unit = await _org.getById(id);
      final private = await _org.getAtbiyaPrivate(id);
      if (mounted) {
        setState(() {
          _parish = unit;
          _parishPrivate = private;
          _detailsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _detailsLoading = false);
    }
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

  /// The congregation record, across both of its documents.
  ///
  /// The public fields live in `hierarchy`; contact, bankAccounts, lat and lng
  /// live in `atbiyaPrivate`, because /hierarchy is readable by anonymous
  /// visitors so the sign-up dropdown works without an account. Saving goes
  /// through OrgUnitService.updateAtbiya, which splits the payload and writes
  /// both in one batch — sending a private key to /hierarchy is refused by the
  /// rules, and would publish a parish leader's phone number if it were not.
  Widget _detailsTab(bool isDark) {
    if (_detailsLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final parish = _parish;
    if (parish == null) {
      return _notice(loc.t('admin.congregationLoadFailed'), '',
          Icons.church_outlined, isDark);
    }

    final perms = Provider.of<PermissionService>(context, listen: false);
    final mayEdit = perms.isSuperAdmin ||
        perms.can('canEditOwnAtbiya') ||
        perms.can('canManageAtbiyas');
    final contact = (_parishPrivate['contact'] as Map?) ?? const {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          mayEdit
              ? loc.t('admin.detailsPublicNote')
              : '${loc.t('admin.detailsPublicNote')} ${loc.t('admin.detailsReadOnly')}',
          style: GoogleFonts.notoSansEthiopic(
              fontSize: 11, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 14),
        if (_detailsError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.sacredRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_detailsError!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.sacredRed)),
          ),
        ],
        _detailRow(loc.t('admin.entityName'), parish.name, isDark),
        _detailRow(loc.t('admin.entityNameAm'), parish.nameAmharic, isDark),
        _detailRow(loc.t('admin.location'), parish.location, isDark),
        _detailRow(loc.t('admin.foundedAt'), parish.foundedAt, isDark),
        _detailRow(loc.t('admin.entityDescription'), parish.description, isDark),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: AppColors.primary.withValues(alpha: 0.15))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.lock_outline,
                size: 13, color: Colors.grey.withValues(alpha: 0.7)),
          ),
          Expanded(child: Divider(color: AppColors.primary.withValues(alpha: 0.15))),
        ]),
        const SizedBox(height: 8),
        Text(loc.t('admin.contactPrivateHint'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 10, color: Colors.grey, height: 1.5)),
        const SizedBox(height: 10),
        _detailRow(loc.t('admin.contactNameEn'), contact['nameEn'] as String?, isDark),
        _detailRow(loc.t('admin.contactNameAm'), contact['nameAm'] as String?, isDark),
        _detailRow(loc.t('admin.phone'), contact['phone'] as String?, isDark),
        _detailRow(loc.t('admin.altPhone'), contact['phone2'] as String?, isDark),
        _detailRow(loc.t('admin.email'), contact['email'] as String?, isDark),
        if (mayEdit) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingDetails ? null : () => _editDetails(parish, contact),
              icon: const Icon(Icons.edit_outlined, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              label: Text(loc.t('admin.edit')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String? value, bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 130,
            child: Text(label.toUpperCase(),
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              (value ?? '').trim().isEmpty ? loc.t('admin.notSet') : value!,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: (value ?? '').trim().isEmpty
                      ? Colors.grey
                      : (isDark ? Colors.white : AppColors.lightText)),
            ),
          ),
        ]),
      );

  Future<void> _editDetails(OrgUnit parish, Map contact) async {
    final nameCtrl = TextEditingController(text: parish.name);
    final nameAmCtrl = TextEditingController(text: parish.nameAmharic ?? '');
    final locationCtrl = TextEditingController(text: parish.location ?? '');
    final foundedCtrl = TextEditingController(text: parish.foundedAt ?? '');
    final descCtrl = TextEditingController(text: parish.description ?? '');
    final cNameEnCtrl =
        TextEditingController(text: (contact['nameEn'] as String?) ?? '');
    final cNameAmCtrl =
        TextEditingController(text: (contact['nameAm'] as String?) ?? '');
    final phoneCtrl =
        TextEditingController(text: (contact['phone'] as String?) ?? '');
    final phone2Ctrl =
        TextEditingController(text: (contact['phone2'] as String?) ?? '');
    final emailCtrl =
        TextEditingController(text: (contact['email'] as String?) ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return FormSheet(
            title: loc.t('admin.tabDetails'),
            subtitle: loc.t('admin.detailsPublicNote'),
            isDark: isDark,
            saving: _savingDetails,
            submitLabel: loc.t('admin.save'),
            onSubmit: () async {
              if (nameCtrl.text.trim().isEmpty) {
                setState(() =>
                    _detailsError = loc.t('admin.englishNameRequired'));
                return;
              }
              setSheet(() => _savingDetails = true);
              try {
                await _org.updateAtbiya(parish.id, {
                  'name': nameCtrl.text.trim(),
                  'nameAmharic': nameAmCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'foundedAt': foundedCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  // Goes to atbiyaPrivate, never to /hierarchy.
                  'contact': {
                    'nameEn': cNameEnCtrl.text.trim(),
                    'nameAm': cNameAmCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'phone2': phone2Ctrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                  },
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                final denied = e.toString().contains('permission-denied');
                setState(() => _detailsError = denied
                    ? loc.t('admin.permissionDenied')
                    : loc.t('admin.congregationSaveFailed'));
                if (ctx.mounted) Navigator.pop(ctx, false);
              } finally {
                if (ctx.mounted) setSheet(() => _savingDetails = false);
              }
            },
            children: [
              buildLabel('${loc.t('admin.entityName')} *', isDark),
              buildTextField(nameCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.entityNameAm'), isDark),
              buildTextField(nameAmCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.location'), isDark),
              buildTextField(locationCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.foundedAt'), isDark),
              buildTextField(foundedCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.entityDescription'), isDark),
              buildTextField(descCtrl, '', isDark, maxLines: 3),
              const SizedBox(height: 18),
              buildLabel(loc.t('admin.contactPrivateHint'), isDark),
              const SizedBox(height: 8),
              buildLabel(loc.t('admin.contactNameEn'), isDark),
              buildTextField(cNameEnCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.contactNameAm'), isDark),
              buildTextField(cNameAmCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.phone'), isDark),
              buildTextField(phoneCtrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.altPhone'), isDark),
              buildTextField(phone2Ctrl, '', isDark),
              const SizedBox(height: 14),
              buildLabel(loc.t('admin.email'), isDark),
              buildTextField(emailCtrl, '', isDark),
            ],
          );
        });
      },
    );

    if (saved == true) {
      setState(() => _detailsError = null);
      await _loadParish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.t('admin.congregationSaved'))));
      }
    }
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
