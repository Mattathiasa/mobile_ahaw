import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../services/permission_service.dart';
import '../../services/hierarchy_service.dart';
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;

class HierarchyPage extends StatefulWidget {
  const HierarchyPage({super.key});

  @override
  State<HierarchyPage> createState() => _HierarchyPageState();
}

class _HierarchyPageState extends State<HierarchyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HierarchyService _hierarchyService = HierarchyService();

  final List<String> _levels = ['Zone', 'Atbiya', 'EnkesekaseMaikel', 'Mahderat'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _levels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateEntitySheet(BuildContext context, String level) {
    final nameCtrl = TextEditingController();
    final nameAmharicCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedParentId;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return FormSheet(
            title: 'Create $level',
            subtitle: 'Add a new organizational unit to the hierarchy',
            isDark: isDark,
            saving: saving,
            submitLabel: 'Create Entity',
            onSubmit: () async {
              if (nameCtrl.text.isEmpty) return;
              setSheet(() => saving = true);
              try {
                await _hierarchyService.createEntity({
                  'name': nameCtrl.text.trim(),
                  'nameAmharic': nameAmharicCtrl.text.trim(),
                  'level': level,
                  'location': locationCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'parentId': selectedParentId,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('$level created successfully!', success: true);
              } catch (e) {
                _showSnack('Failed: $e');
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            },
            children: [
              buildLabel('Name (English) *', isDark),
              buildTextField(nameCtrl, 'e.g. East Shewa Zone', isDark),
              const SizedBox(height: 16),
              buildLabel('Name (Amharic)', isDark),
              buildTextField(nameAmharicCtrl, 'e.g. ምስራቅ ሸዋ ዞን', isDark),
              const SizedBox(height: 16),
              if (level != 'Zone') ...[
                buildLabel('Parent Entity *', isDark),
                _buildParentDropdown(level, selectedParentId, (v) => setSheet(() => selectedParentId = v), isDark),
                const SizedBox(height: 16),
              ],
              buildLabel('Location', isDark),
              buildTextField(locationCtrl, 'e.g. Addis Ababa', isDark),
              const SizedBox(height: 16),
              buildLabel('Description', isDark),
              buildTextField(descCtrl, 'Brief description...', isDark, maxLines: 3),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.sacredRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Hierarchy', style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.lightText), onPressed: () => Navigator.pop(context)),
        actions: [
          if (perms.isSuperAdmin || perms.can('canCreateHierarchy'))
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.add_business_outlined, color: AppColors.primary),
                onPressed: () => _showCreateEntitySheet(context, _levels[_tabController.index]),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: _levels.map((l) => Tab(text: l.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _levels.map((level) => _buildLevelList(level, isDark, perms)).toList(),
      ),
    );
  }

  Widget _buildLevelList(String level, bool isDark, PermissionService perms) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _hierarchyService.getEntitiesByLevel(level),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final entities = snapshot.data ?? [];
        if (entities.isEmpty) return _buildEmptyState(level);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entities.length,
          itemBuilder: (context, index) {
            final data = entities[index];
            return _buildEntityCard(data, isDark, perms);
          },
        );
      },
    );
  }

  Widget _buildEntityCard(Map<String, dynamic> data, bool isDark, PermissionService perms) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? 'Unnamed', style: GoogleFonts.notoSansEthiopic(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText)),
                    if (data['nameAmharic'] != null && data['nameAmharic'].isNotEmpty)
                      Text(data['nameAmharic'], style: GoogleFonts.notoSansEthiopic(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (perms.isSuperAdmin || perms.can('canDeleteHierarchy'))
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.sacredRed, size: 20), onPressed: () => _confirmDelete(data['id'], data['name'])),
            ],
          ),
          if (data['location'] != null && data['location'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(data['location'], style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            ]),
          ],
          if (data['description'] != null && data['description'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(data['description'], style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  void _confirmDelete(String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entity'),
        content: Text('Are you sure you want to delete ${name ?? 'this entity'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            await _hierarchyService.deleteEntity(id);
            if (ctx.mounted) Navigator.pop(ctx);
            _showSnack('Entity deleted');
          }, child: const Text('Delete', style: TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String level) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.business_outlined, size: 64, color: AppColors.primary.withOpacity(0.2)),
    const SizedBox(height: 16),
    Text('NO ${level.toUpperCase()}S YET', style: GoogleFonts.notoSansEthiopic(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey.withOpacity(0.5))),
  ]));

  Widget _buildParentDropdown(String level, String? selectedId, ValueChanged<String?> onChanged, bool isDark) {
    String parentLevel = '';
    if (level == 'Atbiya') {
      parentLevel = 'Zone';
    } else if (level == 'EnkesekaseMaikel' || level == 'Mahderat') {
      parentLevel = 'Atbiya';
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _hierarchyService.getEntitiesByLevel(parentLevel),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.12))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              hint: Text('Select Parent $parentLevel', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              items: items.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name'] ?? 'Unnamed'))).toList(),
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1A365D) : Colors.white,
            ),
          ),
        );
      },
    );
  }
}
