import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  /// The catalog, reachable from dialogs and sheets as well as `build`.
  /// `build` separately watches it (below) so a language change rebuilds the
  /// screen; this accessor only reads, so it is safe outside the build phase.
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Create ──────────────────────────────────────────────────────────────────
  void _showCreateSheet(BuildContext context) {
    final userModel = Provider.of<AuthService>(context, listen: false).userModel;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    DateTime? expiresAt;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: loc.t('pages.newAnnouncement'),
            subtitle: loc.t('admin.newAnnouncementDesc'),
            isDark: isDark,
            saving: saving,
            submitLabel: loc.t('admin.postAnnouncement'),
            onSubmit: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  contentCtrl.text.trim().isEmpty) {
                return;
              }
              setSheet(() => saving = true);
              try {
                final data = <String, dynamic>{
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'authorId': userModel?.id,
                  'authorName': userModel?.displayName,
                  'authorHierarchyLevel':
                      userModel?.hierarchyLevel ?? 'Atbiya',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (expiresAt != null) {
                  data['expiresAt'] = expiresAt!.toIso8601String();
                }
                await _db.collection('announcements').add(data);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack(loc.t('pages.announcementCreated'), success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Title *', isDark),
              buildTextField(titleCtrl, loc.t('pages.announcementTitlePlaceholder'), isDark),
              const SizedBox(height: 16),
              buildLabel('Content *', isDark),
              buildTextField(contentCtrl, loc.t('pages.announcementContentPlaceholder'),
                  isDark, maxLines: 5),
              const SizedBox(height: 16),
              buildLabel(loc.t('pages.expirationDate'), isDark),
              _ExpiryPicker(
                isDark: isDark,
                value: expiresAt,
                onChanged: (d) => setSheet(() => expiresAt = d),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Edit ────────────────────────────────────────────────────────────────────
  void _showEditSheet(BuildContext context, Map<String, dynamic> data, String id) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final contentCtrl = TextEditingController(text: data['content'] ?? '');
    DateTime? expiresAt = data['expiresAt'] != null
        ? DateTime.tryParse(data['expiresAt'].toString())
        : null;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: loc.t('pages.editAnnouncement'),
            subtitle: loc.t('admin.editAnnouncementSub'),
            isDark: isDark,
            saving: saving,
            submitLabel: loc.t('admin.update'),
            onSubmit: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  contentCtrl.text.trim().isEmpty) {
                return;
              }
              setSheet(() => saving = true);
              try {
                final update = <String, dynamic>{
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (expiresAt != null) {
                  update['expiresAt'] = expiresAt!.toIso8601String();
                }
                await _db.collection('announcements').doc(id).update(update);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack(loc.t('pages.announcementUpdated'), success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Title *', isDark),
              buildTextField(titleCtrl, loc.t('pages.announcementTitlePlaceholder'), isDark),
              const SizedBox(height: 16),
              buildLabel('Content *', isDark),
              buildTextField(contentCtrl, loc.t('pages.announcementContentPlaceholder'),
                  isDark, maxLines: 5),
              const SizedBox(height: 16),
              buildLabel(loc.t('pages.expirationDate'), isDark),
              _ExpiryPicker(
                isDark: isDark,
                value: expiresAt,
                onChanged: (d) => setSheet(() => expiresAt = d),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.t('pages.deleteAnnouncement'),
            style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900)),
        content: Text('${loc.t('pages.deleteAnnouncement')}: "$title"',
            style: GoogleFonts.notoSansEthiopic()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('admin.cancel'),
                style: GoogleFonts.notoSansEthiopic(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sacredRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.collection('announcements').doc(id).delete();
              _showSnack(loc.t('pages.announcementDeleted'), success: true);
            },
            child: Text(loc.t('pages.delete'),
                style: GoogleFonts.notoSansEthiopic(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansEthiopic()),
      backgroundColor: success ? AppColors.success : AppColors.sacredRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    // SuperAdmin always gets all actions; otherwise check specific permission
    const canCreate = true; // Match web: anyone authenticated can post
    final canEdit   = perms.isSuperAdmin || perms.can('canEditAnnouncement');
    final canDelete = perms.isSuperAdmin || perms.can('canDeleteAnnouncement');

    return DashboardScaffold(
      titleKey: 'nav.announcements',
      moduleKey: 'announcements',
      constrainWidth: false,
      actions: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('pages.create'),
                  style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: GoogleFonts.notoSansEthiopic(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primary, size: 18),
                  hintText: loc.t('pages.searchAnnouncements'),
                  hintStyle: GoogleFonts.notoSansEthiopic(
                      fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  if (_search.isEmpty) return true;
                  final d = doc.data() as Map<String, dynamic>;
                  return (d['title'] ?? '').toString().toLowerCase().contains(_search) ||
                      (d['content'] ?? '').toString().toLowerCase().contains(_search);
                }).toList();

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    return _buildCard(context, data, id, index, isDark,
                        canEdit: canEdit, canDelete: canDelete);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data, String id,
      int index, bool isDark,
      {required bool canEdit, required bool canDelete}) {
    final expiresAt = data['expiresAt'] != null
        ? DateTime.tryParse(data['expiresAt'].toString())
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isExpired
                ? AppColors.sacredRed.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const FaIcon(FontAwesomeIcons.bullhorn,
                    color: AppColors.primary, size: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['title'] ?? loc.t('pages.nmUntitled'),
                  style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.lightText),
                ),
              ),
              if (canEdit || canDelete)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'edit') _showEditSheet(context, data, id);
                    if (val == 'delete') {
                      _confirmDelete(context, id, data['title'] ?? '');
                    }
                  },
                  itemBuilder: (_) => [
                    if (canEdit)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(loc.t('admin.edit'),
                              style: GoogleFonts.notoSansEthiopic(
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline,
                              size: 16, color: AppColors.sacredRed),
                          const SizedBox(width: 8),
                          Text(loc.t('pages.delete'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sacredRed)),
                        ]),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data['content'] ?? '',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (data['authorName'] != null) ...[
                Icon(Icons.person_outline,
                    size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(data['authorName'],
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
              ],
              const Spacer(),
              if (expiresAt != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isExpired ? AppColors.sacredRed : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isExpired ? 'EXPIRED' : 'EXP'}: ${expiresAt.toLocal().toString().substring(0, 10)}',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 8,
                        color: isExpired
                            ? AppColors.sacredRed
                            : AppColors.warning,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.04);
  }

  Widget _buildEmptyState() => const DashboardEmpty(
        icon: Icons.mark_email_unread_outlined,
        messageKey: 'dashboard.noAnnouncementsAvailable',
      );
}

// ── Shared form helpers ────────────────────────────────────────────────────────

Widget buildLabel(String text, bool isDark) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? AppColors.accent : AppColors.primary)),
    );

