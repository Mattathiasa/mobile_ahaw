import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/church_rules_service.dart';
import '../../services/localization_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

/// Church Rules (Hige Denb) — three categories synced from the web admin
/// (siteConfig/churchRules): Regulations (ደንብ), Directives (መመሪያ), Policies.
class ChurchRulesPage extends StatelessWidget {
  const ChurchRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);
    final rules = Provider.of<ChurchRulesService>(context);
    final perms = Provider.of<PermissionService>(context);
    final registry = Provider.of<RoleRegistryService>(context);
    final level =
        Provider.of<AuthService>(context).userModel?.hierarchyLevel;
    final canEdit = perms.isSuperAdmin || registry.isAdminRole(level);

    final categories = [
      _Category('denb', 'Regulations', 'ደንብ', FontAwesomeIcons.scaleBalanced, Colors.indigo, rules.denb),
      _Category('memerya', 'Directives', 'መመሪያ', FontAwesomeIcons.bookOpen, Colors.green, rules.memerya),
      _Category('policies', 'Policies', 'ፖሊሲ', FontAwesomeIcons.clipboardList, Colors.amber, rules.policies),
    ];

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(loc.t('churchRules'),
              style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText,
              )),
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : AppColors.lightText),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900, fontSize: 12),
            tabs: categories
                .map((c) => Tab(text: '${c.label} (${c.amharic})'))
                .toList(),
          ),
        ),
        body: !rules.loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                children: categories
                    .map((cat) =>
                        _buildList(context, cat, isDark, canEdit, rules))
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildList(BuildContext context, _Category cat, bool isDark,
      bool canEdit, ChurchRulesService svc) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openRuleForm(context, svc, cat),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add ${cat.label.toLowerCase()}'),
              ),
            ),
          ),
        if (cat.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  FaIcon(cat.icon, size: 48, color: cat.color.withOpacity(0.4)),
                  const SizedBox(height: 14),
                  Text('No ${cat.label.toLowerCase()} yet',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ...cat.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cat.color.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FaIcon(cat.icon, size: 13, color: cat.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.title,
                            style: GoogleFonts.notoSansEthiopic(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color:
                                  isDark ? Colors.white : AppColors.lightText,
                            )),
                      ),
                      if (canEdit)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _openRuleForm(context, svc, cat,
                                  index: i, existing: item);
                            } else if (v == 'delete') {
                              _deleteRule(context, svc, cat, i);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item.content,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 13,
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      )),
                ],
              ),
            ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: 0.05);
          }),
      ],
    );
  }

  Future<void> _deleteRule(BuildContext context, ChurchRulesService svc,
      _Category cat, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Delete "${cat.items[index].title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
    if (ok == true) {
      final list = List<RuleItem>.from(svc.itemsFor(cat.key))..removeAt(index);
      await svc.saveCategory(cat.key, list);
    }
  }

  void _openRuleForm(BuildContext context, ChurchRulesService svc,
      _Category cat, {int? index, RuleItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title);
    final contentCtrl = TextEditingController(text: existing?.content);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text(
                      '${existing == null ? 'New' : 'Edit'} ${cat.label.toLowerCase()}',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Title', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Content', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final item = RuleItem(
                            titleCtrl.text.trim(), contentCtrl.text.trim());
                        final list = List<RuleItem>.from(svc.itemsFor(cat.key));
                        if (index != null) {
                          list[index] = item;
                        } else {
                          list.add(item);
                        }
                        await svc.saveCategory(cat.key, list);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Category {
  final String key;
  final String label;
  final String amharic;
  final IconData icon;
  final Color color;
  final List<RuleItem> items;
  const _Category(
      this.key, this.label, this.amharic, this.icon, this.color, this.items);
}
