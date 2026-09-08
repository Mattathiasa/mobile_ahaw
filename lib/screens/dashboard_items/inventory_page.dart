import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/module_config_service.dart';
import '../../theme/app_colors.dart';

/// Church asset inventory: list, search, and (for admins) add/edit/delete.
/// Condition / status option lists come from Module Config.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final InventoryService _service = InventoryService();
  String _search = '';

  static const _statusColors = {
    'InUse': Color(0xFF10B981),
    'InStorage': AppColors.primary,
    'Maintenance': AppColors.divineGold,
    'Retired': Colors.grey,
    'Disposed': AppColors.sacredRed,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final canManage = perms.isSuperAdmin || perms.can('canViewInventory');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Inventory',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _openForm(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Search assets...',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.1))),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.watchAssets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return _empty('Could not load assets');
                }
                var assets = snapshot.data ?? [];
                if (_search.isNotEmpty) {
                  assets = assets
                      .where((a) => (a['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search))
                      .toList();
                }
                if (assets.isEmpty) return _empty('No assets yet');
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: assets.length,
                  itemBuilder: (context, i) =>
                      _card(assets[i], isDark, i, canManage),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> a, bool isDark, int index, bool canManage) {
    final status = a['status'] as String? ?? 'InStorage';
    final statusColor = _statusColors[status] ?? AppColors.primary;
    final qty = (a['quantity'] as num?)?.toInt() ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const FaIcon(FontAwesomeIcons.boxesStacked,
              size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['name'] ?? 'Asset',
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 2),
            Row(children: [
              if ((a['category'] ?? '').toString().isNotEmpty)
                Text('${a['category']} · ',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 10, color: Colors.grey)),
              Text('Qty $qty',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10, color: Colors.grey)),
              if ((a['location'] ?? '').toString().isNotEmpty)
                Text(' · ${a['location']}',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 10, color: Colors.grey)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(status,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: statusColor)),
          ),
          if (canManage)
            SizedBox(
              height: 28,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 16),
                onSelected: (v) {
                  if (v == 'edit') _openForm(context, existing: a);
                  if (v == 'delete') _confirmDelete(a);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
        ]),
      ]),
    ).animate().fadeIn(delay: (index * 30).ms);
  }

  Future<void> _confirmDelete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete asset?'),
        content: Text('Delete "${a['name'] ?? ''}"?'),
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
    if (ok == true) await _service.remove(a['id'] as String);
  }

  void _openForm(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final moduleConfig =
        Provider.of<ModuleConfigService>(context, listen: false);
    final conditions = moduleConfig.options('inventory', 'conditions');
    final statuses = moduleConfig.options('inventory', 'statuses');

    final nameCtrl = TextEditingController(text: existing?['name']);
    final categoryCtrl = TextEditingController(text: existing?['category']);
    final locationCtrl = TextEditingController(text: existing?['location']);
    final qtyCtrl =
        TextEditingController(text: (existing?['quantity'] ?? 1).toString());
    final assignedCtrl = TextEditingController(text: existing?['assignedTo']);
    String condition = existing?['condition']?.toString() ??
        (conditions.isNotEmpty ? conditions.first : 'Good');
    String status = existing?['status']?.toString() ??
        (statuses.isNotEmpty ? statuses.first : 'InStorage');
    String acquisition = existing?['acquisitionType']?.toString() ?? 'Purchased';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'Edit Asset' : 'New Asset',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _field(nameCtrl, 'Name', required: true),
                    _field(categoryCtrl, 'Category'),
                    _field(qtyCtrl, 'Quantity',
                        keyboardType: TextInputType.number),
                    _field(locationCtrl, 'Location'),
                    _field(assignedCtrl, 'Assigned To'),
                    _dropdown('Condition', condition,
                        conditions.isEmpty ? const ['New', 'Good', 'Fair', 'Poor'] : conditions,
                        (v) => setSheet(() => condition = v)),
                    _dropdown('Status', status,
                        statuses.isEmpty ? const ['InUse', 'InStorage', 'Maintenance', 'Retired'] : statuses,
                        (v) => setSheet(() => status = v)),
                    _dropdown('Acquisition', acquisition,
                        const ['Purchased', 'Rented'],
                        (v) => setSheet(() => acquisition = v)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                final data = {
                                  'name': nameCtrl.text.trim(),
                                  'category': categoryCtrl.text.trim(),
                                  'quantity':
                                      int.tryParse(qtyCtrl.text.trim()) ?? 1,
                                  'location': locationCtrl.text.trim(),
                                  'assignedTo': assignedCtrl.text.trim(),
                                  'condition': condition,
                                  'status': status,
                                  'acquisitionType': acquisition,
                                };
                                try {
                                  if (isEditing) {
                                    await _service.update(
                                        existing['id'] as String, data);
                                  } else {
                                    await _service.create(data);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    final safe = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safe,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v ?? safe),
      ),
    );
  }

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FaIcon(FontAwesomeIcons.boxOpen,
              size: 56, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      );
}
