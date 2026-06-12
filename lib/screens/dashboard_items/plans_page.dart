import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Re-use helpers from announcements_page
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filterTimeframe = 'All';

  static const _timeframes = ['All', 'Weekly', 'Monthly', 'Annually'];

  static const _timeframeColors = {
    'Weekly': Color(0xFF6366F1),
    'Monthly': AppColors.primary,
    'Annually': Color(0xFF10B981),
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Create ──────────────────────────────────────────────────────────────────
  void _showCreateSheet(BuildContext context) {
    final userModel = Provider.of<AuthService>(context, listen: false).userModel;
    final nameCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    String timeframe = 'Monthly';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: 'New Plan',
            subtitle: 'Establish a new strategic roadmap for ministry',
            isDark: isDark,
            saving: saving,
            submitLabel: 'Create Plan',
            onSubmit: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  detailsCtrl.text.trim().isEmpty) return;
              setSheet(() => saving = true);
              try {
                await _db.collection('plans').add({
                  'name': nameCtrl.text.trim(),
                  'timeframe': timeframe,
                  'details': detailsCtrl.text.trim(),
                  'createdBy': {
                    'id': userModel?.id,
                    'fullName': userModel?.displayName,
                    'hierarchyLevel': userModel?.hierarchyLevel ?? 'Atbiya',
                  },
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Plan created!', success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Plan Name *', isDark),
              buildTextField(nameCtrl, 'Enter plan name', isDark),
              const SizedBox(height: 16),
              buildLabel('Timeframe *', isDark),
              SegmentedPicker(
                options: const ['Weekly', 'Monthly', 'Annually'],
                selected: timeframe,
                isDark: isDark,
                onChanged: (v) => setSheet(() => timeframe = v),
              ),
              const SizedBox(height: 16),
              buildLabel('Details *', isDark),
              buildTextField(detailsCtrl,
                  'Detail the objectives and spiritual milestones...', isDark,
                  maxLines: 5),
            ],
          );
        },
      ),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Plan',
            style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900)),
        content: Text('Delete "$name"? This cannot be undone.',
            style: GoogleFonts.notoSansEthiopic()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
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
              await _db.collection('plans').doc(id).delete();
              _showSnack('Plan deleted', success: true);
            },
            child: Text('Delete',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final canCreate = perms.isSuperAdmin || perms.can('canCreatePlan');
    final canDelete = perms.isSuperAdmin || perms.can('canDeletePlan');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Plans',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canCreate)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text('New',
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
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: GoogleFonts.notoSansEthiopic(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primary, size: 18),
                  hintText: 'Search plans...',
                  hintStyle: GoogleFonts.notoSansEthiopic(
                      fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Timeframe filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _timeframes.map((tf) {
                final selected = _filterTimeframe == tf;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterTimeframe = tf),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : AppColors.primary.withOpacity(0.12)),
                      ),
                      child: Text(tf,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('plans')
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
                  final d = doc.data() as Map<String, dynamic>;
                  final matchSearch = _search.isEmpty ||
                      (d['name'] ?? '').toString().toLowerCase().contains(_search) ||
                      (d['details'] ?? '').toString().toLowerCase().contains(_search);
                  final matchTf = _filterTimeframe == 'All' ||
                      d['timeframe'] == _filterTimeframe;
                  return matchSearch && matchTf;
                }).toList();

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    return _buildCard(context, data, id, index, isDark,
                        canDelete: canDelete);
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
      {required bool canDelete}) {
    final timeframe = data['timeframe'] as String? ?? 'Monthly';
    final color = _timeframeColors[timeframe] ?? AppColors.primary;
    final createdBy = data['createdBy'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.4)]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name'] ?? 'Untitled Plan',
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.lightText),
                      ),
                    ),
                    // Timeframe badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(timeframe,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.5)),
                    ),
                    if (canDelete) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _confirmDelete(context, id, data['name'] ?? ''),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.sacredRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline,
                              size: 16, color: AppColors.sacredRed),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data['details'] ?? '',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (createdBy != null) ...[
                      Icon(Icons.person_outline,
                          size: 11, color: Colors.grey.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(createdBy['fullName'] ?? 'Steward',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            createdBy['hierarchyLevel'] ?? '',
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 40).ms).moveY(begin: 10);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.fileLines,
                size: 48, color: AppColors.primary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('NO PLANS YET',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.lightText.withOpacity(0.3)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Segmented picker for timeframe ────────────────────────────────────────────

class SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const SegmentedPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
                child: Text(opt,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.grey))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