Widget buildTextField(
  TextEditingController ctrl,
  String hint,
  bool isDark, {
  int maxLines = 1,
  bool obscure = false,
}) =>
    Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        obscureText: obscure,
        style: GoogleFonts.notoSansEthiopic(
            fontSize: 13,
            color: isDark ? Colors.white : AppColors.lightText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.notoSansEthiopic(
              fontSize: 13, color: Colors.grey),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );

// ── Expiry date picker widget ─────────────────────────────────────────────────

class _ExpiryPicker extends StatelessWidget {
  final bool isDark;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _ExpiryPicker({
    required this.isDark,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: isDark ? AppColors.accent : AppColors.primary),
            const SizedBox(width: 10),
            Text(
              value != null
                  ? value!.toLocal().toString().substring(0, 10)
                  : loc.t('admin.selectExpiryOptional'),
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: value != null
                      ? (isDark ? Colors.white : AppColors.lightText)
                      : Colors.grey),
            ),
            const Spacer(),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable bottom-sheet form wrapper ────────────────────────────────────────

class FormSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final bool saving;
  final String submitLabel;
  final VoidCallback onSubmit;
  final List<Widget> children;

  const FormSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationService>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D2440) : const Color(0xFFF8FAFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.lightText)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.lightText.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                // Gradient accent bar (matches web card top bar)
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),

          Divider(
              color: AppColors.primary.withValues(alpha: 0.08),
              height: 24),

          // Form body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D2440)
                  : const Color(0xFFF8FAFF),
              border: Border(
                  top: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(loc.t('admin.cancel'),
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : AppColors.lightText)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: saving ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(submitLabel,
                            style: GoogleFonts.notoSansEthiopic(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
