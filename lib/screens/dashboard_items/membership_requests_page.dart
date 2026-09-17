import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/membership_requests_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/software_control_service.dart';
import '../../services/localization_service.dart';
import '../../services/role_registry_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';

/// Approve/reject the pending self-signups created by the Signup flow.
/// Head-office approvers see every parish; a parish approver sees only its own.
/// Congregations that actually have something pending.
///
/// Built from the loaded requests rather than the registry, the way the
/// web's `congregationOptions` does: a congregation with nothing waiting is
/// not worth offering as a filter.
List<({String id, String name, int count})> congregationOptions(
    List<Map<String, dynamic>> requests) {
  final names = <String, String>{};
  final counts = <String, int>{};
  for (final r in requests) {
    final id = (r['atbiyaId'] as String?) ?? '';
    if (id.isEmpty) continue;
    names[id] = (r['atbiyaName'] as String?) ?? id;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final out = names.entries
      .map((e) => (id: e.key, name: e.value, count: counts[e.key] ?? 0))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return out;
}

class MembershipRequestsPage extends StatefulWidget {
  /// True when this sits inside another screen's tab, in which case it renders
  /// only its body — a DashboardScaffold within a tab would stack a second
  /// app bar under the first.
  final bool embedded;

  const MembershipRequestsPage({super.key, this.embedded = false});

  @override
  State<MembershipRequestsPage> createState() => _MembershipRequestsPageState();
}

class _MembershipRequestsPageState extends State<MembershipRequestsPage>
    with SingleTickerProviderStateMixin {
  /// Whether the approve and reject buttons do anything.
  ///
  /// Software Control is a kill switch an administrator flips on the web to
  /// take an action out of service everywhere. The app read the nav half of it
  /// and ignored the element half entirely — `elementAllowed` had no caller —
  /// so disabling `members.approve` left these buttons live. The web gates the
  /// same decision on `showElement('members.approve')`.
  bool get _canAct {
    final perms = Provider.of<PermissionService>(context, listen: false);
    final level =
        Provider.of<AuthService>(context, listen: false).userModel?.hierarchyLevel ??
            '';
    return Provider.of<SoftwareControlService>(context, listen: false)
        .elementAllowed('members.approve', level, perms.isSuperAdmin);
  }

  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final MembershipRequestsService _service = MembershipRequestsService();
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _decided;
  late final TabController _tabs;

  /// Congregation id the pending list is filtered to, or '' for all of them.
  /// Only meaningful for head office — a parish sees one congregation anyway.
  String _congregationFilter = '';

  /// The assignable roles come from RoleRegistryService (`siteConfig/roles`),
  /// not a const list: roles are dynamic, so a hardcoded set hid any role an
  /// admin added in Software Control and showed raw keys instead of labels.
  List<String> _assignableRoles(BuildContext context) {
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final me = Provider.of<AuthService>(context, listen: false).userModel;
    final headOffice = perms.isSuperAdmin ||
        registry.scopeOf(me?.hierarchyLevel) == RoleScope.global;
    return registry.assignableRoles(isHeadOffice: headOffice);
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _future = _load();
    _decided = _loadDecided();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The congregation scope this approver may see, shared by both queries.
  ({bool wholeDirectory, String atbiyaId}) _scope() {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry =
        Provider.of<RoleRegistryService>(context, listen: false);
    final s = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    return (wholeDirectory: s.wholeDirectory, atbiyaId: s.atbiyaId);
  }

  Future<List<Map<String, dynamic>>> _loadDecided() {
    final scope = _scope();
    return _service.listDecided(
        atbiyaId: scope.wholeDirectory ? null : scope.atbiyaId);
  }

  Future<List<Map<String, dynamic>>> _load() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    final scope = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    return _service.listPending(
        atbiyaId: scope.wholeDirectory ? null : scope.atbiyaId);
  }

  void _reload() => setState(() {
        _future = _load();
        _decided = _loadDecided();
      });



  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = Column(children: [
      TabBar(
        controller: _tabs,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900, fontSize: 12),
        tabs: [
          Tab(text: loc.t('admin.tabPending')),
          Tab(text: loc.t('admin.tabDecided')),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [_pendingTab(isDark), _decidedTab(isDark)],
        ),
      ),
    ]);

    if (widget.embedded) return body;
    return DashboardScaffold(
      titleKey: 'admin.requestsTitle',
      moduleKey: 'membershipRequests',
      constrainWidth: false,
      actions: [
        IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, color: AppColors.primary)),
      ],
      body: body,
    );
  }

  Widget _pendingTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          // The web distinguishes these too: a composite index that is still
          // building looks exactly like an empty queue otherwise, and an
          // approver waits for requests that were there all along.
          final message = snapshot.error.toString().toLowerCase();
          final building = message.contains('index') ||
              message.contains('failed-precondition');
          return _empty(
            building
                ? loc.t('admin.requestsIndexBuilding')
                : loc.t('admin.requestsLoadFailed'),
            FontAwesomeIcons.userClock,
          );
        }
        final all = snapshot.data ?? [];
        if (all.isEmpty) {
          return _empty(loc.t('admin.noPendingRequests'),
              FontAwesomeIcons.userCheck,
              body: loc.t('admin.noPendingRequestsDesc'));
        }

        final options = congregationOptions(all);
        final filtered = _congregationFilter.isEmpty
            ? all
            : all
                .where((r) => r['atbiyaId'] == _congregationFilter)
                .toList();

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          color: AppColors.primary,
          child: Column(children: [
            // Only offered when there is more than one congregation to choose
            // between — a parish approver has exactly one.
            if (options.length > 1) _congregationBar(options, isDark),
            Expanded(
              child: filtered.isEmpty
                  ? _empty(loc.t('admin.noPendingForCongregation'),
                      FontAwesomeIcons.userCheck,
                      body: loc.t('admin.noPendingForCongregationDesc'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) =>
                          _card(filtered[i], isDark, i),
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _congregationBar(
      List<({String id, String name, int count})> options, bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _filterChip(loc.t('admin.allCongregations'), '', isDark),
          ...options.map((o) =>
              _filterChip('${o.name} (${o.count})', o.id, isDark)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String id, bool isDark) {
    final selected = _congregationFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _congregationFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.primary)),
        ),
      ),
    );
  }

  Widget _decidedTab(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _decided,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return _empty(loc.t('admin.requestsLoadFailed'),
              FontAwesomeIcons.userClock);
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return _empty(loc.t('admin.noDecidedYet'), FontAwesomeIcons.clockRotateLeft,
              body: loc.t('admin.noDecidedYetDesc'));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            itemBuilder: (context, i) => _card(rows[i], isDark, i),
          ),
        );
      },
    );
  }

  /// `requestedAt` is an ISO string; anything unparseable is simply not shown
  /// rather than rendered raw.
  static String? _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('MMM d, yyyy').format(d.toLocal());
  }

  /// The outcome badge on a decided request, with the rejection reason the
  /// member was given.
  Widget _outcome(Map<String, dynamic> r, bool isDark) {
    final rejected = r['status'] == 'rejected';
    final reason = (r['rejectedReason'] as String?)?.trim() ?? '';
    final color = rejected ? AppColors.sacredRed : AppColors.success;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(
            rejected
                ? loc.t('admin.scColRejected')
                : loc.t('admin.statusActive'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 9, fontWeight: FontWeight.w900, color: color)),
      ),
      if (rejected && reason.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('${loc.t('pages.rejectedReasonLabel')}: $reason',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11, color: Colors.grey, height: 1.4)),
      ],
    ]);
  }

  Widget _card(Map<String, dynamic> r, bool isDark, int index) {
    final name = r['fullNameEnglish'] ?? r['fullName'] ?? loc.t('admin.applicant');
    final nameAm = r['fullNameAmharic'] ?? '';
    final parish = r['atbiyaName'] ?? '';
    final phone = r['phone'] ?? '';
    final email = r['email'] ?? '';
    final address = (r['address'] as Map?) ?? const {};
    final where = [
      address['region'],
      address['zone'],
      address['woreda'],
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' · ');
    final ministries = ((r['ministryType'] as List?) ?? const [])
        .whereType<String>()
        .where((m) => m.trim().isNotEmpty)
        .toList();
    final requestedAt = _shortDate(r['requestedAt'] as String?);
    final decided = r['status'] != 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: GoogleFonts.notoSansEthiopic(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.lightText)),
          if (nameAm.toString().isNotEmpty)
            Text(nameAm,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (parish.toString().isNotEmpty)
            _line(Icons.church_outlined, parish.toString()),
          if (phone.toString().isNotEmpty)
            _line(Icons.phone_outlined, phone.toString()),
          if (email.toString().isNotEmpty)
            _line(Icons.alternate_email, email.toString()),
          if (where.isNotEmpty) _line(Icons.place_outlined, where),
          if (requestedAt != null)
            _line(Icons.calendar_today_outlined,
                '${loc.t('admin.requested')} $requestedAt'),
          if (ministries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ministries
                  .map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(m,
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary)),
                      ))
                  .toList(),
            ),
          ],
          // A decided request is history: it shows the outcome and the reason,
          // and offers no buttons.
          if (decided) ...[
            const SizedBox(height: 10),
            _outcome(r, isDark),
          ] else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canAct ? () => _approve(r) : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(loc.t('admin.approve')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canAct ? () => _reject(r) : null,
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(loc.t('admin.reject')),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sacredRed),
                ),
              ),
            ],
          ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.05);
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 11, color: Colors.grey))),
        ]),
      );

  Future<void> _approve(Map<String, dynamic> r) async {
    final roles = _assignableRoles(context);
    if (roles.isEmpty) {
      _snack(loc.t('admin.noParishRole'), AppColors.sacredRed);
      return;
    }
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final lang = Provider.of<LocalizationService>(context, listen: false).language;
    String role = roles.contains(r['hierarchyLevel'])
        ? r['hierarchyLevel'] as String
        : roles.last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(loc.t('admin.approve')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r['fullNameEnglish'] ?? loc.t('admin.member')} \u2014 '
                  '${loc.t('admin.assignRole')}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: roles
                    .map((e) => DropdownMenuItem(
                        value: e, child: Text(registry.roleLabel(e, lang))))
                    .toList(),
                onChanged: (v) => setD(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.t('common.cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(loc.t('admin.approve'))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final approverId =
          Provider.of<AuthService>(context, listen: false).userModel?.id ?? '';
      await _service.approve(
          uid: r['id'] as String, approverId: approverId, roleKey: role);
      _reload();
      _snack("${r['fullNameEnglish'] ?? loc.t('admin.member')} "
          "${loc.t('admin.approvedNotice')}", AppColors.success);
    } catch (e) {
      _snack(loc.t('admin.approveFailed'), AppColors.sacredRed);
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final reasonCtrl = TextEditingController();
    // Disposed in the finally below — this leaked a controller per rejection.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('admin.confirmRejection')),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: loc.t('admin.rejectionReason'),
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.t('admin.confirmRejection'),
                  style: const TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final approverId =
          Provider.of<AuthService>(context, listen: false).userModel?.id ?? '';
      await _service.reject(
          uid: r['id'] as String, approverId: approverId, reason: reason);
      _reload();
      _snack("${r['fullNameEnglish'] ?? loc.t('admin.member')} "
          "${loc.t('admin.rejectedNotice')}", AppColors.divineGold);
    } catch (e) {
      _snack(loc.t('admin.rejectFailed'), AppColors.sacredRed);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  Widget _empty(String msg, FaIconData icon, {String? body}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FaIcon(icon,
                size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            if (body != null && body.isNotEmpty) ...[
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
