import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/strategic_plan_service.dart';
import '../../services/localization_service.dart';
import '../../services/permission_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StrategicPlanPage extends StatefulWidget {
  const StrategicPlanPage({super.key});

  @override
  State<StrategicPlanPage> createState() => _StrategicPlanPageState();
}

class _StrategicPlanPageState extends State<StrategicPlanPage> {
  final StrategicPlanService _service = StrategicPlanService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);
    final canManage = Provider.of<PermissionService>(context).isSuperAdmin;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loc.t('strategicPlan'),
          style: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.watchGoals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildEmptyState(
                'Unable to load strategic goals.', isDark);
          }
          final goals = snapshot.data ?? [];
          if (goals.isEmpty) {
            return _buildEmptyState('No strategic goals yet.', isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return _buildGoalCard(
                  context, goals[index], index, surfaceColor, isDark, canManage);
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _openGoalForm(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.flag,
              size: 72, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Map<String, dynamic> goal,
      int index, Color surfaceColor, bool isDark, bool canManage) {
    final current = double.tryParse(goal['currentValue'].toString()) ?? 0;
    final target = double.tryParse(goal['targetValue'].toString()) ?? 1;
    final percentage = (current / target * 100).clamp(0, 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(FontAwesomeIcons.flag,
                      color: AppColors.primary, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['title'] ?? 'Untitled Goal',
                        style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color:
                                isDark ? Colors.white : AppColors.lightText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal['description'] ?? '',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('TARGET',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey)),
                    Text(
                      '${goal['targetYear'] ?? ''}',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) {
                      if (v == 'edit') _openGoalForm(context, goal: goal);
                      if (v == 'delete') _confirmDelete(context, goal);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$percentage%',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.lightText),
                    ),
                    const Icon(Icons.trending_up,
                        color: Colors.green, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (current / target).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildValueBox(
                          'Current ${goal['unit'] ?? ''}', current, isDark, false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValueBox(
                          'Target ${goal['unit'] ?? ''}', target, isDark, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }

  Widget _buildValueBox(
      String label, double value, bool isDark, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary
            : (isDark ? Colors.black26 : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border:
            isPrimary ? null : Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white70 : Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value.toInt().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isPrimary ? Colors.white : null),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text('Delete "${goal['title'] ?? ''}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteGoal(goal['id'] as String);
    }
  }

  void _openGoalForm(BuildContext context, {Map<String, dynamic>? goal}) {
    final isEditing = goal != null;
    final titleCtrl = TextEditingController(text: goal?['title']?.toString());
    final descCtrl =
        TextEditingController(text: goal?['description']?.toString());
    final unitCtrl = TextEditingController(text: goal?['unit']?.toString());
    final targetYearCtrl =
        TextEditingController(text: goal?['targetYear']?.toString());
    final currentCtrl =
        TextEditingController(text: goal?['currentValue']?.toString());
    final targetCtrl =
        TextEditingController(text: goal?['targetValue']?.toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'Edit Goal' : 'New Strategic Goal',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _field(titleCtrl, 'Title', required: true),
                    _field(descCtrl, 'Description', maxLines: 3),
                    _field(unitCtrl, 'Unit (e.g. Members)'),
                    _field(targetYearCtrl, 'Target Year',
                        keyboardType: TextInputType.number),
                    _field(currentCtrl, 'Current Value',
                        keyboardType: TextInputType.number),
                    _field(targetCtrl, 'Target Value',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final data = {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'unit': unitCtrl.text.trim(),
                            'targetYear':
                                int.tryParse(targetYearCtrl.text.trim()) ?? 0,
                            'currentValue':
                                num.tryParse(currentCtrl.text.trim()) ?? 0,
                            'targetValue':
                                num.tryParse(targetCtrl.text.trim()) ?? 0,
                          };
                          if (isEditing) {
                            await _service.updateGoal(
                                goal['id'] as String, data);
                          } else {
                            await _service.createGoal(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(isEditing ? 'Save' : 'Create',
                            style:
                                const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false,
      int maxLines = 1,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
