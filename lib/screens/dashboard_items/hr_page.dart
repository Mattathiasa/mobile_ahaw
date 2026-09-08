import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/hr_service.dart';
import '../../services/permission_service.dart';
import '../../services/module_config_service.dart';
import '../../theme/app_colors.dart';

/// Employee/HR management: list, search, and (for HR roles) add/edit/delete.
/// Employment type / status option lists come from Module Config.
class HRPage extends StatefulWidget {
  const HRPage({super.key});

  @override
  State<HRPage> createState() => _HRPageState();
}

class _HRPageState extends State<HRPage> {
  final HrService _service = HrService();
  String _search = '';

  static const _statusColors = {
    'Active': Color(0xFF10B981),
    'OnLeave': AppColors.divineGold,
    'Terminated': AppColors.sacredRed,
    'Inactive': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final canManage = perms.isSuperAdmin || perms.can('canViewHR');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Human Resources',
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
                hintText: 'Search employees...',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppColors.primary.withOpacity(0.1))),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.watchEmployees(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) return _empty('Could not load employees');
                var staff = snapshot.data ?? [];
                if (_search.isNotEmpty) {
                  staff = staff
                      .where((e) => (e['fullName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search))
                      .toList();
                }
                if (staff.isEmpty) return _empty('No employees yet');
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staff.length,
                  itemBuilder: (context, i) =>
                      _card(staff[i], isDark, i, canManage),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> e, bool isDark, int index, bool canManage) {
    final status = e['status'] as String? ?? 'Active';
    final statusColor = _statusColors[status] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            (e['fullName'] ?? 'E').toString().trim().isNotEmpty
                ? e['fullName'].toString().trim()[0].toUpperCase()
                : 'E',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['fullName'] ?? 'Employee',
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 2),
            Text(
                [e['position'], e['department']]
                    .where((x) => (x ?? '').toString().isNotEmpty)
                    .join(' · '),
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10, color: Colors.grey)),
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
                  if (v == 'edit') _openForm(context, existing: e);
                  if (v == 'delete') _confirmDelete(e);
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

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('Delete "${e['fullName'] ?? ''}"?'),
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
    if (ok == true) await _service.remove(e['id'] as String);
  }

  void _openForm(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final moduleConfig =
        Provider.of<ModuleConfigService>(context, listen: false);
    final types = moduleConfig.options('hr', 'employmentTypes');
    final statuses = moduleConfig.options('hr', 'statuses');

    final nameCtrl = TextEditingController(text: existing?['fullName']);
    final positionCtrl = TextEditingController(text: existing?['position']);
    final deptCtrl = TextEditingController(text: existing?['department']);
    final phoneCtrl = TextEditingController(text: existing?['phone']);
    final emailCtrl = TextEditingController(text: existing?['email']);
    final salaryCtrl =
        TextEditingController(text: existing?['salary']?.toString());
    final hireCtrl = TextEditingController(text: existing?['hireDate']);
    String type = existing?['employmentType']?.toString() ??
        (types.isNotEmpty ? types.first : 'FullTime');
    String status = existing?['status']?.toString() ??
        (statuses.isNotEmpty ? statuses.first : 'Active');
    String category = existing?['category']?.toString() ?? 'Staff';
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
                    Text(isEditing ? 'Edit Employee' : 'New Employee',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _field(nameCtrl, 'Full Name', required: true),
                    _field(positionCtrl, 'Position', required: true),
                    _field(deptCtrl, 'Department'),
                    _field(phoneCtrl, 'Phone',
                        keyboardType: TextInputType.phone),
                    _field(emailCtrl, 'Email',
                        keyboardType: TextInputType.emailAddress),
                    _field(salaryCtrl, 'Salary (ETB)',
                        keyboardType: TextInputType.number),
                    _field(hireCtrl, 'Hire Date (YYYY-MM-DD)'),
                    _dropdown('Category', category,
                        const ['Staff', 'Priest'],
                        (v) => setSheet(() => category = v)),
                    _dropdown('Employment Type', type,
                        types.isEmpty
                            ? const ['FullTime', 'PartTime', 'Contract', 'Volunteer']
                            : types,
                        (v) => setSheet(() => type = v)),
                    _dropdown('Status', status,
                        statuses.isEmpty
                            ? const ['Active', 'OnLeave', 'Terminated']
                            : statuses,
                        (v) => setSheet(() => status = v)),
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
                                  'fullName': nameCtrl.text.trim(),
                                  'position': positionCtrl.text.trim(),
                                  'department': deptCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'salary':
                                      num.tryParse(salaryCtrl.text.trim()) ?? 0,
                                  'hireDate': hireCtrl.text.trim(),
                                  'category': category,
                                  'employmentType': type,
                                  'status': status,
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
          FaIcon(FontAwesomeIcons.userTie,
              size: 56, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      );
}
