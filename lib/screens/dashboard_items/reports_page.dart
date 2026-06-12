import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;
import 'plans_page.dart' show SegmentedPicker;

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _optionColors = {
    'Memriya': Color(0xFF3B82F6),
    'Kifil': Color(0xFF10B981),
    'Zerf': Color(0xFF8B5CF6),
  };

  static const _timeframeColors = {
    'Weekly': AppColors.primary,
    'Monthly': AppColors.divineGold,
    'Annually': Color(0xFF10B981),
  };

  // ── Create report ────────────────────────────────────────────────────────────
  void _showCreateSheet(BuildContext context) {
    final userModel = Provider.of<AuthService>(context, listen: false).userModel;
    final workDoneCtrl = TextEditingController();
    final resultCtrl = TextEditingController();
    String? selectedPlanId;
    String? selectedPlanName;
    String option = 'Memriya';
    String timeframe = 'Weekly';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: 'New Report',
            subtitle: 'Establish a record of divine progress',
            isDark: isDark,
            saving: saving,
            submitLabel: 'Submit Report',
            onSubmit: () async {
              if (selectedPlanId == null ||
                  workDoneCtrl.text.trim().isEmpty ||
                  resultCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Please fill all required fields',
                      style: GoogleFonts.notoSansEthiopic()),
                  backgroundColor: AppColors.sacredRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
                return;
              }
              setSheet(() => saving = true);
              try {
                await _db.collection('reports').add({
                  'planId': selectedPlanId,
                  'planName': selectedPlanName ?? 'Unknown Plan',
                  'option': option,
                  'timeframe': timeframe,
                  'workDone': workDoneCtrl.text.trim(),
                  'result': resultCtrl.text.trim(),
                  'authorId': userModel?.id,
                  'authorName': userModel?.displayName,
                  'authorHierarchyLevel':
                      userModel?.hierarchyLevel ?? 'Atbiya',
                  'submittedAt': DateTime.now().toIso8601String(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'comments': [],
                  'status': 'submitted',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Report submitted!', success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              // Plan selector
              buildLabel('Select Plan *', isDark),
              _PlanDropdown(
                isDark: isDark,
                selectedId: selectedPlanId,
                onChanged: (id, name) =>
                    setSheet(() {
                      selectedPlanId = id;
                      selectedPlanName = name;
                    }),
              ),
              const SizedBox(height: 16),

              // Option
              buildLabel('Report Type *', isDark),
              SegmentedPicker(
                options: const ['Memriya', 'Kifil', 'Zerf'],
                selected: option,
                isDark: isDark,
                onChanged: (v) => setSheet(() => option = v),
              ),
              const SizedBox(height: 16),

              // Timeframe
              buildLabel('Timeframe *', isDark),
              SegmentedPicker(
                options: const ['Weekly', 'Monthly', 'Annually'],
                selected: timeframe,
                isDark: isDark,
                onChanged: (v) => setSheet(() => timeframe = v),
              ),
              const SizedBox(height: 16),

              // Work done
              buildLabel('Work Done *', isDark),
              buildTextField(workDoneCtrl,
                  'Detail the activities completed...', isDark,
                  maxLines: 4),
              const SizedBox(height: 16),

              // Result
              buildLabel('Results *', isDark),
              buildTextField(
                  resultCtrl, 'Quantify the results and impact...', isDark,
                  maxLines: 4),
            ],
          );
        },
      ),
    );
  }

  // ── Add comment ──────────────────────────────────────────────────────────────
  void _showCommentSheet(BuildContext context, String reportId) {
    final userModel = Provider.of<AuthService>(context, listen: false).userModel;
    final commentCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: 'Add Feedback',
            subtitle: 'Provide professional guidance or acknowledgment',
            isDark: isDark,
            saving: saving,
            submitLabel: 'Add Insight',
            onSubmit: () async {
              if (commentCtrl.text.trim().isEmpty) return;
              setSheet(() => saving = true);
              try {
                await _db.collection('reports').doc(reportId).update({
                  'comments': FieldValue.arrayUnion([
                    {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'content': commentCtrl.text.trim(),
                      'authorName': userModel?.displayName ?? 'Anonymous',
                      'createdAt': DateTime.now().toIso8601String(),
                    }
                  ]),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Comment added!', success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Your Feedback *', isDark),
              buildTextField(commentCtrl,
                  'Enter your feedback or guidance...', isDark,
                  maxLines: 5),
            ],
          );
        },
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
    final canCreate  = perms.isSuperAdmin || perms.can('canCreateReport');
    final canComment = perms.isSuperAdmin || perms.can('canCommentOnReport');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Reports',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              return _buildCard(context, data, id, index, isDark,
                  canComment: canComment);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data, String id,
      int index, bool isDark,
      {required bool canComment}) {
    final option = data['option'] as String? ?? 'Memriya';
    final timeframe = data['timeframe'] as String? ?? 'Weekly';
    final optionColor = _optionColors[option] ?? AppColors.primary;
    final tfColor = _timeframeColors[timeframe] ?? AppColors.primary;
    final comments = (data['comments'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: optionColor.withOpacity(0.06),
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
                  colors: [optionColor, optionColor.withOpacity(0.3)]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: optionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FaIcon(FontAwesomeIcons.clipboardList,
                          color: optionColor, size: 12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['planName'] ?? 'Untitled Report',
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppColors.lightText),
                      ),
                    ),
                    // Option badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: optionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(option,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: optionColor,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Meta row
                Row(
                  children: [
                    if (data['authorName'] != null) ...[
                      Icon(Icons.person_outline,
                          size: 11, color: Colors.grey.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(data['authorName'],
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tfColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(timeframe,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: tfColor)),
                    ),
                    const Spacer(),
                    // Ref ID
                    Text(
                      'REF: ${id.substring(id.length > 8 ? id.length - 8 : 0).toUpperCase()}',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 8,
                          color: Colors.grey.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),

                const Divider(height: 20),

                // Work done
                _buildSection('Work Done', data['workDone'] ?? '', isDark,
                    AppColors.primary),
                const SizedBox(height: 12),

                // Result
                _buildSection('Results', data['result'] ?? '', isDark,
                    const Color(0xFF10B981)),

                // Comments section
                if (comments.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 13, color: AppColors.primary.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text(
                        '${comments.length} Feedback${comments.length != 1 ? 's' : ''}',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white54
                                : AppColors.lightText.withOpacity(0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...comments.take(3).map((c) {
                    final comment = c as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : AppColors.primary.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (comment['authorName'] ?? 'A')[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment['authorName'] ?? 'Anonymous',
                                    style: GoogleFonts.notoSansEthiopic(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.lightText)),
                                const SizedBox(height: 2),
                                Text(comment['content'] ?? '',
                                    style: GoogleFonts.notoSansEthiopic(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (canComment) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showCommentSheet(context, id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_comment_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Add Feedback',
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 40).ms).moveY(begin: 10);
  }

  Widget _buildSection(
      String label, String content, bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark
                        ? Colors.white38
                        : AppColors.lightText.withOpacity(0.4))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : accentColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(content,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5)),
        ),
      ],
    );
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
            FaIcon(FontAwesomeIcons.fileCircleExclamation,
                size: 48, color: AppColors.primary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('NO REPORTS YET',
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

// ── Plan dropdown (fetches from Firestore) ────────────────────────────────────

class _PlanDropdown extends StatelessWidget {
  final bool isDark;
  final String? selectedId;
  final void Function(String id, String name) onChanged;

  const _PlanDropdown({
    required this.isDark,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final plans = snapshot.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              hint: Text('Select a plan',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 13, color: Colors.grey)),
              dropdownColor:
                  isDark ? const Color(0xFF1A365D) : Colors.white,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.lightText),
              items: plans.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(data['name'] ?? 'Unnamed Plan',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                final doc = plans.firstWhere((d) => d.id == id);
                final name =
                    (doc.data() as Map<String, dynamic>)['name'] ?? '';
                onChanged(id, name);
              },
            ),
          ),
        );
      },
    );
  }
}
