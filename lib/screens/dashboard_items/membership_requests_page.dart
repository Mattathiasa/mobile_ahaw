import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/membership_requests_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/localization_service.dart';
import '../../services/role_registry_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';

/// Approve/reject the pending self-signups created by the Signup flow.
/// Head-office approvers see every parish; a parish approver sees only its own.
class MembershipRequestsPage extends StatefulWidget {
  const MembershipRequestsPage({super.key});

  @override
  State<MembershipRequestsPage> createState() => _MembershipRequestsPageState();
}

class _MembershipRequestsPageState extends State<MembershipRequestsPage> {
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final MembershipRequestsService _service = MembershipRequestsService();
  late Future<List<Map<String, dynamic>>> _future;

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
    _future = _load();
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

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardScaffold(
      titleKey: 'admin.requestsTitle',
      moduleKey: 'membershipRequests',
      constrainWidth: false,
      actions: [
        IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, color: AppColors.primary)),
      ],
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            final building =
                message.contains('index') || message.contains('failed-precondition');
            return _empty(
              building
                  ? loc.t('admin.requestsIndexBuilding')
                  : loc.t('admin.requestsLoadFailed'),
              FontAwesomeIcons.userClock,
            );
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return _empty(loc.t('admin.noPendingRequests'), FontAwesomeIcons.userCheck);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              itemBuilder: (context, i) => _card(requests[i], isDark, i),
            ),
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> r, bool isDark, int index) {
    final name = r['fullNameEnglish'] ?? r['fullName'] ?? 'Applicant';
    final nameAm = r['fullNameAmharic'] ?? '';
    final parish = r['atbiyaName'] ?? '';
    final phone = r['phone'] ?? '';

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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approve(r),
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
                  onPressed: () => _reject(r),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(loc.t('admin.reject')),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sacredRed),
                ),
              ),
            ],
          ),
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

  Widget _empty(String msg, FaIconData icon) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FaIcon(icon, size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
        ]),
      );
}
